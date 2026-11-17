import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color darkGreen = Color(0xFF0B4D3B);
  static const Color emerald = Color(0xFF10A37F);
  static const Color gold = Color(0xFFC9A227);
  static const Color cream = Color(0xFFFBF8F1);
  static const Color darkBackground = Color(0xFF0F1A17);
  static const Color darkSurface = Color(0xFF172521);
}

class AppTheme {
  AppTheme._();

  static const double radius = 16;

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.darkGreen,
      primary: AppColors.darkGreen,
      secondary: AppColors.emerald,
      tertiary: AppColors.gold,
      surface: AppColors.cream,
      brightness: Brightness.light,
    );
    return _base(scheme).copyWith(scaffoldBackgroundColor: AppColors.cream);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.darkGreen,
      primary: const Color(0xFF6FD3B0),
      secondary: AppColors.emerald,
      tertiary: AppColors.gold,
      surface: AppColors.darkSurface,
      brightness: Brightness.dark,
    );
    return _base(scheme).copyWith(scaffoldBackgroundColor: AppColors.darkBackground);
  }

  static ThemeData _base(ColorScheme scheme) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: shape.copyWith(side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6))),
        color: scheme.brightness == Brightness.light ? Colors.white : scheme.surfaceContainerHigh,
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(radius), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
        ),
      ),
      chipTheme: ChipThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: scheme.secondaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
    );
  }
}
