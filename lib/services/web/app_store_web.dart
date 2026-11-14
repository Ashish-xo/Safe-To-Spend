import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user_settings_model.dart';
import '../../models/transaction_model.dart';
import '../../models/recurring_payment_model.dart';
import '../../models/budget_goal_models.dart';

/// Web storage: same API as the IO store, backed by localStorage
/// (browsers have no SQLite). Data is stored as JSON.
class AppStore {
  static const _kTx = 'sts_transactions';
  static const _kRec = 'sts_recurring';
  static const _kSettings = 'sts_settings';
  static const _kBud = 'sts_budgets';
  static const _kGoal = 'sts_goals';

  Future<void> init() async => SharedPreferences.getInstance();

  Future<UserSettings> getSettings() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kSettings);
    if (raw != null) return UserSettings.fromMap(jsonDecode(raw));
    return UserSettings(
      initialBalance: 0,
      currentBalance: 0,
      currencySymbol: '₹',
      updatedAt: DateTime.now(),
    );
  }

  Future<void> updateSettings(UserSettings s) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kSettings, jsonEncode(s.toMap()));
  }

  Future<List<TransactionModel>> getTransactions() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList(_kTx) ?? [];
    return raw.map((e) => TransactionModel.fromMap(jsonDecode(e))).toList();
  }

  Future<void> addTransaction(TransactionModel t) async {
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList(_kTx) ?? [];
    list.add(jsonEncode(t.toMap()));
    await p.setStringList(_kTx, list);
    // Keep balance in sync, mirroring the original AppDatabase behaviour.
    final s = await getSettings();
    final newBalance = t.type == TransactionType.income
        ? s.currentBalance + t.amount
        : s.currentBalance - t.amount;
    await updateSettings(s.copyWith(currentBalance: newBalance, updatedAt: DateTime.now()));
  }

  Future<void> deleteTransaction(String id) async {
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList(_kTx) ?? [];
    await p.setStringList(_kTx, list.where((e) {
      final map = jsonDecode(e) as Map<String, dynamic>;
      return map['id'] != id;
    }).toList());
  }

  Future<List<RecurringPaymentModel>> getRecurringPayments() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList(_kRec) ?? [];
    return raw.map((e) => RecurringPaymentModel.fromMap(jsonDecode(e))).toList();
  }

  Future<void> addRecurringPayment(RecurringPaymentModel pay) async {
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList(_kRec) ?? [];
    list.add(jsonEncode(pay.toMap()));
    await p.setStringList(_kRec, list);
  }

  // ---- Budgets ----
  Future<List<BudgetModel>> getBudgets() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList(_kBud) ?? [];
    return raw.map((e) => BudgetModel.fromMap(jsonDecode(e))).toList();
  }

  Future<void> addBudget(BudgetModel b) async {
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList(_kBud) ?? [];
    // one budget per category — replace existing
    list.removeWhere((e) => BudgetModel.fromMap(jsonDecode(e)).category == b.category);
    list.add(jsonEncode(b.toMap()));
    await p.setStringList(_kBud, list);
  }

  Future<void> deleteBudget(String id) async {
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList(_kBud) ?? [];
    list.removeWhere((e) => BudgetModel.fromMap(jsonDecode(e)).id == id);
    await p.setStringList(_kBud, list);
  }

  // ---- Savings goals ----
  Future<List<SavingsGoalModel>> getSavingsGoals() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList(_kGoal) ?? [];
    return raw.map((e) => SavingsGoalModel.fromMap(jsonDecode(e))).toList();
  }

  Future<void> addSavingsGoal(SavingsGoalModel g) async {
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList(_kGoal) ?? [];
    list.add(jsonEncode(g.toMap()));
    await p.setStringList(_kGoal, list);
  }

  Future<void> updateSavingsGoal(SavingsGoalModel g) async {
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList(_kGoal) ?? [];
    final i = list.indexWhere((e) => SavingsGoalModel.fromMap(jsonDecode(e)).id == g.id);
    if (i >= 0) {
      list[i] = jsonEncode(g.toMap());
      await p.setStringList(_kGoal, list);
    }
  }

  Future<void> deleteSavingsGoal(String id) async {
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList(_kGoal) ?? [];
    list.removeWhere((e) => SavingsGoalModel.fromMap(jsonDecode(e)).id == id);
    await p.setStringList(_kGoal, list);
  }

  Future<void> clearAll() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kTx);
    await p.remove(_kRec);
    await p.remove(_kBud);
    await p.remove(_kGoal);
  }
}
