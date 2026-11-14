enum RecurrenceFrequency { daily, weekly, monthly, yearly }

class RecurringPaymentModel {
  final String id;
  final String name;
  final double amount;
  final String category;
  final RecurrenceFrequency frequency;
  final DateTime nextPaymentDate;
  final DateTime? endDate;
  final bool isActive;
  final String? note;

  RecurringPaymentModel({
    required this.id,
    required this.name,
    required this.amount,
    required this.category,
    required this.frequency,
    required this.nextPaymentDate,
    this.endDate,
    this.isActive = true,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'category': category,
      'frequency': frequency.name.toUpperCase(),
      'next_payment_date': nextPaymentDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'is_active': isActive ? 1 : 0,
      'note': note,
    };
  }

  factory RecurringPaymentModel.fromMap(Map<String, dynamic> map) {
    return RecurringPaymentModel(
      id: map['id'],
      name: map['name'],
      amount: (map['amount'] as num).toDouble(),
      category: map['category'],
      frequency: RecurrenceFrequency.values.firstWhere(
        (f) => f.name.toUpperCase() == map['frequency'],
        orElse: () => RecurrenceFrequency.monthly,
      ),
      nextPaymentDate: DateTime.parse(map['next_payment_date']),
      endDate: map['end_date'] != null ? DateTime.parse(map['end_date']) : null,
      isActive: (map['is_active'] as int) == 1,
      note: map['note'],
    );
  }
}
