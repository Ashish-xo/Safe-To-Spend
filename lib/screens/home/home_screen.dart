import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../calculations/safe_to_spend_engine.dart';
import '../../models/user_settings_model.dart';
import '../../models/transaction_model.dart';
import '../../models/recurring_payment_model.dart';
import '../../services/app_store.dart';
import 'add_transaction_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  UserSettings? _settings;
  List<TransactionModel> _transactions = [];
  List<RecurringPaymentModel> _recurringPayments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final store = AppStore();
    await store.init();
    final settings = await store.getSettings();
    final transactions = await store.getTransactions();
    final recurring = await store.getRecurringPayments();

    setState(() {
      _settings = settings;
      _transactions = transactions;
      _recurringPayments = recurring;
      _isLoading = false;
    });
  }

  Future<void> _openAddSheet(bool isIncome) async {
    await AddTransactionSheet.show(context, isIncome: isIncome, onSaved: _loadData);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final hour = now.hour;
    final greeting = hour < 12 ? 'Good morning' : (hour < 17 ? 'Good afternoon' : 'Good evening');

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final safeToSpend = SafeToSpendEngine.calculateSafeToSpend(
      currentBalance: _settings?.currentBalance ?? 0.0,
      recurringPayments: _recurringPayments,
    );

    final earnedToday = SafeToSpendEngine.calculateEarnedToday(_transactions);
    final spentToday = SafeToSpendEngine.calculateSpentToday(_transactions);
    final keptToday = SafeToSpendEngine.calculateKeptToday(_transactions);

    final currency = _settings?.currencySymbol ?? '₹';
    final recent = _transactions.take(8).toList();

    return Scaffold(
      body: RefreshIndicator(
        color: AppColors.primaryGreen,
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
          children: [
            // Greeting
            Text(greeting,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                    color: AppColors.textSecondary(isDark))),
            const SizedBox(height: 2),
            Text(DateFormat('EEEE, d MMMM').format(now),
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary(isDark))),

            const SizedBox(height: 24),

            // HERO CARD — Safe to Spend
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF00C896), Color(0xFF08916A)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryGreen.withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('SAFE TO SPEND',
                            style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                                color: Colors.white)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '$currency${_fmt(safeToSpend)}',
                    style: const TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.5,
                        height: 1,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _settings?.currentBalance == null || _settings!.currentBalance == 0
                        ? 'after upcoming obligations'
                        : 'balance ${currency}${_fmt(_settings!.currentBalance)} − upcoming bills',
                    style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.white.withValues(alpha: 0.85))),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // TODAY — three stat chips
            Row(
              children: [
                _statChip(context, 'Earned', '+$currency${_fmt(earnedToday)}',
                    AppColors.primaryGreen, Icons.arrow_downward),
                const SizedBox(width: 12),
                _statChip(context, 'Spent', '-$currency${_fmt(spentToday)}',
                    AppColors.accentRed, Icons.arrow_upward),
                const SizedBox(width: 12),
                _statChip(context, 'Kept', '$currency${_fmt(keptToday)}',
                    AppColors.accentBlue, Icons.savings_outlined),
              ],
            ),

            const SizedBox(height: 28),

            // ACTION BUTTONS
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _openAddSheet(true),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Income'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _openAddSheet(false),
                    style: FilledButton.styleFrom(
                      backgroundColor: isDark
                          ? AppColors.darkCardElevated
                          : Colors.white,
                      foregroundColor: AppColors.accentRed,
                      side: isDark
                          ? null
                          : const BorderSide(color: AppColors.accentRed, width: 1.2),
                    ),
                    icon: const Icon(Icons.remove, size: 18),
                    label: const Text('Expense'),
                  ),
                ),
              ],
            ),

            // RECENT TRANSACTIONS
            if (recent.isNotEmpty) ...[
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('RECENT',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                          color: AppColors.textSecondary(isDark))),
                ],
              ),
              const SizedBox(height: 12),
              ...recent.map((t) => _transactionTile(context, t, currency)),
            ],
          ],
        ),
      ),
    );
  }

  String _fmt(double v) {
    if (v == v.roundToDouble() && v.abs() < 100000) return v.round().toString();
    return v.toStringAsFixed(v.abs() < 100 ? 2 : 0);
  }

  Widget _statChip(BuildContext context, String label, String value, Color color, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.card(isDark),
          borderRadius: BorderRadius.circular(18),
          border: isDark ? Border.all(color: AppColors.darkDivider) : null,
          boxShadow: isDark
              ? null
              : [BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary(isDark))),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary(isDark))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _transactionTile(BuildContext context, TransactionModel t, String currency) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isIncome = t.type == TransactionType.income;
    final (icon, color) = _categoryVisual(t.category);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card(isDark),
        borderRadius: BorderRadius.circular(18),
        border: isDark ? Border.all(color: AppColors.darkDivider) : null,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.16 : 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, size: 19, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.note?.isNotEmpty == true ? t.note! : t.category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary(isDark))),
                const SizedBox(height: 2),
                Text(
                    '${t.category} • ${t.date.day}/${t.date.month}',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary(isDark))),
              ],
            ),
          ),
          Text(
            '${isIncome ? '+' : '-'}$currency${_fmt(t.amount)}',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: isIncome ? AppColors.primaryGreen : AppColors.textPrimary(isDark)),
          ),
        ],
      ),
    );
  }

  (IconData, Color) _categoryVisual(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return (Icons.lunch_dining_outlined, AppColors.accentRed);
      case 'transport':
        return (Icons.directions_bus_outlined, AppColors.accentBlue);
      case 'groceries':
        return (Icons.shopping_basket_outlined, AppColors.primaryGreen);
      case 'entertainment':
        return (Icons.movie_outlined, AppColors.accentViolet);
      case 'shopping':
        return (Icons.shopping_bag_outlined, Colors.pinkAccent);
      case 'health':
        return (Icons.favorite_border, AppColors.accentRed);
      case 'education':
        return (Icons.school_outlined, AppColors.accentBlue);
      case 'rent':
        return (Icons.home_outlined, AppColors.accentViolet);
      case 'utilities':
        return (Icons.bolt_outlined, Colors.orangeAccent);
      case 'salary':
      case 'freelance':
        return (Icons.payments_outlined, AppColors.primaryGreen);
      default:
        return (Icons.category_outlined, AppColors.textSecondary(true));
    }
  }
}
