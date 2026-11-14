import 'package:flutter/material.dart';

/// Colors matching the APK's design language (extracted from the
/// decompiled app: Material You dynamic color with a green seed).
class AppColors {
  // Brand seed — Material You green
  static const Color primaryGreen = Color(0xFF006C4C);
  static const Color primaryContainer = Color(0xFF89F8C7);
  static const Color onPrimaryContainer = Color(0xFF002015);

  static const Color accentRed = Color(0xFFBA1A1A);
  static const Color accentBlue = Color(0xFF00639B);
  static const Color accentBlueContainer = Color(0xFFCCE5FF);

  // Light scheme
  static const Color lightBackground = Color(0xFFF6FBF6);
  static const Color lightSurface = Color(0xFFF6FBF6);
  static const Color lightCardBackground = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF161D19);
  static const Color lightTextSecondary = Color(0xFF5A6560);
  static const Color lightDivider = Color(0xFFE2EAE4);

  // Dark scheme
  static const Color darkBackground = Color(0xFF101410);
  static const Color darkCardBackground = Color(0xFF1A201B);
  static const Color darkCardElevated = Color(0xFF232A24);
  static const Color darkTextPrimary = Color(0xFFE1E3DE);
  static const Color darkTextSecondary = Color(0xFFB2BCB4);
  static const Color darkDivider = Color(0xFF313934);

  // Semantic helpers
  static Color background(bool isDark) => isDark ? darkBackground : lightBackground;
  static Color card(bool isDark) => isDark ? darkCardBackground : lightCardBackground;
  static Color textPrimary(bool isDark) => isDark ? darkTextPrimary : lightTextPrimary;
  static Color textSecondary(bool isDark) => isDark ? darkTextSecondary : lightTextSecondary;

  /// Icon/background color for a category (used by transaction tiles
  /// and the category donut).
  static Color categoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'food':
      case 'dining':
        return const Color(0xFFFF6D5A);
      case 'transport':
        return const Color(0xFF7C6AF0);
      case 'groceries':
        return const Color(0xFF46B87C);
      case 'entertainment':
        return const Color(0xFFF06EC0);
      case 'shopping':
        return const Color(0xFFF2A84B);
      case 'health':
        return const Color(0xFF5AD1D6);
      case 'education':
        return const Color(0xFF7FA8F0);
      case 'rent':
        return const Color(0xFFE05B5B);
      case 'utilities':
        return const Color(0xFFF0C95A);
      case 'salary':
      case 'income':
        return primaryGreen;
      default:
        return const Color(0xFF9AA5A0);
    }
  }

  static IconData? categoryIconData(String category) => null; // filled by UI layer
}

class AppTheme {
  static ThemeData light() => _theme(Brightness.light);
  static ThemeData dark() => _theme(Brightness.dark);

  static ThemeData _theme(Brightness b) {
    final isDark = b == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: b,
      scaffoldBackgroundColor: AppColors.background(isDark),
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryGreen,
        brightness: b,
        primary: isDark ? const Color(0xFF4EDDA6) : AppColors.primaryGreen,
        secondary: AppColors.accentBlue,
        surface: AppColors.card(isDark),
        error: AppColors.accentRed,
      ),
      fontFamily: 'Inter',
      textTheme: _textTheme(isDark),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background(isDark),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary(isDark),
          fontFamily: 'Inter',
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.card(isDark),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card(isDark),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primaryGreen, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
    );
  }

  static TextTheme _textTheme(bool isDark) {
    Color c = AppColors.textPrimary(isDark);
    return TextTheme(
      displayLarge: TextStyle(fontSize: 40, fontWeight: FontWeight.w700, color: c, letterSpacing: -1),
      displayMedium: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: c, letterSpacing: -0.5),
      headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: c),
      headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: c),
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: c),
      titleMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: c),
      bodyLarge: TextStyle(fontSize: 16, color: c, height: 1.45),
      bodyMedium: TextStyle(fontSize: 14, color: c, height: 1.45),
      bodySmall: TextStyle(fontSize: 12.5, color: AppColors.textSecondary(isDark), height: 1.4),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c),
    );
  }
}
