import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/transaction_model.dart';
import '../models/recurring_payment_model.dart';
import '../models/user_settings_model.dart';

/// Deterministic, local statistical analysis of the user's finances.
/// All numbers here are computed on-device from the local database —
/// the LLM only phrases them into human sentences.
class InsightsEngine {
  final List<TransactionModel> transactions;
  final List<RecurringPaymentModel> recurring;
  final UserSettings settings;

  InsightsEngine({
    required this.transactions,
    required this.recurring,
    required this.settings,
  });

  String get _cur => settings.currencySymbol;

  bool get hasData => transactions.isNotEmpty;

  List<TransactionModel> get _expenses =>
      transactions.where((t) => t.type == TransactionType.expense).toList();

  /// Compact facts about the user's data, sent to the LLM as grounding.
  Map<String, dynamic> computeFacts() {
    final now = DateTime.now();
    final expenses = _expenses;
    final incomes = transactions.where((t) => t.type == TransactionType.income).toList();

    // This month vs last month
    double spentThisMonth = 0, spentLastMonth = 0, earnedThisMonth = 0;
    final lastMonth = DateTime(now.year, now.month - 1);
    for (final t in transactions) {
      final isThis = t.date.year == now.year && t.date.month == now.month;
      final isLast = t.date.year == lastMonth.year && t.date.month == lastMonth.month;
      if (t.type == TransactionType.expense) {
        if (isThis) spentThisMonth += t.amount;
        if (isLast) spentLastMonth += t.amount;
      } else if (isThis) {
        earnedThisMonth += t.amount;
      }
    }

    // Top categories this month
    final catTotals = <String, double>{};
    for (final t in expenses) {
      if (t.date.year == now.year && t.date.month == now.month) {
        catTotals[t.category] = (catTotals[t.category] ?? 0) + t.amount;
      }
    }
    final topCats = catTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Last-month category totals (for trend comparison)
    final lastCatTotals = <String, double>{};
    for (final t in expenses) {
      if (t.date.year == lastMonth.year && t.date.month == lastMonth.month) {
        lastCatTotals[t.category] = (lastCatTotals[t.category] ?? 0) + t.amount;
      }
    }

    // Weekend vs weekday spending (last 8 weeks)
    double weekend = 0, weekday = 0;
    int weekendDays = 0, weekdayDays = 0;
    for (var d = now.subtract(const Duration(days: 56));
        d.isBefore(now);
        d = d.add(const Duration(days: 1))) {
      final isWeekend = d.weekday == DateTime.saturday || d.weekday == DateTime.sunday;
      if (isWeekend) weekendDays++; else weekdayDays++;
    }
    for (final t in expenses) {
      if (now.difference(t.date).inDays <= 56) {
        final isWeekend = t.date.weekday == DateTime.saturday || t.date.weekday == DateTime.sunday;
        if (isWeekend) weekend += t.amount; else weekday += t.amount;
      }
    }
    final weekendPerDay = weekendDays > 0 ? weekend / weekendDays : 0.0;
    final weekdayPerDay = weekdayDays > 0 ? weekday / weekdayDays : 0.0;

    // Daily burn rate (this month)
    final dayOfMonth = math.max(now.day, 1);
    final burnRate = spentThisMonth / dayOfMonth;
    final projectedMonth = burnRate * _daysInMonth(now);

    // Weekly spending, last 4 weeks (for trend + chart)
    final weeklySpend = <double>[0, 0, 0, 0]; // [4w ago .. this week]
    for (final t in expenses) {
      final weeksAgo = now.difference(t.date).inDays ~/ 7;
      if (weeksAgo >= 0 && weeksAgo < 4) weeklySpend[3 - weeksAgo] += t.amount;
    }

    // Recurring obligations next 30 days
    double upcoming = 0;
    final upcomingList = <Map<String, dynamic>>[];
    final cutoff = now.add(const Duration(days: 30));
    for (final p in recurring.where((p) => p.isActive)) {
      var next = p.nextPaymentDate;
      int guard = 0;
      while ((next.isBefore(cutoff) || _sameDay(next, cutoff)) && guard++ < 100) {
        if (p.endDate != null && next.isAfter(p.endDate!)) break;
        upcoming += p.amount;
        upcomingList.add({'name': p.name, 'amount': p.amount, 'date': next.toIso8601String().substring(0, 10)});
        next = _nextDate(next, p.frequency);
      }
    }

    // Anomaly detection: per-category, flag expenses > 2.5x category average
    final anomalies = <Map<String, dynamic>>[];
    final catAllTime = <String, List<double>>{};
    for (final t in expenses) {
      catAllTime.putIfAbsent(t.category, () => []).add(t.amount);
    }
    final catAvg = <String, double>{};
    catAllTime.forEach((cat, amounts) {
      var s = 0.0;
      for (final a in amounts) {
        s += a;
      }
      catAvg[cat] = s / amounts.length;
    });
    for (final t in expenses) {
      final amounts = catAllTime[t.category]!;
      if (amounts.length < 3) continue; // need history
      final avg = catAvg[t.category]!;
      if (t.amount > avg * 2.5 && t.amount > 100) {
        anomalies.add({
          'category': t.category,
          'amount': t.amount,
          'typical': avg,
          'note': t.note ?? '',
          'date': t.date.toIso8601String().substring(0, 10),
        });
      }
    }

    // Biggest single transaction this month
    TransactionModel? biggest;
    for (final t in expenses) {
      if (t.date.year == now.year && t.date.month == now.month) {
        if (biggest == null || t.amount > biggest.amount) biggest = t;
      }
    }

    final savingsRate = earnedThisMonth > 0
        ? ((earnedThisMonth - spentThisMonth) / earnedThisMonth) * 100
        : 0.0;

    return {
      'today': now.toIso8601String().substring(0, 10),
      'currency': _cur,
      'current_balance': settings.currentBalance,
      'transactions_count': transactions.length,
      'spent_this_month': spentThisMonth,
      'spent_last_month': spentLastMonth,
      'earned_this_month': earnedThisMonth,
      'month_over_month_change_pct': spentLastMonth > 0
          ? ((spentThisMonth - spentLastMonth) / spentLastMonth) * 100
          : null,
      'projected_month_end_spend': projectedMonth,
      'daily_burn_rate': burnRate,
      'weekly_spend_last4': weeklySpend,
      'top_categories_this_month': [
        for (final e in topCats.take(5))
          {
            'category': e.key,
            'amount': e.value,
            'last_month': lastCatTotals[e.key] ?? 0,
            'trend_pct': (lastCatTotals[e.key] ?? 0) > 0
                ? ((e.value - (lastCatTotals[e.key] ?? 0)) / lastCatTotals[e.key]!) * 100
                : null,
          }
      ],
      'weekend_vs_weekday_per_day': {
        'weekend': weekendPerDay,
        'weekday': weekdayPerDay,
        'weekend_ratio': weekdayPerDay > 0 ? weekendPerDay / weekdayPerDay : null,
      },
      'upcoming_obligations_30d': upcoming,
      'upcoming_obligations_list': upcomingList,
      'savings_rate_pct': savingsRate,
      'anomalies': anomalies.take(4).toList(),
      'biggest_expense_this_month': biggest == null
          ? null
          : {'category': biggest.category, 'amount': biggest.amount, 'note': biggest.note ?? ''},
    };
  }

  /// Insights shown in the UI before/without an LLM. Always accurate
  /// because they are computed locally.
  List<Insight> generateLocalInsights() {
    final facts = computeFacts();
    final out = <Insight>[];
    final cur = _cur;

    if (!hasData) {
      out.add(Insight(
        icon: '👋',
        title: 'Add some transactions first',
        body: 'Insights get smarter as you log income and expenses. '
            'Try the Assistant — say "spent 250 on biryani yesterday".',
        tone: InsightTone.neutral,
      ));
      return out;
    }

    final mom = facts['month_over_month_change_pct'] as double?;
    if (mom != null) {
      final up = mom > 0;
      out.add(Insight(
        icon: up ? '📈' : '📉',
        title: 'Spending is ${up ? 'up' : 'down'} ${mom.abs().toStringAsFixed(0)}% vs last month',
        body: 'You\'ve spent $cur${(facts['spent_this_month'] as double).toStringAsFixed(0)} this month '
            'vs $cur${(facts['spent_last_month'] as double).toStringAsFixed(0)} last month.',
        tone: up ? InsightTone.warning : InsightTone.good,
      ));
    }

    final projected = facts['projected_month_end_spend'] as double;
    if (projected > 0) {
      out.add(Insight(
        icon: '🔮',
        title: 'Projected month-end spend: $cur${projected.toStringAsFixed(0)}',
        body: 'At your current pace of $cur${(facts['daily_burn_rate'] as double).toStringAsFixed(0)}/day.',
        tone: InsightTone.neutral,
      ));
    }

    final wv = facts['weekend_vs_weekday_per_day'] as Map<String, dynamic>;
    final ratio = wv['weekend_ratio'] as double?;
    if (ratio != null && ratio > 1.3) {
      out.add(Insight(
        icon: '🍔',
        title: 'Weekends cost you ${((ratio - 1) * 100).toStringAsFixed(0)}% more per day',
        body: 'Weekend: $cur${(wv['weekend'] as double).toStringAsFixed(0)}/day vs '
            'weekday: $cur${(wv['weekday'] as double).toStringAsFixed(0)}/day.',
        tone: InsightTone.warning,
      ));
    }

    final cats = (facts['top_categories_this_month'] as List).cast<Map>();
    if (cats.isNotEmpty) {
      final top = cats.first;
      final trend = top['trend_pct'] as double?;
      var body = '$cur${(top['amount'] as double).toStringAsFixed(0)} this month '
          '(${((top['amount'] as double) / math.max(facts['spent_this_month'] as double, 1) * 100).toStringAsFixed(0)}% of spending)';
      if (trend != null) {
        body += trend > 0
            ? ' — up ${trend.abs().toStringAsFixed(0)}% vs last month.'
            : ' — down ${trend.abs().toStringAsFixed(0)}% vs last month.';
      }
      out.add(Insight(
        icon: '🏷️',
        title: 'Biggest category: ${top['category']}',
        body: body,
        tone: InsightTone.neutral,
      ));
    }

    // Anomalies
    for (final a in (facts['anomalies'] as List).cast<Map>()) {
      out.add(Insight(
        icon: '⚠️',
        title: 'Unusual ${a['category']} expense: $cur${(a['amount'] as double).toStringAsFixed(0)}',
        body: 'Typical ${a['category']} spends are $cur${(a['typical'] as double).toStringAsFixed(0)}.'
            '${a['note'].toString().isNotEmpty ? ' ("${a['note']}")' : ""}',
        tone: InsightTone.warning,
      ));
    }

    final savings = facts['savings_rate_pct'] as double;
    if (facts['earned_this_month'] as double > 0) {
      out.add(Insight(
        icon: savings >= 20 ? '🏆' : '🟡',
        title: 'Savings rate: ${savings.toStringAsFixed(0)}%',
        body: savings >= 20
            ? 'Great pace — you\'re keeping more than a fifth of what you earn.'
            : 'Aim for 20%+. Trimming your top category is the fastest lever.',
        tone: savings >= 20 ? InsightTone.good : InsightTone.warning,
      ));
    }

    return out;
  }

  int _daysInMonth(DateTime d) {
    final next = DateTime(d.year, d.month + 1, 1);
    return next.subtract(const Duration(days: 1)).day;
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime _nextDate(DateTime current, RecurrenceFrequency frequency) {
    switch (frequency) {
      case RecurrenceFrequency.daily: return current.add(const Duration(days: 1));
      case RecurrenceFrequency.weekly: return current.add(const Duration(days: 7));
      case RecurrenceFrequency.monthly: return DateTime(current.year, current.month + 1, current.day);
      case RecurrenceFrequency.yearly: return DateTime(current.year + 1, current.month, current.day);
    }
  }
}

enum InsightTone { good, warning, neutral }

class Insight {
  final String icon;
  final String title;
  final String body;
  final InsightTone tone;

  Insight({required this.icon, required this.title, required this.body, required this.tone});
}

/// Calls a free, keyless OpenAI-compatible endpoint (Pollinations) to turn
/// computed facts into warm, human-sounding advice. Falls back to the
/// local insights if the network is unavailable — the demo never breaks.
class AiAdvisor {
  static const _endpoint = 'https://text.pollinations.ai/openai';

  int _attempts = 3;
  int _timeoutSeconds = 45;
  String? lastError; // surfaced in UI for diagnosis

  Future<String?> generateInsightNarrative(Map<String, dynamic> facts) async {
    for (var attempt = 1; attempt <= _attempts; attempt++) {
      final result = await _tryOnce(facts);
      if (result != null) return result;
      if (attempt < _attempts) {
        // Pollinations free tier: 1 reply / 45s per IP — back off accordingly.
        await Future.delayed(const Duration(seconds: 20));
      }
    }
    return null;
  }

  Future<String?> _tryOnce(Map<String, dynamic> facts) async {
    try {
      final res = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        // NOTE: encode as UTF-8 bytes — the http package defaults String
        // bodies to latin1, which corrupts ₹/emoji and yields HTTP 400.
        body: utf8.encode(jsonEncode({
          'model': 'openai-fast', // reasoning models (gpt-oss) exhaust tokens thinking -> 400
          'max_tokens': 2000,
          'messages': [
            {
              'role': 'system',
              'content':
                  'You are "Sage", a warm personal finance coach inside a student expense-tracker app. '
                  'You will be given verified financial facts computed by the app (JSON). '
                  'Write 3 short, warm insights in plain English. Rules: '
                  '1) ONLY use the numbers given — never invent or estimate new numbers. '
                  '2) Each insight: one short sentence of observation + one short sentence of friendly advice. '
                  '3) Use the currency symbol provided. '
                  '4) If an "anomalies" list is present, one of the insights MUST address it. '
                  '5) Return ONLY a JSON array like: '
                  '[{"icon":"📊","title":"...","body":"...","tone":"good|warning|neutral"}] '
                  'with exactly 3 items. No markdown fences, no extra text.'
            },
            {'role': 'user', 'content': jsonEncode(facts)}
          ],
        })),
      )
          .timeout(Duration(seconds: _timeoutSeconds));

      if (res.statusCode != 200) {
        lastError = 'HTTP ${res.statusCode}';
        return null;
      }
      // Parse the API envelope first, then the insights array inside
      // choices[0].message.content (which is a JSON-encoded string itself).
      final envelope = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final content = (envelope['choices']?[0]?['message']?['content'] ?? '') as String;
      if (content.trim().isEmpty) {
        lastError = 'empty content';
        return null;
      }
      final cleaned = _extractJson(content);
      final list = jsonDecode(cleaned) as List;
      if (list.isEmpty) {
        lastError = 'empty list';
        return null;
      }
      // Validated shape -> return raw JSON string for the UI to parse.
      return cleaned;
    } catch (e) {
      lastError = 'exception: $e';
      if (kDebugMode) debugPrint('AiAdvisor error: $e');
      return null;
    }
  }

  /// Ask the LLM a one-off question about the user's finances
  /// (used by the Assistant for affordability checks etc.).
  Future<String?> askQuestion(String question, Map<String, dynamic> facts) async {
    for (var attempt = 1; attempt <= _attempts; attempt++) {
      try {
        final res = await http.post(
          Uri.parse(_endpoint),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
          body: utf8.encode(jsonEncode({
            'model': 'openai-fast',
            'max_tokens': 800,
            'messages': [
              {
                'role': 'system',
                'content': 'You are Sage, a friendly money coach in a student expense tracker. '
                    'Answer the user\'s question using ONLY the verified financial facts given (JSON). '
                    'Be warm and brief (max 3 sentences). For "can I afford X" questions: compare X\'s '
                    'price against safe_to_spend, say clearly yes/no/depends, and give one practical tip. '
                    'Never invent numbers. Currency symbol is provided in the facts. '
                    'Return only plain text, no markdown.'
              },
              {
                'role': 'user',
                'content': 'FACTS: ${jsonEncode(facts)}\n\nQUESTION: $question'
              }
            ],
          })),
        ).timeout(Duration(seconds: _timeoutSeconds));

        if (res.statusCode != 200) {
          lastError = 'HTTP ${res.statusCode}';
        } else {
          final envelope = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
          final content = (envelope['choices']?[0]?['message']?['content'] ?? '').toString().trim();
          if (content.isNotEmpty) return content;
          lastError = 'empty content';
        }
      } catch (e) {
        lastError = 'exception: $e';
      }
      if (attempt < _attempts) await Future.delayed(const Duration(seconds: 20));
    }
    return null;
  }

  String _extractJson(String raw) {
    final start = raw.indexOf('[');
    final end = raw.lastIndexOf(']');
    if (start == -1 || end == -1 || end <= start) return raw;
    return raw.substring(start, end + 1);
  }
}

class AiInsight {
  final String icon;
  final String title;
  final String body;
  final String tone;

  AiInsight({required this.icon, required this.title, required this.body, required this.tone});

  factory AiInsight.fromJson(Map<String, dynamic> j) => AiInsight(
        icon: (j['icon'] as String?) ?? '📊',
        title: (j['title'] as String?) ?? 'Insight',
        body: (j['body'] as String?) ?? '',
        tone: (j['tone'] as String?) ?? 'neutral',
      );
}
