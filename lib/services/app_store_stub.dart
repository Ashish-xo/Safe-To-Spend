import '../models/user_settings_model.dart';
import '../models/transaction_model.dart';
import '../models/recurring_payment_model.dart';

/// Fallback implementation — replaced at compile time by io/web variants.
class AppStore {
  Future<void> init() async => throw UnsupportedError('No platform storage');
  Future<UserSettings> getSettings() async => throw UnsupportedError('');
  Future<void> updateSettings(UserSettings s) async => throw UnsupportedError('');
  Future<List<TransactionModel>> getTransactions() async => throw UnsupportedError('');
  Future<void> addTransaction(TransactionModel t) async => throw UnsupportedError('');
  Future<void> deleteTransaction(String id) async => throw UnsupportedError('');
  Future<List<RecurringPaymentModel>> getRecurringPayments() async => throw UnsupportedError('');
  Future<void> addRecurringPayment(RecurringPaymentModel p) async => throw UnsupportedError('');
  Future<void> clearAll() async => throw UnsupportedError('');
}
