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

    // Step 1: instant local parse for obvious add-intent (works offline).
    final parsed = _quickParse(message, settings.currencySymbol);
    if (parsed != null) {
      await store.addTransaction(parsed);
      _remember('user', message);
      _remember('assistant', 'Logged ${parsed.type == TransactionType.income ? "income" : "expense"} of ${settings.currencySymbol}${parsed.amount} (${parsed.category}).');
      return AssistantReply(
        text: 'Logged ${parsed.type == TransactionType.income ? "income" : "expense"} of '
            '${settings.currencySymbol}${parsed.amount.toStringAsFixed(0)} '
            '(${parsed.category})${parsed.note != null ? ' — "${parsed.note}"' : ""}. '
            'Your Safe to Spend is updated.',
        addedTransaction: parsed,
      );
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

  TransactionModel? _quickParse(String message, String cur) {
    final m = message.toLowerCase().trim();
    final isIncome = m.contains('earned') || m.contains('received') ||
        m.contains('salary') || m.contains('add income') ||
        RegExp(r'\blog\b.*\b(salary|income)\b').hasMatch(m);
    final isExpense = m.contains('spent') || m.contains('paid') || m.contains('bought') ||
        m.contains('add expense');
    if (!isIncome && !isExpense) return null;

    final amt = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(m);
    if (amt == null) return null;
    final amount = double.parse(amt.group(1)!);

    final category = _guessCategory(m);
    var date = DateTime.now();
    if (m.contains('yesterday')) {
      date = DateTime.now().subtract(const Duration(days: 1));
    } else if (m.contains('day before')) {
      date = DateTime.now().subtract(const Duration(days: 2));
    }

    return TransactionModel(
      id: const Uuid().v4(),
      amount: amount,
      type: isIncome && !m.contains('spent') ? TransactionType.income : TransactionType.expense,
      category: category,
      date: date,
      note: _extractNote(m),
      createdAt: DateTime.now(),
    );
  }

  String _guessCategory(String m) {
    const map = {
      'food': ['food', 'biryani', 'lunch', 'dinner', 'breakfast', 'restaurant', 'pizza', 'swiggy', 'zomato', 'coffee', 'chai', 'snack', 'hotel', 'dosa', 'idli'],
      'transport': ['uber', 'ola', 'auto', 'petrol', 'fuel', 'bus', 'metro', 'train', 'cab', 'travel'],
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

  String? _extractNote(String m) {
    final match = RegExp(r'(?:on|for|at)\s+(.+?)(?:\s+yesterday|\s+today)?$').firstMatch(m);
    final raw = match?.group(1)?.trim();
    if (raw == null || raw.isEmpty || raw.length > 60) return null;
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
