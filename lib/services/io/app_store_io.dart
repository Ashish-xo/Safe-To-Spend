import 'dart:io';
import '../../database/app_database.dart';
import '../../models/user_settings_model.dart';
import '../../models/transaction_model.dart';
import '../../models/recurring_payment_model.dart';

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

  Future<void> clearAll() async {
    final database = await db.database;
    await database.delete('transactions');
    await database.delete('recurring_payments');
  }
}
