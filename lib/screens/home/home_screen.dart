import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../calculations/safe_to_spend_engine.dart';
import '../../models/user_settings_model.dart';
import '../../models/transaction_model.dart';
import '../../services/app_store.dart';
import '../home/add_transaction_sheet.dart';
import '../assistant/assistant_screen.dart';
import '../../services/budget_guard.dart';

/// Home screen matching the APK's dashboard:
/// time-of-day greeting + date, SAFE TO SPEND hero card with "How this is
/// calculated", earned/spent/kept today stats, and the transaction list.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  UserSettings? _settings;
  List<TransactionModel> _transactions = [];
  double _safeToSpend = 0;
  bool _hasObligations = false;
  bool _upcomingExceedsBalance = false;
  BudgetAlert? _budgetAlert;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final store = AppStore();
    final settings = await store.getSettings();
    final txs = await store.getTransactions();
    final payments = await store.getRecurringPayments();

    final safeToSpend = SafeToSpendEngine.calculateSafeToSpend(
      currentBalance: settings.currentBalance,
      recurringPayments: payments,
    );
    final upcoming = payments.where((p) => p.isActive).fold<double>(0, (a, p) => a + p.amount);

    // Sage's budget guard: worst active alert for the dashboard banner.
    final budgets = await store.getBudgets();
    BudgetAlert? alert;
    if (budgets.isNotEmpty) {
      alert = BudgetGuard(budgets: budgets, transactions: txs).worstAlert();
    }

    setState(() {
      _settings = settings;
      _transactions = txs;
      _safeToSpend = safeToSpend;
      _hasObligations = upcoming > 0;
      _upcomingExceedsBalance = _hasObligations && safeToSpend < 0;
      _budgetAlert = alert;
    });
  }

  Future<void> _refresh() async {
    await _loadData();
  }

  void _openAddSheet(bool isIncome) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddTransactionSheet(isIncome: isIncome, onSaved: _refresh),
    );
  }

  void _openSage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AssistantScreen()),
    );
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'GOOD MORNING';
    if (h < 17) return 'GOOD AFTERNOON';
    return 'GOOD EVENING';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cur = _settings?.currencySymbol ?? '₹';
    final now = DateTime.now();

    final today = _transactions.where((t) =>
        t.date.year == now.year && t.date.month == now.month && t.date.day == now.day);
    final earnedToday = today
        .where((t) => t.type == TransactionType.income)
        .fold<double>(0, (a, t) => a + t.amount);
    final spentToday = today
        .where((t) => t.type == TransactionType.expense)
        .fold<double>(0, (a, t) => a + t.amount);
    final keptToday = earnedToday - spentToday;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 140),
          children: [
            // Greeting + date
            Text(_greeting,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: AppColors.primaryGreen)),
            const SizedBox(height: 4),
            Text(
              DateFormat('EEEE, MMMM d, y').format(now),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),

            // SAGE BUDGET ALERT BANNER
            if (_budgetAlert != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: (_budgetAlert!.isOver ? AppColors.accentRed : const Color(0xFFB25E00))
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: (_budgetAlert!.isOver ? AppColors.accentRed : const Color(0xFFB25E00))
                        .withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 20,
                        color: _budgetAlert!.isOver
                            ? AppColors.accentRed
                            : const Color(0xFFB25E00)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _budgetAlert!.warningText(cur),
                        style: const TextStyle(fontSize: 13, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

            // SAFE TO SPEND hero
            _heroCard(isDark, cur),

            const SizedBox(height: 12),

            // Earned / Spent / Kept today
            Row(
              children: [
                _statChip(isDark, 'Earned', earnedToday, Icons.south_west_rounded,
                    AppColors.primaryGreen),
                const SizedBox(width: 10),
                _statChip(isDark, 'Spent', spentToday, Icons.north_east_rounded,
                    AppColors.accentRed),
                const SizedBox(width: 10),
                _statChip(isDark, 'Kept', keptToday, Icons.savings_outlined,
                    AppColors.accentBlue),
              ],
            ),

            const SizedBox(height: 14),

            // SAGE — prominent one-tap access, in-flow (no overlap on phones)
            InkWell(
              onTap: _openSage,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF006C4C), Color(0xFF00A87A)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryGreen.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Ask Sage',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800)),
                          Text('Log, budget, or ask anything — plain English',
                              style: TextStyle(color: Colors.white70, fontSize: 11)),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 14),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 28),

            // Transactions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Where it went',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                Text('Today', style: TextStyle(fontSize: 13, color: AppColors.textSecondary(isDark))),
              ],
            ),
            const SizedBox(height: 12),
            if (_transactions.isEmpty)
              _emptyTx(isDark)
            else
              for (final t in _transactions.take(12)) _txTile(isDark, t, cur),

            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _openAddSheet(false),
                    icon: const Icon(Icons.remove, size: 18),
                    label: const Text('Add expense'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openAddSheet(true),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add income'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroCard(bool isDark, String cur) {
    final hasBalance = (_settings?.currentBalance ?? 0) != 0 || _transactions.isNotEmpty;
    Color heroColor;
    String heroLine;
    if (!hasBalance) {
      heroColor = AppColors.textSecondary(isDark);
      heroLine = 'Add your balance to see what is safe to spend.';
    } else if (_upcomingExceedsBalance) {
      heroColor = AppColors.accentRed;
      heroLine = 'Every rupee is already spoken for. Nothing is safe to spend today.';
    } else if (_hasObligations && _safeToSpend < (_settings?.currentBalance ?? 0) * 0.25) {
      heroColor = const Color(0xFFB25E00);
      heroLine = 'Things are tight after your upcoming payments. Spend carefully.';
    } else {
      heroColor = AppColors.primaryGreen;
      heroLine = 'That is what remains after everything you have already committed to.';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('SAFE TO SPEND',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: AppColors.primaryGreen)),
              const Spacer(),
              InkWell(
                onTap: () => _showHowCalculated(),
                child: Row(
                  children: [
                    Icon(Icons.help_outline_rounded,
                        size: 15, color: AppColors.textSecondary(isDark)),
                    const SizedBox(width: 4),
                    Text('How this is calculated',
                        style: TextStyle(
                            fontSize: 11.5, color: AppColors.textSecondary(isDark))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '$cur${_safeToSpend.toStringAsFixed(0)}',
            style: Theme.of(context).textTheme.displayMedium,
          ),
          const SizedBox(height: 8),
          Text(
            heroLine,
            style: TextStyle(fontSize: 13, color: heroColor, height: 1.35),
          ),
        ],
      ),
    );
  }

  void _showHowCalculated() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('How this is calculated'),
        content: const Text(
          'Safe to Spend is your balance minus everything you have already '
          'committed to in the next 30 days — recurring payments, rent, '
          'subscriptions. Your bank balance is not the whole story: rent is due, '
          'the phone bill is coming, Netflix renews on Thursday.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _statChip(bool isDark, String label, double amount, IconData icon, Color color) {
    final cur = _settings?.currencySymbol ?? '₹';
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.card(isDark),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
        ),
        child: Column(
          children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 11, color: AppColors.textSecondary(isDark))),
            const SizedBox(height: 2),
            Text('$cur${amount.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  Widget _emptyTx(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.card(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
      ),
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined, size: 36, color: AppColors.textSecondary(isDark)),
          const SizedBox(height: 10),
          Text('Nothing logged today',
              style: TextStyle(
                  fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary(isDark))),
          const SizedBox(height: 4),
          Text('Add your first income or expense from the home screen and it will show up here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary(isDark))),
        ],
      ),
    );
  }

  Widget _txTile(bool isDark, TransactionModel t, String cur) {
    final isIncome = t.type == TransactionType.income;
    final color = isIncome ? AppColors.primaryGreen : AppColors.accentRed;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.card(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.categoryColor(t.category).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isIncome ? Icons.south_west_rounded : Icons.north_east_rounded,
              size: 17,
              color: isIncome ? AppColors.primaryGreen : AppColors.categoryColor(t.category),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.note != null && t.note!.isNotEmpty ? t.note! : t.category,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
                Text(
                  t.category[0].toUpperCase() + t.category.substring(1),
                  style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary(isDark)),
                ),
              ],
            ),
          ),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${isIncome ? '+' : '-'}$cur${t.amount.toStringAsFixed(0)}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: color),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
