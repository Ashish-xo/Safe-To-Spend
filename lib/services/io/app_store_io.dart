import '../../database/app_database.dart';
import '../../models/user_settings_model.dart';
import '../../models/transaction_model.dart';
import '../../models/recurring_payment_model.dart';
import '../../models/budget_goal_models.dart';

/// IO (Android/desktop) storage using the original sqflite AppDatabase.
class AppStore {
  final db = AppDatabase.instance;

  Future<void> init() async {}

  Future<UserSettings> getSettings() => db.getUserSettings();

  Future<void> updateSettings(UserSettings s) => db.updateUserSettings(s);

  Future<List<TransactionModel>> getTransactions() => db.getTransactions();

  Future<void> addTransaction(TransactionModel t) => db.insertTransaction(t);

  Future<void> deleteTransaction(String id) async {
    final database = await db.database;
    await database.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<RecurringPaymentModel>> getRecurringPayments() => db.getRecurringPayments();

  Future<void> addRecurringPayment(RecurringPaymentModel p) => db.insertRecurringPayment(p);

  // ---- Budgets ----
  Future<List<BudgetModel>> getBudgets() async {
    final database = await db.database;
    final rows = await database.query('budgets');
    return rows.map((m) => BudgetModel.fromMap({
          'id': m['id'],
          'category': m['category'],
          'limit_amount': m['monthly_limit'],
          'warn_at_pct': 80,
          'created_at': DateTime.now().toIso8601String(),
        })).toList();
  }

  Future<void> addBudget(BudgetModel b) async {
    final database = await db.database;
    await database.insert('budgets', {
      'id': b.id,
      'category': b.category,
      'monthly_limit': b.limitAmount,
    });
  }

  Future<void> deleteBudget(String id) async {
    final database = await db.database;
    await database.delete('budgets', where: 'id = ?', whereArgs: [id]);
  }

  // ---- Savings goals ----
  Future<List<SavingsGoalModel>> getSavingsGoals() async {
    final database = await db.database;
    final rows = await database.query('savings_goals');
    return rows.map((m) => SavingsGoalModel.fromMap({
          'id': m['id'],
          'name': m['name'],
          'target_amount': m['target_amount'],
          'saved_amount': m['saved_amount'],
          'created_at': DateTime.now().toIso8601String(),
        })).toList();
  }

  Future<void> addSavingsGoal(SavingsGoalModel g) async {
    final database = await db.database;
    await database.insert('savings_goals', {
      'id': g.id,
      'name': g.name,
      'target_amount': g.targetAmount,
      'saved_amount': g.savedAmount,
    });
  }

  Future<void> updateSavingsGoal(SavingsGoalModel g) async {
    final database = await db.database;
    await database.update('savings_goals', {
      'name': g.name,
      'target_amount': g.targetAmount,
      'saved_amount': g.savedAmount,
    }, where: 'id = ?', whereArgs: [g.id]);
  }

  Future<void> deleteSavingsGoal(String id) async {
    final database = await db.database;
    await database.delete('savings_goals', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearAll() async {
    final database = await db.database;
    await database.delete('transactions');
    await database.delete('recurring_payments');
    await database.delete('budgets');
    await database.delete('savings_goals');
  }
}
