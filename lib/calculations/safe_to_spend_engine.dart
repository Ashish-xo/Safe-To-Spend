import '../models/recurring_payment_model.dart';
import '../models/transaction_model.dart';

class SafeToSpendEngine {
  /// Calculates the Safe to Spend amount:
  /// Safe to Spend = Current Available Balance - Upcoming Obligations (within next 30 days or billing cycle)
  static double calculateSafeToSpend({
    required double currentBalance,
    required List<RecurringPaymentModel> recurringPayments,
    DateTime? now,
    int daysAhead = 30,
  }) {
    final referenceDate = now ?? DateTime.now();
    final cutoffDate = referenceDate.add(Duration(days: daysAhead));

    double totalUpcomingObligations = 0.0;

    for (final payment in recurringPayments) {
      if (!payment.isActive) continue;

      DateTime nextDate = payment.nextPaymentDate;

      // Add all instances of this recurring payment that fall between referenceDate and cutoffDate
      while (nextDate.isBefore(cutoffDate) || _isSameDay(nextDate, cutoffDate)) {
        if (payment.endDate != null && nextDate.isAfter(payment.endDate!)) {
          break;
        }

        if (!nextDate.isBefore(referenceDate) || _isSameDay(nextDate, referenceDate)) {
          totalUpcomingObligations += payment.amount;
        }

        nextDate = _getNextPaymentDate(nextDate, payment.frequency);
      }
    }

    return currentBalance - totalUpcomingObligations;
  }

  /// Calculates total earned today
  static double calculateEarnedToday(List<TransactionModel> transactions, {DateTime? date}) {
    final targetDate = date ?? DateTime.now();
    return transactions
        .where((t) => t.type == TransactionType.income && _isSameDay(t.date, targetDate))
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  /// Calculates total spent today
  static double calculateSpentToday(List<TransactionModel> transactions, {DateTime? date}) {
    final targetDate = date ?? DateTime.now();
    return transactions
        .where((t) => t.type == TransactionType.expense && _isSameDay(t.date, targetDate))
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  /// Calculates Kept Today: Earned Today - Spent Today
  static double calculateKeptToday(List<TransactionModel> transactions, {DateTime? date}) {
    return calculateEarnedToday(transactions, date: date) - calculateSpentToday(transactions, date: date);
  }

  static bool _isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  static DateTime _getNextPaymentDate(DateTime current, RecurrenceFrequency frequency) {
    switch (frequency) {
      case RecurrenceFrequency.daily:
        return current.add(const Duration(days: 1));
      case RecurrenceFrequency.weekly:
        return current.add(const Duration(days: 7));
      case RecurrenceFrequency.monthly:
        return DateTime(current.year, current.month + 1, current.day);
      case RecurrenceFrequency.yearly:
        return DateTime(current.year + 1, current.month, current.day);
    }
  }
}
