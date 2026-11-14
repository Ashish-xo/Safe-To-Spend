import 'dart:convert';
import 'package:flutter/material.dart';
import '../../models/recurring_payment_model.dart';
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
  List<RecurringPaymentModel>? _recurring;
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
    final settings = await store.getSettings();
    final txs = await store.getTransactions();
    final rec = await store.getRecurringPayments();
    final engine = InsightsEngine(transactions: txs, recurring: rec, settings: settings);

    setState(() {
      _settings = settings;
      _transactions = txs;
      _recurring = rec;
      _localInsights = engine.generateLocalInsights();
      _aiInsights = [];
      _aiFailed = false;
    });

    // Then enrich with AI narrative (non-blocking).
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
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            Text('AI INSIGHTS', style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.2,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            )),
            const SizedBox(height: 4),
            const Text('Your money, explained', style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w700,
            )),
            const SizedBox(height: 16),

            // --- AI-generated insights ---
            if (_aiLoading)
              const Card(child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Sage is analysing your spending...', textAlign: TextAlign.center),
                ]),
              )),
            if (_aiFailed)
              Card(child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  const Text('⚡ '),
                  Expanded(
                    child: Text(
                      'AI phrasing is offline right now — showing locally-computed insights below '
                      '${_aiError == null ? "" : "($_aiError) "}(all numbers are still exact).',
                      style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                    ),
                  ),
                ]),
              )),
            for (final i in _aiInsights) _insightCard(i.icon, i.title, i.body, i.tone),

            if (_aiInsights.isNotEmpty || _aiFailed || !_aiLoading) ...[
              const SizedBox(height: 8),
              Text('FROM YOUR DATA', style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.2,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              )),
              const SizedBox(height: 8),
            ],

            // --- Deterministic local insights ---
            for (final i in _localInsights)
              _insightCard(i.icon, i.title, i.body, i.tone.name),
          ],
        ),
      ),
    );
  }

  Widget _insightCard(String icon, String title, String body, String tone) {
    final good = tone == 'good';
    final warning = tone == 'warning';
    Color? accent;
    if (good) accent = AppColors.primaryGreen;
    if (warning) accent = AppColors.accentRed;
    return Card(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: accent != null ? Border(left: BorderSide(color: accent, width: 4)) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$icon  $title', style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w700,
            )),
            if (body.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(body, style: TextStyle(fontSize: 13.5, color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
            ],
          ],
        ),
      ),
    );
  }
}
