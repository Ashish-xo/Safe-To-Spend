import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/app_store.dart';
import '../../services/category_classifier.dart';

/// LIVE view inside the Naive Bayes model: type any note, see the actual
/// word probabilities, per-category log-scores and confidence that the
/// math produces. This is the ML made visible — nothing is faked, every
/// number comes straight from CategoryClassifier.explain().
class ModelBrainScreen extends StatefulWidget {
  const ModelBrainScreen({super.key});

  @override
  State<ModelBrainScreen> createState() => _ModelBrainScreenState();
}

class _ModelBrainScreenState extends State<ModelBrainScreen> {
  final _controller = TextEditingController();
  CategoryClassifier? _classifier;
  int _trainingSize = 0;
  NaiveBayesExplanation? _explanation;

  @override
  void initState() {
    super.initState();
    _reload();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final store = AppStore();
    final txs = await store.getTransactions();
    final c = CategoryClassifier();
    c.trainFrom(txs);
    if (!mounted) return;
    setState(() {
      _classifier = c;
      _trainingSize = c.trainingSize;
    });
    _onChanged();
  }

  void _onChanged() {
    final c = _classifier;
    if (c == null) return;
    setState(() {
      _explanation =
          _controller.text.trim().isEmpty ? null : c.explain(_controller.text);
      // Keep the header's vocabulary stat in sync with the live model.
      _vocabularySize = _explanation?.vocabularySize ?? 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: AppBar(
        backgroundColor: AppColors.background(isDark),
        title: const Text('Model brain'),
      ),
      body: _classifier == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _statusCard(isDark),
                const SizedBox(height: 16),
                TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText:
                        'Type a note to classify — e.g. "kebab order 250"',
                    filled: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 16),
                if (_explanation != null)
                  _explanationView(_explanation!, isDark),
              ],
            ),
    );
  }

  Widget _statusCard(bool isDark) {
    final c = _classifier!;
    final cats = c.learnedCategories;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card(isDark),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Multinomial Naive Bayes — live',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.textPrimary(isDark))),
          const SizedBox(height: 6),
          Text(
            'Trained on $_trainingSize of your transactions · '
            'vocabulary of ${_vocabularySize} words · '
            '${cats.length} categories: ${cats.join(", ")}',
            style: TextStyle(
                fontSize: 12.5, color: AppColors.textSecondary(isDark)),
          ),
          const SizedBox(height: 8),
          Text(
            'Every guess below is computed on this phone with '
            'P(category|note) ∝ P(category) × Π P(word|category). '
            'No cloud, no pre-trained model.',
            style: TextStyle(
                fontSize: 12, color: AppColors.textSecondary(isDark)),
          ),
        ],
      ),
    );
  }

  int? _vocabularySize;

  Widget _explanationView(NaiveBayesExplanation ex, bool isDark) {
    final winning = ex.bestCategory == null
        ? <({String word, double logP})>[]
        : ex.winningEvidence(ex.bestCategory!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ---- 1. Verdict ----
        _card(isDark, 'VERDICT', [
          Row(
            children: [
              Text(
                ex.bestCategory ?? '—',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryGreen),
              ),
              const Spacer(),
              Text(
                'confidence ${(ex.confidence * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                    fontSize: 14, color: AppColors.textPrimary(isDark)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Beats runner-up with ${(ex.bestVsSecond * 100).toStringAsFixed(1)}% '
            'probability · ${ex.knownWords}/${ex.words.length} words known · '
            'coverage ${(ex.coverage * 100).toStringAsFixed(0)}%',
            style:
                TextStyle(fontSize: 12, color: AppColors.textSecondary(isDark)),
          ),
          if (ex.confidence < 0.25)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Below the 0.25 trust threshold → the model ABSTAINS to '
                '"Other" instead of guessing. That is deliberate.',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.orangeAccent,
                    fontStyle: FontStyle.italic),
              ),
            ),
        ]),

        // ---- 2. Per-category scores ----
        _card(isDark, 'P(category | note) — log-space scores', [
          ...ex.rankedScores.map((r) {
            final top = r == ex.rankedScores.first;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                      width: 110,
                      child: Text(r.category,
                          style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: top ? FontWeight.w700 : FontWeight.w400,
                              color: top
                                  ? AppColors.primaryGreen
                                  : AppColors.textPrimary(isDark)))),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: _barValue(r.logProb, ex.rankedScores),
                        minHeight: 10,
                        backgroundColor: AppColors.background(isDark),
                        valueColor: AlwaysStoppedAnimation(
                            top ? AppColors.primaryGreen : Colors.grey),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(r.logProb.toStringAsFixed(2),
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary(isDark))),
                ],
              ),
            );
          }),
          Text(
            'log P(note|category) = log P(category) + Σ log P(word|category). '
            'Higher (less negative) wins.',
            style: TextStyle(
                fontSize: 11.5, color: AppColors.textSecondary(isDark)),
          ),
        ]),

        // ---- 3. Word-level evidence ----
        if (winning.isNotEmpty)
          _card(isDark, 'Why "${ex.bestCategory}"? — word evidence', [
            ...winning.map((e) {
              final known = ex.evidence[ex.bestCategory!]!
                  .firstWhere((x) => x.word == e.word)
                  .known;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(
                      known ? Icons.check_circle : Icons.help_outline,
                      size: 16,
                      color: known ? Colors.greenAccent : Colors.orangeAccent,
                    ),
                    const SizedBox(width: 8),
                    Text('"${e.word}"',
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary(isDark))),
                    const Spacer(),
                    Text(
                      known
                          ? 'seen before · log P = ${e.logP.toStringAsFixed(2)}'
                          : 'unseen → Laplace-smoothed · log P = ${e.logP.toStringAsFixed(2)}',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary(isDark)),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 4),
            Text(
              'Green = the model has seen this word in this category before. '
              'Orange = unseen word getting the smoothed (add-one) probability '
              '— the model still reasons with it instead of crashing.',
              style: TextStyle(
                  fontSize: 11.5, color: AppColors.textSecondary(isDark)),
            ),
          ]),
      ],
    );
  }

  double _barValue(double logProb, List<({String category, double logProb})> all) {
    // Map log-probs to [0.05, 1] bar lengths relative to the best/worst.
    if (all.length == 1) return 1;
    final best = all.first.logProb;
    final worst = all.last.logProb;
    if (best == worst) return 1;
    final t = (logProb - worst) / (best - worst);
    return 0.05 + 0.95 * t.clamp(0.0, 1.0);
  }

  Widget _card(bool isDark, String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card(isDark),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(),
              style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary(isDark))),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}
