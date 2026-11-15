import 'dart:math' as math;

import '../models/transaction_model.dart';

/// On-device Naive Bayes text classifier that learns to map free-form
/// notes to spending categories from the user's own transaction history.
///
/// HOW IT WORKS (one-liner for demos):
/// "It counts which words appear in which category, then uses those
/// counts as probabilities to guess the category of new notes.
/// Trained entirely on-device — no cloud, no API."
///
/// Model = Multinomial Naive Bayes with add-one (Laplace) smoothing:
///   P(category|note) ∝ P(category) · Π P(word|category)
///   P(word|category) = (count(word,category)+α) / (totalWords(category)+α·V)
///
/// - Trains in O(N·W) on every new transaction — instant for personal scale.
/// - Falls back to the built-in keyword rules when the model is unsure,
///   so behaviour is never worse than before the ML was added.
class CategoryClassifier {
  /// Word counts per category: {category: {word: count}}.
  final Map<String, Map<String, int>> _wordCounts = {};

  /// Total number of training documents (transactions) per category.
  final Map<String, int> _docCounts = {};

  /// Total training documents overall.
  int _totalDocs = 0;

  /// Laplace smoothing constant (add-one).
  static const double _alpha = 1.0;

  /// Minimum confidence required to trust the model over the built-in
  /// keyword rules. 0.25 balances recall vs precision on small corpora.
  static const double _confidenceMargin = 0.25;

  /// Words too common or meaningless to learn from.
  static const _stopWords = {
    'the', 'a', 'an', 'for', 'on', 'at', 'to', 'of', 'and', 'in', 'with',
    'my', 'from', 'by', 'is', 'was', 'paid', 'spent', 'bought',
    'yesterday', 'today', 'log', 'add', 'logged', 'added', 'some', 'mr',
  };

  CategoryClassifier();

  /// True if the model has been trained on any data.
  bool get isTrained => _totalDocs > 0;

  /// Number of training examples seen.
  int get trainingSize => _totalDocs;

  /// Distinct categories the model has learned.
  List<String> get learnedCategories =>
      _docCounts.entries.where((e) => e.value > 0).map((e) => e.key).toList()
        ..sort();

  /// Tokenize a note/message into lowercase word features.
  static List<String> tokenize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\u0900-\u097F\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 2 && w.length <= 20 && !_stopWords.contains(w))
        .toList();
  }

  /// Train on one transaction (called for every stored transaction and
  /// every newly logged one — the model improves with every entry).
  void learn(String note, String category, {bool isExpense = true}) {
    if (!isExpense || note.isEmpty) return;
    final words = tokenize(note);
    if (words.isEmpty) return;

    final bucket = _wordCounts.putIfAbsent(category, () => {});
    for (final w in words) {
      bucket[w] = (bucket[w] ?? 0) + 1;
    }
    _docCounts[category] = (_docCounts[category] ?? 0) + 1;
    _totalDocs++;
  }

  /// Batch-train from the transaction store. Entries marked 'other' are
  /// skipped: that label means "unknown", not a real category — training
  /// on it would teach the model that everything unfamiliar is 'other'
  /// and poison the vocabulary.
  void trainFrom(List<TransactionModel> transactions) {
    for (final t in transactions) {
      if (t.category == 'other') continue;
      // '_learn: <words>' records are user corrections — train hard (x3)
      // so one correction outweighs a few conflicting old examples.
      if (t.note != null && t.note!.startsWith('_learn: ')) {
        final words = t.note!.substring(7).trim();
        if (words.isNotEmpty) {
          for (var i = 0; i < 3; i++) {
            learn(words, t.category, isExpense: t.isExpense);
          }
        }
        continue;
      }
      if (t.note != null) learn(t.note!, t.category, isExpense: t.isExpense);
      // Also learn from the category word itself appearing in text, so
      // explicit mentions ("food", "transport") stay perfectly classified.
      learn(t.category, t.category, isExpense: t.isExpense);
    }
  }

  /// Classify a note. Returns (category, confidence 0..1) or null when the
  /// model has no training data.
  ({String category, double confidence})? classify(String text) {
    if (!isTrained) return null;
    final words = tokenize(text);
    if (words.isEmpty) return null;

    final vocab = <String>{};
    for (final b in _wordCounts.values) {
      vocab.addAll(b.keys);
    }
    final vocabSize = vocab.isEmpty ? 1 : vocab.length;

    String? best;
    var bestScore = double.negativeInfinity;
    var secondScore = double.negativeInfinity;

    for (final entry in _docCounts.entries) {
      if (entry.value <= 0) continue;
      final cat = entry.key;
      final bucket = _wordCounts[cat] ?? const {};
      final totalWords = bucket.values.fold<int>(0, (s, c) => s + c);

      // Log P(category) with a smoothed prior
      var score = log(_docCounts[cat]! / _totalDocs);
      for (final w in words) {
        final count = bucket[w] ?? 0;
        // Log P(word|category) with add-one smoothing
        score += log((count + _alpha) / (totalWords + _alpha * vocabSize));
      }

      if (score > bestScore) {
        secondScore = bestScore;
        bestScore = score;
        best = cat;
      } else if (score > secondScore) {
        secondScore = score;
      }
    }

    if (best == null) return null;

    // Confidence: how strongly the note's words point at the winning
    // category vs the field overall. Blends two signals, both easy to
    // explain in a demo:
    //  1. log-prob margin between the best and second-best category
    //     (softmax-ish squash over the max plausible margin of ~6 nats)
    //  2. vocabulary coverage: fraction of words the model has seen
    // Unseen words ("kebab") with a clear prior lean still classify; truly
    // ambiguous junk stays low-confidence and falls through to 'other'.
    var knownWords = 0;
    for (final w in words) {
      for (final b in _wordCounts.values) {
        if (b.containsKey(w)) {
          knownWords++;
          break;
        }
      }
    }
    final coverage = knownWords / words.length;
    // Principle: with ZERO known words the score difference is pure prior
    // bias (denominator artifacts) — not evidence. Dampen hard so the
    // model abstains instead of guessing on out-of-vocabulary text.
    final damp = knownWords == 0 ? 0.3 : 1.0;
    final margin = (secondScore == double.negativeInfinity)
        ? 6.0
        : (bestScore - secondScore);
    final marginConf = (margin / 6.0).clamp(0.0, 1.0);
    final confidence =
        (damp * (0.55 * marginConf + 0.45 * coverage)).clamp(0.0, 1.0);

    return (category: best, confidence: confidence);
  }

  /// Hybrid guess used by the assistant: the built-in keyword map first
  /// (deterministic, always right when it matches), then the trained
  /// model when keywords are silent, and 'other' as the last resort.
  String guessWithFallback(
    String text,
    String Function(String) keywordGuess,
  ) {
    final keyword = keywordGuess(text);
    if (keyword != 'other') return keyword;

    final result = classify(text);
    if (result != null &&
        result.confidence >= _confidenceMargin &&
        result.category != 'other') {
      return result.category;
    }
    return 'other';
  }

  static double log(num x) => x <= 0 ? -1000 : math.log(x);

  /// Full decision trace for one note — the same math as [classify] but
  /// exposing every intermediate value so the app can SHOW the model
  /// thinking. Used by the "model brain" panel and in-reply explanations.
  NaiveBayesExplanation explain(String text) {
    final words = tokenize(text);
    if (!isTrained || words.isEmpty) {
      return NaiveBayesExplanation.empty(text, words);
    }

    final vocab = <String>{};
    for (final b in _wordCounts.values) {
      vocab.addAll(b.keys);
    }
    final vocabSize = vocab.isEmpty ? 1 : vocab.length;

    // Per-category log-probability and per-word evidence.
    final scores = <String, double>{};
    final evidence =
        <String, List<({String word, double logP, bool known})>>{};

    for (final entry in _docCounts.entries) {
      if (entry.value <= 0) continue;
      final cat = entry.key;
      final bucket = _wordCounts[cat] ?? const {};
      final totalWords = bucket.values.fold<int>(0, (s, c) => s + c);
      var score = log(_docCounts[cat]! / _totalDocs); // log P(cat)
      final ev = <({String word, double logP, bool known})>[];
      for (final w in words) {
        final count = bucket[w] ?? 0;
        // log P(word|cat) with add-one smoothing
        final lp = log((count + _alpha) / (totalWords + _alpha * vocabSize));
        score += lp;
        ev.add((word: w, logP: lp, known: count > 0));
      }
      scores[cat] = score;
      evidence[cat] = ev;
    }

    // Rank categories by log-probability.
    final ranked = scores.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final best = ranked.isEmpty ? null : ranked.first;
    final second = ranked.length > 1 ? ranked[1] : null;

    // Vocabulary coverage + confidence, mirroring classify().
    var knownWords = 0;
    for (final w in words) {
      for (final b in _wordCounts.values) {
        if (b.containsKey(w)) {
          knownWords++;
          break;
        }
      }
    }
    final coverage = words.isEmpty ? 0.0 : knownWords / words.length;
    final damp = knownWords == 0 ? 0.3 : 1.0;
    final margin = (best == null || second == null)
        ? 6.0
        : (best.value - second.value);
    final marginConf = (margin / 6.0).clamp(0.0, 1.0);
    final confidence =
        (damp * (0.55 * marginConf + 0.45 * coverage)).clamp(0.0, 1.0);

    return NaiveBayesExplanation(
      rawText: text,
      words: words,
      vocabularySize: vocabSize,
      trainingDocs: _totalDocs,
      knownWords: knownWords,
      coverage: coverage,
      confidence: confidence,
      rankedScores: ranked
          .map((e) => (category: e.key, logProb: e.value))
          .toList(),
      evidence: evidence,
    );
  }
}

/// The complete decision trace of one Naive Bayes classification — every
/// number the model used, in a form a human (or a viva examiner) can read.
class NaiveBayesExplanation {
  final String rawText;
  final List<String> words;
  final int vocabularySize;
  final int trainingDocs;
  final int knownWords;
  final double coverage;
  final double confidence;
  final List<({String category, double logProb})> rankedScores;
  final Map<String, List<({String word, double logP, bool known})>> evidence;

  const NaiveBayesExplanation({
    required this.rawText,
    required this.words,
    required this.vocabularySize,
    required this.trainingDocs,
    required this.knownWords,
    required this.coverage,
    required this.confidence,
    required this.rankedScores,
    required this.evidence,
  });

  factory NaiveBayesExplanation.empty(String text, List<String> words) =>
      NaiveBayesExplanation(
        rawText: text,
        words: words,
        vocabularySize: 0,
        trainingDocs: 0,
        knownWords: 0,
        coverage: 0,
        confidence: 0,
        rankedScores: const [],
        evidence: const {},
      );

  String? get bestCategory =>
      rankedScores.isEmpty ? null : rankedScores.first.category;

  /// Probability that the best category beats the runner-up, computed by
  /// softmax over the top log-probabilities — the closest thing to
  /// P(best | text) the model can offer.
  double get bestVsSecond {
    if (rankedScores.length < 2) return 1.0;
    final a = rankedScores[0].logProb, b = rankedScores[1].logProb;
    // softmax with max-shift for numeric stability
    final m = math.max(a, b);
    final ea = math.exp(a - m), eb = math.exp(b - m);
    return ea / (ea + eb);
  }

  /// The words that pushed the decision toward the winning category
  /// (highest per-word log-probability in the best category).
  List<({String word, double logP})> winningEvidence(String category) {
    final ev = evidence[category];
    if (ev == null) return const [];
    final sorted = [...ev]..sort((x, y) => y.logP.compareTo(x.logP));
    return sorted.map((e) => (word: e.word, logP: e.logP)).toList();
  }
}
