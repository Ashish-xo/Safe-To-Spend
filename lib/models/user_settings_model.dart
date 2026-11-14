class UserSettings {
  final double initialBalance;
  final double currentBalance;
  final String currencySymbol;
  final bool isBiometricEnabled;
  final DateTime updatedAt;

  UserSettings({
    required this.initialBalance,
    required this.currentBalance,
    this.currencySymbol = '₹',
    this.isBiometricEnabled = false,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': 1,
      'initial_balance': initialBalance,
      'current_balance': currentBalance,
      'currency_symbol': currencySymbol,
      'is_biometric_enabled': isBiometricEnabled ? 1 : 0,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory UserSettings.fromMap(Map<String, dynamic> map) {
    return UserSettings(
      initialBalance: (map['initial_balance'] as num).toDouble(),
      currentBalance: (map['current_balance'] as num).toDouble(),
      currencySymbol: map['currency_symbol'] ?? '₹',
      isBiometricEnabled: (map['is_biometric_enabled'] as int) == 1,
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  UserSettings copyWith({
    double? initialBalance,
    double? currentBalance,
    String? currencySymbol,
    bool? isBiometricEnabled,
    DateTime? updatedAt,
  }) {
    return UserSettings(
      initialBalance: initialBalance ?? this.initialBalance,
      currentBalance: currentBalance ?? this.currentBalance,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      isBiometricEnabled: isBiometricEnabled ?? this.isBiometricEnabled,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
