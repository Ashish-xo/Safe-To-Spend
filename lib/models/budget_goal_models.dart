/// Monthly category budget — matches the APK's budget feature
/// ("Monthly limits per category, with alerts before you overshoot").
class BudgetModel {
  final String id;
  final String category;
  final double limitAmount;
  final double warnAtPct; // "Warn me at X%" — 0 = default 80%
  final DateTime createdAt;

  BudgetModel({
    required this.id,
    required this.category,
    required this.limitAmount,
    this.warnAtPct = 80,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'category': category,
        'limit_amount': limitAmount,
        'warn_at_pct': warnAtPct,
        'created_at': createdAt.toIso8601String(),
      };

  factory BudgetModel.fromMap(Map<String, dynamic> m) => BudgetModel(
        id: m['id'] as String,
        category: m['category'] as String,
        limitAmount: (m['limit_amount'] as num).toDouble(),
        warnAtPct: (m['warn_at_pct'] as num?)?.toDouble() ?? 80,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}

/// Savings goal — matches the APK's goals screen
/// ("Put money aside on purpose, and watch it add up.").
class SavingsGoalModel {
  final String id;
  final String name;
  final double targetAmount;
  final double savedAmount;
  final DateTime createdAt;

  SavingsGoalModel({
    required this.id,
    required this.name,
    required this.targetAmount,
    this.savedAmount = 0,
    required this.createdAt,
  });

  double get progress => targetAmount > 0 ? (savedAmount / targetAmount).clamp(0.0, 1.0) : 0;
  bool get onTrack => progress >= 0.0; // APK shows "ON TRACK" chip

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'target_amount': targetAmount,
        'saved_amount': savedAmount,
        'created_at': createdAt.toIso8601String(),
      };

  factory SavingsGoalModel.fromMap(Map<String, dynamic> m) => SavingsGoalModel(
        id: m['id'] as String,
        name: m['name'] as String,
        targetAmount: (m['target_amount'] as num).toDouble(),
        savedAmount: (m['saved_amount'] as num?)?.toDouble() ?? 0,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}
