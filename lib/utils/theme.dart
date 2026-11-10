import 'package:flutter/material.dart';

/// Central place for LearnSignPH's colors, text styles, and ThemeData.
/// Keeping this separate means every screen stays visually consistent
/// without repeating color codes everywhere.
class AppColors {
  static const Color primary = Color(0xFF1F3F63);
  static const Color primaryLight = Color(0xFF4C7DB2);
  static const Color accent = Color(0xFFE0A13D);
  static const Color accentSoft = Color(0xFFF5D491);
  static const Color success = Color(0xFF57A96A);
  static const Color background = Color(0xFFE9EEF6);
  static const Color panel = Color(0xFF254B74);
  static const Color card = Color(0xFFF7F9FC);
  static const Color surface = Color(0xFFE4ECF4);
  static const Color textDark = Color(0xFF1F2E3D);
  static const Color textMuted = Color(0xFF6D7D8D);
  static const Color border = Color(0xFFC7D5E3);
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
      listTileTheme: const ListTileThemeData(
        tileColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        color: Colors.white,
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
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: AppColors.primary.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            );
          }
          return const TextStyle(
            fontWeight: FontWeight.w500,
            color: AppColors.textMuted,
          );
        }),
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
