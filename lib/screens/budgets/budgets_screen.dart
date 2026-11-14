import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/budget_goal_models.dart';
import '../../models/transaction_model.dart';
import '../../models/user_settings_model.dart';
import '../../services/app_store.dart';
import '../../theme/app_theme.dart';

/// Budgets screen — matches the APK's Budgets tab:
/// "Create a budget", "Monthly limits per category, with alerts before
/// you overshoot.", "Approaching your budget on X", "Over budget on X".
class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  List<BudgetModel> _budgets = [];
  Map<String, double> _spentByCategory = {};
  UserSettings? _settings;

  static const _categories = [
    'food', 'transport', 'groceries', 'entertainment',
    'shopping', 'health', 'education', 'rent', 'utilities', 'other',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final store = AppStore();
    final s = await store.getSettings();
    final budgets = await store.getBudgets();
    final txs = await store.getTransactions();
    final now = DateTime.now();
    final spent = <String, double>{};
    for (final t in txs) {
      if (t.type == TransactionType.expense &&
          t.date.year == now.year && t.date.month == now.month) {
        spent[t.category] = (spent[t.category] ?? 0) + t.amount;
      }
    }
    setState(() {
      _settings = s;
      _budgets = budgets;
      _spentByCategory = spent;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cur = _settings?.currencySymbol ?? '₹';

    return Scaffold(
      appBar: AppBar(title: const Text('Budgets')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openSheet(),
        icon: const Icon(Icons.add),
        label: const Text('New budget'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
        children: [
          if (_budgets.isEmpty) ...[
            const SizedBox(height: 48),
            Icon(Icons.savings_outlined, size: 56, color: AppColors.textSecondary(isDark)),
            const SizedBox(height: 12),
            const Text('Nothing here yet',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              'Set a monthly limit for a category and the app will warn you before you blow through it.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary(isDark)),
            ),
          ] else
            for (final b in _budgets) _budgetCard(isDark, b, cur),
        ],
      ),
    );
  }

  Widget _budgetCard(bool isDark, BudgetModel b, String cur) {
    final spent = _spentByCategory[b.category] ?? 0;
    final pct = b.limitAmount > 0 ? (spent / b.limitAmount).clamp(0.0, 1.5) : 0.0;
    final over = spent > b.limitAmount;
    final approaching = !over && pct >= b.warnAtPct / 100;
    final color = over
        ? AppColors.accentRed
        : approaching
            ? const Color(0xFFB25E00)
            : AppColors.primaryGreen;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.categoryColor(b.category).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.circle_outlined,
                    size: 18, color: AppColors.categoryColor(b.category)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(b.category[0].toUpperCase() + b.category.substring(1),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline,
                    size: 20, color: AppColors.textSecondary(isDark)),
                onPressed: () async {
                  await AppStore().deleteBudget(b.id);
                  _load();
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text('$cur${spent.toStringAsFixed(0)} of $cur${b.limitAmount.toStringAsFixed(0)}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
              ),
              Flexible(
                child: Text(
                  over
                      ? 'Over budget by $cur${(spent - b.limitAmount).toStringAsFixed(0)}'
                      : '$cur${(b.limitAmount - spent).toStringAsFixed(0)} left',
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 12.5, color: color, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (over)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Over budget on ${b.category}',
                  style: const TextStyle(fontSize: 12, color: AppColors.accentRed)),
            )
          else if (approaching)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Approaching your budget on ${b.category}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFFB25E00))),
            ),
        ],
      ),
    );
  }

  Future<void> _openSheet() async {
    String category = _categories.first;
    final amountCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (ctx, setSheet) => Padding(
            padding: const EdgeInsets.all(22),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Create a budget',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(
                    'Monthly limits per category, with alerts before you overshoot.',
                    style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary(Theme.of(ctx).brightness == Brightness.dark)),
                  ),
                  const SizedBox(height: 18),
                  const Text('Pick a category',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final c in _categories)
                        ChoiceChip(
                          label: Text(c),
                          selected: category == c,
                          onSelected: (_) => setSheet(() => category = c),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Enter a limit', prefixText: '₹ '),
                    validator: (v) =>
                        double.tryParse(v ?? '') == null || (double.tryParse(v ?? '0') ?? 0) <= 0
                            ? 'Limit must be more than zero'
                            : null,
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        if (!(formKey.currentState?.validate() ?? false)) return;
                        await AppStore().addBudget(BudgetModel(
                          id: const Uuid().v4(),
                          category: category,
                          limitAmount: double.parse(amountCtrl.text),
                          createdAt: DateTime.now(),
                        ));
                        if (ctx.mounted) Navigator.pop(ctx);
                        _load();
                      },
                      child: const Text('Add budget'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
