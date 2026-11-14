import 'package:flutter/material.dart';

class AppColors {
  // Brand
  static const Color primaryGreen = Color(0xFF00C896);
  static const Color primaryGreenDark = Color(0xFF0A9B7E);
  static const Color primaryGreenLight = Color(0xFFE6FBF4);
  static const Color accentLime = Color(0xFFD7F464);

  static const Color accentRed = Color(0xFFFF5757);
  static const Color accentRedLight = Color(0xFFFFE9E9);

  static const Color accentBlue = Color(0xFF4D9FFF);
  static const Color accentBlueLight = Color(0xFFE5F1FF);

  static const Color accentViolet = Color(0xFF8B7CF6);

  // Dark palette
  static const Color darkBackground = Color(0xFF0D1117);
  static const Color darkCardBackground = Color(0xFF161D27);
  static const Color darkCardElevated = Color(0xFF1E2733);
  static const Color darkTextPrimary = Color(0xFFF5F7FA);
  static const Color darkTextSecondary = Color(0xFF8B95A5);
  static const Color darkDivider = Color(0xFF232D3B);

  // Light palette
  static const Color lightBackground = Color(0xFFF4F6F8);
  static const Color lightCardBackground = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF151B26);
  static const Color lightTextSecondary = Color(0xFF7B8494);
  static const Color lightDivider = Color(0xFFE9EDF2);

  // Semantic helpers
  static Color background(bool isDark) => isDark ? darkBackground : lightBackground;
  static Color card(bool isDark) => isDark ? darkCardBackground : lightCardBackground;
  static Color textPrimary(bool isDark) => isDark ? darkTextPrimary : lightTextPrimary;
  static Color textSecondary(bool isDark) => isDark ? darkTextSecondary : lightTextSecondary;
}

class AppTheme {
  static ThemeData get lightTheme => _theme(Brightness.light);
  static ThemeData get darkTheme => _theme(Brightness.dark);

  static ThemeData _theme(Brightness b) {
    final isDark = b == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: b,
      scaffoldBackgroundColor: AppColors.background(isDark),
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryGreen,
        brightness: b,
        primary: AppColors.primaryGreen,
        secondary: AppColors.accentBlue,
        surface: AppColors.card(isDark),
        error: AppColors.accentRed,
      ),
      fontFamily: 'Inter',
      cardTheme: CardThemeData(
        color: AppColors.card(isDark),
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: isDark
              ? const BorderSide(color: AppColors.darkDivider, width: 1)
              : BorderSide.none,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? AppColors.darkCardElevated : Colors.black87,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.darkCardElevated : Colors.white,
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
          borderSide: const BorderSide(color: AppColors.primaryGreen, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary(isDark),
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.card(isDark),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        showDragHandle: true,
      ),
    );
  }
}
