import 'package:flutter/material.dart';

/// Central place for LearnSignPH's colors, text styles, and ThemeData.
/// Keeping this separate means every screen stays visually consistent
/// without repeating color codes everywhere.
class AppColors {
  static const Color primary = Color(0xFF2C5F8A); // deep blue - matches diagrams
  static const Color primaryLight = Color(0xFF3E7CB1);
  static const Color accent = Color(0xFFC9862B); // orange accent (Firebase/backend color)
  static const Color success = Color(0xFF4C8C4A);
  static const Color background = Color(0xFFF7F9FB);
  static const Color textDark = Color(0xFF222222);
  static const Color textMuted = Color(0xFF666666);
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.accent,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark),
        titleMedium: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark),
        bodyMedium: TextStyle(color: AppColors.textDark),
        bodySmall: TextStyle(color: AppColors.textMuted),
      ),
    );
  }
}
