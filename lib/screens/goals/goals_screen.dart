import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/budget_goal_models.dart';
import '../../models/user_settings_model.dart';
import '../../services/app_store.dart';
import '../../theme/app_theme.dart';

/// Savings goals screen — matches the APK's Goals tab:
/// "Put money aside on purpose, and watch it add up.", "Create a goal",
/// "Add money", "ON TRACK".
class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  List<SavingsGoalModel> _goals = [];
  UserSettings? _settings;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final store = AppStore();
    final s = await store.getSettings();
    final g = await store.getSavingsGoals();
    setState(() {
      _settings = s;
      _goals = g;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cur = _settings?.currencySymbol ?? '₹';

    return Scaffold(
      appBar: AppBar(title: const Text('Goals')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openNewGoalSheet(),
        icon: const Icon(Icons.add),
        label: const Text('Create a goal'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
        children: [
          if (_goals.isEmpty) ...[
            const SizedBox(height: 48),
            Icon(Icons.flag_outlined, size: 56, color: AppColors.textSecondary(isDark)),
            const SizedBox(height: 12),
            const Text('Put money aside on purpose,',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const Text('and watch it add up.',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              'A phone, a trip, an emergency fund — give it a target and chip away.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary(isDark)),
            ),
          ] else
            for (final g in _goals) _goalCard(isDark, g, cur),
        ],
      ),
    );
  }

  Widget _goalCard(bool isDark, SavingsGoalModel g, String cur) {
    final pct = g.progress;
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
              Expanded(
                child: Text(g.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('ON TRACK',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: AppColors.primaryGreen)),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline,
                    size: 20, color: AppColors.textSecondary(isDark)),
                onPressed: () async {
                  await AppStore().deleteSavingsGoal(g.id);
                  _load();
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.12),
              valueColor: const AlwaysStoppedAnimation(AppColors.primaryGreen),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$cur${g.savedAmount.toStringAsFixed(0)} of $cur${g.targetAmount.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
              Text('${(pct * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                      fontSize: 12.5, color: AppColors.primaryGreen, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add money'),
                  onPressed: () => _openAddMoneySheet(g),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openNewGoalSheet() async {
    final nameCtrl = TextEditingController();
    final targetCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Create a goal',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('What are you saving for?',
                    style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary(Theme.of(ctx).brightness == Brightness.dark))),
                const SizedBox(height: 18),
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Give this goal a name'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: targetCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Target amount', prefixText: '₹ '),
                  validator: (v) =>
                      double.tryParse(v ?? '') == null || (double.tryParse(v ?? '0') ?? 0) <= 0
                          ? 'Target must be more than zero'
                          : null,
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      if (!(formKey.currentState?.validate() ?? false)) return;
                      await AppStore().addSavingsGoal(SavingsGoalModel(
                        id: const Uuid().v4(),
                        name: nameCtrl.text.trim(),
                        targetAmount: double.parse(targetCtrl.text),
                        createdAt: DateTime.now(),
                      ));
                      if (ctx.mounted) Navigator.pop(ctx);
                      _load();
                    },
                    child: const Text('Create goal'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openAddMoneySheet(SavingsGoalModel g) async {
    final amountCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add money to "${g.name}"',
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              TextField(
                controller: amountCtrl,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹ '),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final amount = double.tryParse(amountCtrl.text) ?? 0;
                    if (amount <= 0) return;
                    await AppStore().updateSavingsGoal(SavingsGoalModel(
                      id: g.id,
                      name: g.name,
                      targetAmount: g.targetAmount,
                      savedAmount: g.savedAmount + amount,
                      createdAt: g.createdAt,
                    ));
                    if (ctx.mounted) Navigator.pop(ctx);
                    _load();
                  },
                  child: const Text('Add to goal'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
