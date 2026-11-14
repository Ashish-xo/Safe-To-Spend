import 'dart:io' show Platform;
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_to_spend/main.dart';
import 'package:safe_to_spend/models/transaction_model.dart';
import 'package:safe_to_spend/models/recurring_payment_model.dart';
import 'package:safe_to_spend/models/user_settings_model.dart';
import 'package:safe_to_spend/calculations/safe_to_spend_engine.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  // Desktop test env has no Android sqflite — use the FFI implementation.
  setUpAll(() {
    if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  });
  testWidgets('App boots to the 5-tab shell', (tester) async {
    await tester.pumpWidget(const SafeToSpendApp());
    await tester.pumpAndSettle();
    for (final label in ['Home', 'Payments', 'Budgets', 'Goals', 'More']) {
      expect(find.text(label), findsWidgets);
    }
  });

  test('SafeToSpend subtracts upcoming obligations within 30 days', () {
    final now = DateTime(2026, 11, 14);
    final recurring = [
      RecurringPaymentModel(
        id: 'r1',
        name: 'Netflix',
        amount: 199,
        category: 'entertainment',
        frequency: RecurrenceFrequency.monthly,
        nextPaymentDate: DateTime(2026, 11, 20),
      ),
      RecurringPaymentModel(
        id: 'r2',
        name: 'Far future bill (outside window)',
        amount: 5000,
        category: 'other',
        frequency: RecurrenceFrequency.yearly,
        nextPaymentDate: DateTime(2027, 6, 1),
      ),
    ];
    final safe = SafeToSpendEngine.calculateSafeToSpend(
      currentBalance: 5000,
      recurringPayments: recurring,
      now: now,
    );
    // Only the Netflix bill falls inside the 30-day window.
    expect(safe, 5000 - 199);
  });

  test('SafeToSpend skips inactive recurring payments', () {
    final now = DateTime(2026, 11, 14);
    final recurring = [
      RecurringPaymentModel(
        id: 'r1',
        name: 'Old subscription',
        amount: 299,
        category: 'entertainment',
        frequency: RecurrenceFrequency.monthly,
        nextPaymentDate: DateTime(2026, 11, 20),
        isActive: false,
      ),
    ];
    final safe = SafeToSpendEngine.calculateSafeToSpend(
      currentBalance: 2000,
      recurringPayments: recurring,
      now: now,
    );
    expect(safe, 2000);
  });

  test('Spent/earned/kept today are computed per day', () {
    final txs = [
      _tx(100, TransactionType.income, DateTime(2026, 11, 14)),
      _tx(30, TransactionType.expense, DateTime(2026, 11, 14)),
      _tx(70, TransactionType.expense, DateTime(2026, 11, 13)),
    ];
    final day = DateTime(2026, 11, 14);
    expect(SafeToSpendEngine.calculateEarnedToday(txs, date: day), 100);
    expect(SafeToSpendEngine.calculateSpentToday(txs, date: day), 30);
    expect(SafeToSpendEngine.calculateKeptToday(txs, date: day), 70);
  });

  test('Transaction model JSON round-trips', () {
    final t = TransactionModel(
      id: 't1',
      amount: 249.5,
      type: TransactionType.expense,
      category: 'food',
      date: DateTime(2026, 11, 14, 10, 30),
      note: 'dosa',
      createdAt: DateTime(2026, 11, 14, 10, 30),
    );
    final copy = TransactionModel.fromMap(t.toMap());
    expect(copy.id, 't1');
    expect(copy.amount, 249.5);
    expect(copy.type, TransactionType.expense);
    expect(copy.category, 'food');
    expect(copy.note, 'dosa');
  });

  test('UserSettings copyWith preserves untouched fields', () {
    final s = UserSettings(
      initialBalance: 3000,
      currentBalance: 2500,
      currencySymbol: '₹',
      updatedAt: DateTime(2026, 11, 14),
    );
    final s2 = s.copyWith(currentBalance: 2000);
    expect(s2.initialBalance, 3000);
    expect(s2.currentBalance, 2000);
    expect(s2.currencySymbol, '₹');
  });
}

TransactionModel _tx(double amount, TransactionType type, DateTime date) {
  return TransactionModel(
    id: '${date.millisecondsSinceEpoch}-$amount',
    amount: amount,
    type: type,
    category: 'other',
    date: date,
    createdAt: date,
  );
}
