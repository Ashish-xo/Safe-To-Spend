import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user_settings_model.dart';
import '../../models/transaction_model.dart';
import '../../models/recurring_payment_model.dart';

/// Web storage: same API as the IO store, backed by localStorage
/// (browsers have no SQLite). Data is stored as JSON.
class AppStore {
  static const _kTx = 'sts_transactions';
  static const _kRec = 'sts_recurring';
  static const _kSettings = 'sts_settings';

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

  Future<void> clearAll() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kTx);
    await p.remove(_kRec);
  }
}
