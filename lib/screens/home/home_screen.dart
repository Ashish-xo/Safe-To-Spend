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
    final todayStr = DateFormat('MMMM d').format(DateTime.now()).toUpperCase();

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final safeToSpend = SafeToSpendEngine.calculateSafeToSpend(
      currentBalance: _settings?.currentBalance ?? 0.0,
      recurringPayments: _recurringPayments,
    );

    final earnedToday = SafeToSpendEngine.calculateEarnedToday(_transactions);
    final spentToday = SafeToSpendEngine.calculateSpentToday(_transactions);
    final keptToday = SafeToSpendEngine.calculateKeptToday(_transactions);

    final currency = _settings?.currencySymbol ?? '₹';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'GOOD EVENING 👋',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                todayStr,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 24),

              // SAFE TO SPEND CARD
              Card(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: AppColors.primaryGreen,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'SAFE TO SPEND',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '$currency${safeToSpend.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 44,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // TODAY METRICS
              Text(
                'TODAY',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Column(
                    children: [
                      _buildMetricRow('💰 Earned', '$currency${earnedToday.toStringAsFixed(0)}', AppColors.primaryGreen),
                      const Divider(height: 16),
                      _buildMetricRow('💸 Spent', '$currency${spentToday.toStringAsFixed(0)}', AppColors.accentRed),
                      const Divider(height: 16),
                      _buildMetricRow('🟢 Kept', '$currency${keptToday.toStringAsFixed(0)}', AppColors.accentBlue),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // QUICK ACTION BUTTONS
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _openAddSheet(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        '+ Income',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _openAddSheet(false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        '+ Expense',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        Text(
          value,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: valueColor),
        ),
      ],
    );
  }
}
