import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/transaction_model.dart';
import '../models/user_settings_model.dart';
import '../services/app_store.dart';
import 'insights_engine.dart';

/// AI chat assistant. Abilities:
/// 1) Natural-language data entry: "spent 250 on biryani yesterday"
///    -> parsed locally (instant, offline) or by the LLM (richer).
/// 2) Q&A over the user's local data: "how much did I spend on food?"
///    -> grounded in the real DB, LLM phrases/analyses.
/// 3) Affordability checks: "can I afford a 800 concert ticket?"
/// 4) Conversation memory: follow-ups like "and last month?" work.
class ChatAssistant {
  final AppStore store;
  final List<Map<String, String>> _history = []; // rolling conversation memory
  static const _maxHistory = 10;
  static const _endpoint = 'https://text.pollinations.ai/openai';

  ChatAssistant(this.store);

  Future<AssistantReply> handle(String message) async {
    final settings = await store.getSettings();
    final transactions = await store.getTransactions();
    final recurring = await store.getRecurringPayments();

    // Step 0: greetings are answered instantly, no LLM call needed.
    final m = message.toLowerCase().trim();
    if (RegExp(r'^(hi|hello|hey|yo|namaste|hola|sup|good (morning|afternoon|evening))\b[!.,? ]*$')
        .hasMatch(m)) {
      final reply = 'Hey! I\'m Sage. Log a transaction in plain English — e.g. '
          '"spent 250 on biryani yesterday" or "60 for coffee" — or ask me '
          'anything about your spending.';
      _remember('user', message);
      _remember('assistant', reply);
      return AssistantReply(text: reply);
    }

    // Step 1: instant local parse for add-intent (works offline, no LLM
    // needed for logging — also handles compound "X for A and Y for B").
    final parsed = _quickParseAll(message);
    if (parsed.isNotEmpty) {
      for (final t in parsed) {
        await store.addTransaction(t);
      }
      final cur = settings.currencySymbol;
      final summary = parsed
          .map((t) => '$cur${t.amount.toStringAsFixed(0)} (${t.category})'
              '${t.note != null && t.note!.isNotEmpty && t.note!.toLowerCase() != t.category
                  ? ' — "${t.note}"' : ''}')
          .join(parsed.length == 2 ? ' and ' : ', ');
      String text;
      if (parsed.length == 1) {
        final t = parsed.first;
        text = 'Logged ${t.type == TransactionType.income ? "income" : "expense"} of $summary. '
            'Your Safe to Spend is updated.';
      } else {
        final expenseCount =
            parsed.where((t) => t.type == TransactionType.expense).length;
        text = 'Logged ${parsed.length} transactions ($expenseCount expenses): $summary. '
            'Your Safe to Spend is updated.';
      }
      _remember('user', message);
      _remember('assistant', 'Logged ${parsed.length} transaction(s): $summary');
      return AssistantReply(text: text, addedTransaction: parsed.first);
    }

    // Step 2: factual questions are answered EXACTLY from the local DB —
    // the LLM never does math (it hallucinates numbers on empty data).
    final factual = _localFactualAnswer(message, settings, transactions);
    if (factual != null) {
      _remember('user', message);
      _remember('assistant', factual.text);
      return factual;
    }

    // Step 3: LLM for open-ended advice/affordability (retries — Pollinations
    // free tier is 1 reply / 45s per IP).
    final reply = await _askLlm(message, settings, transactions, recurring);
    if (reply != null) return reply;

    // Step 4: offline fallback.
    return _localFallback(message, settings, transactions);
  }

  void _remember(String role, String content) {
    _history.add({'role': role, 'content': content});
    if (_history.length > _maxHistory) _history.removeAt(0);
  }

  /// Answers factual "how much/many" questions with EXACT numbers computed
  /// from the local DB. Returns null if the message isn't a factual query,
  /// so it falls through to the LLM.
  AssistantReply? _localFactualAnswer(
      String message, UserSettings settings, List<TransactionModel> txs) {
    final m = message.toLowerCase().trim();
    final cur = settings.currencySymbol;
    final now = DateTime.now();

    final asksSpend = (m.contains('how much') || m.contains('what') || m.contains('total') || m.startsWith('spend')) &&
        (m.contains('spend') || m.contains('spent') || m.contains('spending'));
    final asksEarned = (m.contains('how much') || m.contains('total')) &&
        (m.contains('earn') || m.contains('income') || m.contains('salary'));
    final asksBalance = m.contains('balance') || m.contains('safe to spend');

    if (!asksSpend && !asksEarned && !asksBalance) return null;

    // Time window
    DateTime? from;
    var period = 'all time';
    if (m.contains('today')) {
      from = DateTime(now.year, now.month, now.day);
      period = 'today';
    } else if (m.contains('this week') || m.contains('this wk')) {
      from = now.subtract(Duration(days: now.weekday - 1));
      period = 'this week';
    } else if (m.contains('this month') || (m.contains('month') && !m.contains('last'))) {
      from = DateTime(now.year, now.month);
      period = 'this month';
    } else if (m.contains('last month')) {
      final last = DateTime(now.year, now.month - 1);
      double spent = 0;
      for (final t in txs) {
        if (t.type == TransactionType.expense &&
            t.date.year == last.year && t.date.month == last.month) {
          spent += t.amount;
        }
      }
      return AssistantReply(text: 'You spent $cur${_fmt(spent)} $period.');
    }

    // Category filter
    final categories = ['food', 'transport', 'groceries', 'entertainment', 'shopping', 'health', 'education', 'rent', 'utilities', 'other'];
    String? cat;
    for (final c in categories) {
      if (m.contains(c)) {
        cat = c;
        break;
      }
    }

    if (asksBalance) {
      return AssistantReply(
          text: 'Your balance is $cur${_fmt(settings.currentBalance)} — that\'s your Safe to Spend before upcoming obligations.');
    }

    double total = 0;
    int count = 0;
    for (final t in txs) {
      final typeMatch = asksEarned ? t.type == TransactionType.income : t.type == TransactionType.expense;
      if (!typeMatch) continue;
      if (from != null && t.date.isBefore(from)) continue;
      if (cat != null && t.category.toLowerCase() != cat) continue;
      total += t.amount;
      count++;
    }

    if (asksEarned) {
      return AssistantReply(
          text: 'You\'ve earned $cur${_fmt(total)} $period'
              '${cat != null ? " from $cat" : ""} ($count entries).');
    }
    return AssistantReply(
        text: 'You\'ve spent $cur${_fmt(total)} $period'
            '${cat != null ? " on $cat" : ""} ($count transactions).');
  }

  String _fmt(double v) {
    if (v == v.roundToDouble() && v.abs() < 1000000) return v.round().toString();
    return v.toStringAsFixed(v.abs() < 100 ? 2 : 0);
  }

  /// Parses one or more transactions from natural language:
  ///   "spent 1200 on shopping"          -> 1 expense
  ///   "60 for coffee and 20 for e-rickshaw" -> 2 expenses (compound)
  ///   "log 5000 salary"                 -> 1 income
  /// Returns empty list if the message has no add-intent.
  List<TransactionModel> _quickParseAll(String message) {
    final m = message.toLowerCase().trim();
    final isIncome = m.contains('earned') || m.contains('received') ||
        m.contains('salary') || m.contains('add income') ||
        RegExp(r'\blog\b.*\b(salary|income)\b').hasMatch(m);
    final isExpense = m.contains('spent') || m.contains('paid') || m.contains('bought') ||
        m.contains('add expense');

    // "60 for coffee" — no verb, but "N for X" is still a log intent.
    final implicit = RegExp(r'\b\d+(?:\.\d+)?\s*(?:for|on|towards)\s+\w+').hasMatch(m);

    if (!isIncome && !isExpense && !implicit) return const [];

    // Split compound messages: "60 for coffee and 20 for e-rickshaw"
    final segments = m
        .split(RegExp(r'\s*(?:,|\+|;|and then|then|and)\s*'))
        .where((s) => s.trim().isNotEmpty)
        .toList();

    // Fast path: single segment (most common case)
    if (segments.length <= 1) {
      final t = _parseOne(m);
      return t == null ? const [] : [t];
    }

    // Compound: parse each segment, keep only the ones with an amount.
    final out = <TransactionModel>[];
    for (final seg in segments) {
      final t = _parseOne(seg.trim(), isIncomeOverride: isIncome);
      if (t != null) out.add(t);
    }
    return out;
  }

  TransactionModel? _parseOne(String segment, {bool? isIncomeOverride}) {
    final amt = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(segment);
    if (amt == null) return null;
    final amount = double.parse(amt.group(1)!);
    if (amount <= 0) return null;

    final isIncome = isIncomeOverride ??
        (segment.contains('earned') || segment.contains('received') ||
            segment.contains('salary') || segment.contains('income'));

    final category = _guessCategory(segment);
    final date = segment.contains('yesterday')
        ? DateTime.now().subtract(const Duration(days: 1))
        : segment.contains('day before')
            ? DateTime.now().subtract(const Duration(days: 2))
            : DateTime.now();

    return TransactionModel(
      id: const Uuid().v4(),
      amount: amount,
      type: isIncome ? TransactionType.income : TransactionType.expense,
      category: category,
      date: date,
      note: _extractNote(segment, category),
      createdAt: DateTime.now(),
    );
  }

  String _guessCategory(String m) {
    const map = {
      'food': ['food', 'biryani', 'lunch', 'dinner', 'breakfast', 'restaurant', 'pizza', 'swiggy', 'zomato', 'coffee', 'chai', 'snack', 'hotel', 'dosa', 'idli'],
      'transport': ['uber', 'ola', 'auto', 'petrol', 'fuel', 'bus', 'metro', 'train', 'cab', 'travel', 'rickshaw', 'rapido'],
      'groceries': ['grocery', 'groceries', 'vegetables', 'milk', 'kirana', 'supermarket', 'bigbasket', 'zepto'],
      'entertainment': ['movie', 'netflix', 'game', 'concert', 'spotify', 'party', 'club', 'ticket'],
      'shopping': ['shopping', 'clothes', 'amazon', 'flipkart', 'myntra', 'shoes', 'shirt', 'phone', 'headphones'],
      'health': ['medicine', 'doctor', 'pharmacy', 'hospital', 'gym'],
      'education': ['books', 'tuition', 'course', 'fees', 'college', 'udemy'],
      'rent': ['rent', 'hostel', 'pg '],
      'utilities': ['electricity', 'wifi', 'internet', 'mobile recharge', 'recharge', 'bill'],
    };
    for (final e in map.entries) {
      for (final kw in e.value) {
        if (m.contains(kw)) return e.key;
      }
    }
    return 'other';
  }

  String? _extractNote(String m, String category) {
    final match = RegExp(r'(?:on|for|at)\s+(.+?)(?:\s+yesterday|\s+today)?$').firstMatch(m);
    var raw = match?.group(1)?.trim();
    if (raw == null || raw.isEmpty || raw.length > 60) return null;
    // Don't duplicate the category in the note: "spent 1200 on shopping"
    // should show note=null, not note="shopping".
    if (raw.toLowerCase() == category.toLowerCase()) return null;
    // Strip leading "spent"/"paid" residue in compound segments
    raw = raw.replaceFirst(RegExp(r'^(?:spent|paid|bought|log(?:ged)?|add(?:ed)?)\s+'), '').trim();
    if (raw.isEmpty) return null;
    return raw;
  }

  Future<AssistantReply?> _askLlm(
      String message,
      UserSettings settings,
      List<TransactionModel> transactions,
      List<dynamic> recurring) async {
    try {
      // Grounding: full computed facts + compact transaction list.
      final engine = InsightsEngine(
          transactions: transactions,
          recurring: recurring.cast(),
          settings: settings);
      final facts = engine.computeFacts();
      final recent = transactions.take(30).map((t) => {
            'amount': t.amount,
            'type': t.type == TransactionType.income ? 'in' : 'out',
            'category': t.category,
            'date': t.date.toIso8601String().substring(0, 10),
            'note': t.note ?? '',
          }).toList();
      facts['recent_transactions'] = recent;

      final res = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        // UTF-8 bytes: the http package writes String bodies as latin1,
        // which corrupts ₹/emoji and causes HTTP 400.
        body: utf8.encode(jsonEncode({
          'model': 'openai-fast', // reasoning models exhaust tokens thinking -> 400
          'max_tokens': 1200,
          'messages': [
            {
              'role': 'system',
              'content':
                  'You are "Sage", the AI assistant inside the Safe-to-Spend expense tracker app. '
                  'You can see the user\'s REAL financial data (JSON "FACTS"). '
                  'Capabilities: '
                  'A) To log a transaction, reply with ONLY JSON: '
                  '{"add_transaction": {"amount": number, "type": "expense|income", '
                  '"category": "one lowercase word", "note": "short", "date": "YYYY-MM-DD"}} '
                  'B) For "can I afford X" questions: compare with safe_to_spend/PROJECTED facts, '
                  'give a clear yes/no/depends + one practical tip. '
                  'C) Otherwise answer from the facts warmly and briefly (under 60 words). '
                  'Rules: never invent numbers not in the facts; use the given currency symbol; '
                  'for follow-up questions use the conversation history. '
                  'Currency: ${settings.currencySymbol}.'
            },
            ..._history.take(_maxHistory),
            {'role': 'user', 'content': message}
          ],
        })),
      ).timeout(const Duration(seconds: 45));

      if (res.statusCode != 200) return null;
      final envelope = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final text = (envelope['choices']?[0]?['message']?['content'] ?? '').toString().trim();
      if (text.isEmpty) return null;

      // If the LLM returned an add-transaction action, perform it.
      final addAction = _extractAddAction(text);
      if (addAction != null) {
        final tx = _txFromAction(addAction);
        if (tx != null) {
          await store.addTransaction(tx);
          _remember('user', message);
          _remember('assistant', 'Logged transaction ${tx.amount}');
          return AssistantReply(
            text: 'Logged! ${tx.type == TransactionType.income ? "Income" : "Expense"} of '
                '${settings.currencySymbol}${tx.amount.toStringAsFixed(0)} (${tx.category})'
                '${tx.note != null && tx.note!.isNotEmpty ? ' — "${tx.note}"' : ""}. '
                'Your Safe to Spend is updated.',
            addedTransaction: tx,
          );
        }
      }

      _remember('user', message);
      _remember('assistant', text);
      return AssistantReply(text: _stripJson(text));
    } catch (e) {
      if (kDebugMode) debugPrint('ChatAssistant LLM error: $e');
      return null;
    }
  }

  Map<String, dynamic>? _extractAddAction(String text) {
    final m = RegExp(r'\{[^{}]*"add_transaction"[\s\S]*?\}').firstMatch(text);
    if (m == null) return null;
    try {
      final parsed = jsonDecode(m.group(0)!) as Map<String, dynamic>;
      final action = parsed['add_transaction'];
      if (action is Map<String, dynamic>) return action;
    } catch (_) {}
    return null;
  }

  TransactionModel? _txFromAction(Map<String, dynamic> a) {
    final amount = (a['amount'] is num)
        ? (a['amount'] as num).toDouble()
        : double.tryParse('${a['amount']}');
    if (amount == null || amount <= 0) return null;
    final type = (a['type'] ?? 'expense').toString().toLowerCase().contains('income')
        ? TransactionType.income
        : TransactionType.expense;
    DateTime date = DateTime.now();
    final d = a['date']?.toString();
    if (d != null) {
      date = DateTime.tryParse(d) ?? date;
    }
    return TransactionModel(
      id: const Uuid().v4(),
      amount: amount,
      type: type,
      category: (a['category'] ?? 'other').toString().toLowerCase().trim(),
      date: date,
      note: a['note']?.toString(),
      createdAt: DateTime.now(),
    );
  }

  String _stripJson(String text) {
    // Remove any JSON the model emitted so the user only sees prose.
    return text
        .replaceAll(RegExp(r'\{[\s\S]*?\}'), '')
        .replaceAll(RegExp(r'```[a-z]*'), '')
        .trim();
  }

  AssistantReply _localFallback(
      String message, UserSettings settings, List<TransactionModel> txs) {
    final m = message.toLowerCase();
    final now = DateTime.now();
    if (m.contains('balance') || m.contains('safe to spend') || (m.contains('how much') && m.contains('spend') == false)) {
      return AssistantReply(
          text: 'Your current balance is ${settings.currencySymbol}${settings.currentBalance.toStringAsFixed(0)}.');
    }
    if (m.contains('month') && (m.contains('spend') || m.contains('spent'))) {
      double spent = 0;
      for (final t in txs) {
        if (t.type == TransactionType.expense &&
            t.date.year == now.year && t.date.month == now.month) {
          spent += t.amount;
        }
      }
      return AssistantReply(
          text: 'You\'ve spent ${settings.currencySymbol}${spent.toStringAsFixed(0)} this month. '
              '(Offline mode — AI phrasing unavailable, numbers are still exact.)');
    }
    return AssistantReply(
      text: 'I\'m offline right now, but I can still log transactions instantly. '
          'Try: "spent 120 on coffee".',
    );
  }
}

class AssistantReply {
  final String text;
  final TransactionModel? addedTransaction;
  AssistantReply({required this.text, this.addedTransaction});
}
