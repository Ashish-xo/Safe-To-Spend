import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/transaction_model.dart';
import '../../models/user_settings_model.dart';
import '../../services/app_store.dart';
import '../../services/insights_engine.dart';
import '../../theme/app_theme.dart';

/// AI Insights screen: deterministic local analysis (always accurate)
/// + AI-generated narrative (graceful fallback to local if offline).
class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  List<TransactionModel>? _transactions;
  UserSettings? _settings;
  List<Insight> _localInsights = [];
  List<AiInsight> _aiInsights = [];
  bool _aiLoading = false;
  bool _aiFailed = false;
  String? _aiError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final store = AppStore();
    await store.init();
    final settings = await store.getSettings();
    final txs = await store.getTransactions();
    final rec = await store.getRecurringPayments();
    final engine = InsightsEngine(transactions: txs, recurring: rec, settings: settings);

    setState(() {
      _settings = settings;
      _transactions = txs;
      _localInsights = engine.generateLocalInsights();
      _aiInsights = [];
      _aiFailed = false;
    });

    await _generateAi(engine);
  }

  Future<void> _generateAi(InsightsEngine engine) async {
    setState(() => _aiLoading = true);
    final advisor = AiAdvisor();
    final raw = await advisor.generateInsightNarrative(engine.computeFacts());
    if (!mounted) return;
    if (raw == null) {
      setState(() {
        _aiLoading = false;
        _aiFailed = true;
        _aiError = advisor.lastError;
      });
      return;
    }
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => AiInsight.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _aiInsights = list;
        _aiLoading = false;
      });
    } catch (_) {
      setState(() {
        _aiLoading = false;
        _aiFailed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_transactions == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: RefreshIndicator(
        color: AppColors.primaryGreen,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
          children: [
            Text('AI INSIGHTS',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: AppColors.textSecondary(isDark))),
            const SizedBox(height: 2),
            const Text('Your money, explained',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 24),

            // WEEKLY SPENDING CHART
            if ((_transactions?.length ?? 0) > 0) ...[
              _weeklyChart(isDark),
              const SizedBox(height: 28),
            ],

            // --- AI-generated insights ---
            if (_aiLoading)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.card(isDark),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.primaryGreen),
                    ),
                    const SizedBox(height: 14),
                    Text('Sage is analysing your spending…',
                        style: TextStyle(
                            fontSize: 13.5, color: AppColors.textSecondary(isDark))),
                  ],
                ),
              ),
            if (_aiFailed)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: isDark ? 0.1 : 1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bolt_outlined, size: 17, color: AppColors.primaryGreen),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'AI phrasing is offline right now — locally-computed insights below '
                        '${_aiError == null ? "" : "($_aiError) "}(all numbers are still exact).',
                        style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary(isDark)),
                      ),
                    ),
                  ],
                ),
              ),
            for (final i in _aiInsights)
              _insightCard(isDark, icon: i.icon, title: i.title, body: i.body, tone: i.tone, ai: true),

            if (_aiInsights.isNotEmpty || _aiFailed || !_aiLoading) ...[
              const SizedBox(height: 28),
              Text('FROM YOUR DATA',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: AppColors.textSecondary(isDark))),
              const SizedBox(height: 12),
            ],

            // --- Deterministic local insights ---
            for (final i in _localInsights)
              _insightCard(isDark,
                  icon: i.icon, title: i.title, body: i.body, tone: i.tone.name, ai: false),
          ],
        ),
      ),
    );
  }

  Widget _weeklyChart(bool isDark) {
    final now = DateTime.now();
    final expenses = _transactions!
        .where((t) => t.type == TransactionType.expense)
        .toList();
    // 4 weekly buckets: [4w ago, 3w ago, 2w ago, this week]
    final weeks = <double>[0, 0, 0, 0];
    for (final t in expenses) {
      final weeksAgo = now.difference(t.date).inDays ~/ 7;
      if (weeksAgo >= 0 && weeksAgo < 4) weeks[3 - weeksAgo] += t.amount;
    }
    final cur = _settings?.currencySymbol ?? '₹';
    final maxVal = weeks.reduce((a, b) => a > b ? a : b);
    if (maxVal <= 0) return const SizedBox.shrink();

    final labels = ['4w ago', '3w ago', '2w ago', 'this wk'];

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 14),
      decoration: BoxDecoration(
        color: AppColors.card(isDark),
        borderRadius: BorderRadius.circular(20),
        border: isDark ? Border.all(color: AppColors.darkDivider) : null,
        boxShadow: isDark
            ? null
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('WEEKLY SPENDING',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: AppColors.textSecondary(isDark))),
          const SizedBox(height: 18),
          SizedBox(
            height: 130,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxVal * 1.25,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                        BarTooltipItem(
                          '$cur${rod.toY.toStringAsFixed(0)}',
                          const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700),
                        ),
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      getTitlesWidget: (value, meta) => Text(
                        labels[value.toInt()],
                        style: TextStyle(
                            fontSize: 10.5,
                            color: AppColors.textSecondary(isDark)),
                      ),
                    ),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: [
                  for (var i = 0; i < 4; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: weeks[i],
                          width: 26,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: i == 3
                                ? [AppColors.primaryGreen, AppColors.primaryGreen.withValues(alpha: 0.55)]
                                : [AppColors.accentBlue.withValues(alpha: 0.45), AppColors.accentBlue.withValues(alpha: 0.2)],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _insightCard(bool isDark,
      {required String icon, required String title, required String body, required String tone, required bool ai}) {
    final good = tone == 'good';
    final warning = tone == 'warning';
    final accent = good
        ? AppColors.primaryGreen
        : warning
            ? AppColors.accentRed
            : AppColors.accentBlue;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card(isDark),
        borderRadius: BorderRadius.circular(20),
        border: isDark ? Border.all(color: AppColors.darkDivider) : null,
        boxShadow: isDark
            ? null
            : [BoxShadow(
                color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tone dot instead of left bar
          Container(
            margin: const EdgeInsets.only(top: 3),
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text('$icon  $title',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary(isDark))),
                    ),
                    if (ai) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen.withValues(alpha: isDark ? 0.15 : 1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('AI',
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                color: AppColors.primaryGreen)),
                      ),
                    ],
                  ],
                ),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(body,
                      style: TextStyle(
                          fontSize: 13.5,
                          height: 1.45,
                          color: AppColors.textSecondary(isDark))),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
