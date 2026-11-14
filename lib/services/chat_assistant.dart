import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/transaction_model.dart';
import '../models/user_settings_model.dart';
import '../models/recurring_payment_model.dart';
import 'app_store.dart';

/// AI chat assistant. Two abilities:
/// 1) Natural-language data entry: "spent 250 on biryani yesterday"
///    -> the LLM returns a structured transaction which we insert.
/// 2) Q&A over the user's local data: "how much did I spend on food?"
///    -> we compute the answer locally from the DB (grounding), and the
///    LLM only phrases it, or we answer directly without the LLM.
class ChatAssistant {
  final AppStore store;
  ChatAssistant(this.store);

  static const _endpoint = 'https://text.pollinations.ai/openai';

  Future<AssistantReply> handle(String message) async {
    final settings = await store.getSettings();
    final transactions = await store.getTransactions();

    // Step 1: try to parse a quick add-intent locally first (fast path,
    // no network). Falls through to the LLM if ambiguous.
    final parsed = _quickParse(message, settings.currencySymbol);
    if (parsed != null) {
      await store.addTransaction(parsed);
      return AssistantReply(
        text: 'Logged ${parsed.type == TransactionType.income ? "income" : "expense"} of '
            '${settings.currencySymbol}${parsed.amount.toStringAsFixed(0)} '
            '(${parsed.category})${parsed.note != null ? ' — "${parsed.note}"' : ""}. '
            'Anything else?',
        addedTransaction: parsed,
      );
    }

    // Step 2: LLM with grounded data (retries — Pollinations free tier is
    // 1 reply / 45s per IP).
    AssistantReply? reply;
    for (var attempt = 0; attempt < 3; attempt++) {
      if (attempt > 0) await Future.delayed(const Duration(seconds: 20));
      reply = await _askLlm(message, settings, transactions);
      if (reply != null) break;
    }
    if (reply != null) return reply;

    // Step 3: offline fallback — answer simple questions locally.
    return _localFallback(message, settings, transactions);
  }

  TransactionModel? _quickParse(String message, String cur) {
    final m = message.toLowerCase().trim();
    final isIncome = m.contains('earned') || m.contains('received') ||
        m.contains('got ') || m.contains('salary') || m.contains('income') ||
        m.contains('add income');
    final isExpense = m.contains('spent') || m.contains('paid') || m.contains('bought') ||
        m.contains('bought') || m.contains('bought') || m.contains('add expense');
    if (!isIncome && !isExpense) return null;

    final amt = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(m);
    if (amt == null) return null;
    final amount = double.parse(amt.group(1)!);

    final category = _guessCategory(m);
    var date = DateTime.now();
    if (m.contains('yesterday')) {
      date = DateTime.now().subtract(const Duration(days: 1));
    }

    final note = _extractNote(m);

    return TransactionModel(
      id: const Uuid().v4(),
      amount: amount,
      type: isIncome && !m.contains('spent') ? TransactionType.income : TransactionType.expense,
      category: category,
      date: date,
      note: note,
      createdAt: DateTime.now(),
    );
  }

  String _guessCategory(String m) {
    const map = {
      'food': ['food', 'biryani', 'lunch', 'dinner', 'breakfast', 'restaurant', 'pizza', 'swiggy', 'zomato', 'coffee', 'chai', 'snack', 'hotel'],
      'transport': ['uber', 'ola', 'auto', 'petrol', 'fuel', 'bus', 'metro', 'train', 'cab', 'travel'],
      'groceries': ['grocery', 'groceries', 'vegetables', 'milk', 'kirana', 'supermarket', 'bigbasket', 'zepto'],
      'entertainment': ['movie', 'netflix', 'game', 'concert', 'spotify', 'party', 'club'],
      'shopping': ['shopping', 'clothes', 'amazon', 'flipkart', 'myntra', 'shoes', 'shirt', 'phone'],
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
      String message, UserSettings settings, List<TransactionModel> transactions) async {
    try {
      // Grounding: compact data summary so the LLM answers from real data.
      final summary = _dataSummary(settings, transactions);
      final res = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        // UTF-8 bytes: the http package writes String bodies as latin1,
        // which corrupts ₹/emoji and causes HTTP 400.
        body: utf8.encode(jsonEncode({
          'model': 'openai-fast', // reasoning models exhaust tokens thinking -> 400
          'max_tokens': 1500,
          'messages': [
            {
              'role': 'system',
              'content':
                  'You are "Sage", the AI assistant inside the Safe-to-Spend expense tracker app. '
                  'You can see the user\'s real financial data below (JSON). '
                  'Answer questions using ONLY that data. If asked to log a transaction, first reply '
                  'with JSON: {"add_transaction": {"amount": number, "type": "expense|income", '
                  '"category": "one word", "note": "short", "date": "YYYY-MM-DD"}} '
                  'The app will insert it — do NOT refuse. Otherwise chat warmly and briefly. '
                  'If the user asks something unrelated to finance, gently steer back. '
                  'Currency: ${settings.currencySymbol}. Keep replies under 60 words.\n\n'
                  'USER DATA: $summary'
            },
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
          return AssistantReply(
            text: '✅ Logged! ${tx.type == TransactionType.income ? "Income" : "Expense"} of '
                '${settings.currencySymbol}${tx.amount.toStringAsFixed(0)} (${tx.category})'
                '${tx.note != null && tx.note!.isNotEmpty ? ' — "${tx.note}"' : ""}. '
                'Your Safe to Spend is updated.',
            addedTransaction: tx,
          );
        }
      }

      return AssistantReply(text: _stripJson(text));
    } catch (e) {
      if (kDebugMode) debugPrint('ChatAssistant LLM error: $e');
      return null;
    }
  }

  Map<String, dynamic> _dataSummary(UserSettings s, List<TransactionModel> txs) {
    final now = DateTime.now();
    double spentMonth = 0, earnedMonth = 0;
    final byCat = <String, double>{};
    for (final t in txs) {
      if (t.date.year == now.year && t.date.month == now.month) {
        if (t.type == TransactionType.expense) {
          spentMonth += t.amount;
          byCat[t.category] = (byCat[t.category] ?? 0) + t.amount;
        } else {
          earnedMonth += t.amount;
        }
      }
    }
    final recent = txs.take(30).map((t) => {
          'amount': t.amount,
          'type': t.type == TransactionType.income ? 'income' : 'expense',
          'category': t.category,
          'date': t.date.toIso8601String().substring(0, 10),
          'note': t.note ?? '',
        }).toList();

    return {
      'currency': s.currencySymbol,
      'current_balance': s.currentBalance,
      'spent_this_month': spentMonth,
      'earned_this_month': earnedMonth,
      'by_category_this_month': byCat,
      'recent_transactions': recent,
    };
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
    final amount = (a['amount'] is num) ? (a['amount'] as num).toDouble() : double.tryParse('${a['amount']}');
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

  AssistantReply _localFallback(String message, UserSettings settings, List<TransactionModel> txs) {
    final m = message.toLowerCase();
    final now = DateTime.now();
    if (m.contains('balance') || m.contains('safe') || m.contains('spend') && m.contains('how much')) {
      return AssistantReply(text: 'Your current balance is ${settings.currencySymbol}${settings.currentBalance.toStringAsFixed(0)}.');
    }
    if (m.contains('month') && (m.contains('spend') || m.contains('spent'))) {
      double spent = 0;
      for (final t in txs) {
        if (t.type == TransactionType.expense &&
            t.date.year == now.year && t.date.month == now.month) {
          spent += t.amount;
        }
      }
      return AssistantReply(text: 'You\'ve spent ${settings.currencySymbol}${spent.toStringAsFixed(0)} this month. '
          '(Offline mode — AI phrasing unavailable, numbers are still exact.)');
    }
    return AssistantReply(
      text: 'I\'m offline right now, but I can still log transactions. '
          'Try: "spent 120 on coffee".',
    );
  }
}

class AssistantReply {
  final String text;
  final TransactionModel? addedTransaction;
  AssistantReply({required this.text, this.addedTransaction});
}
