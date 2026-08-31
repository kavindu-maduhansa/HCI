import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Builds the app's Light and Dark [ThemeData] from the centralised
/// [AppColors] tokens, so screens read colours from the active theme
/// instead of hard-coding hex values. System mode is handled by Flutter
/// itself (MaterialApp.themeMode) - it simply selects between these two
/// ThemeData objects based on the OS brightness, so there is no separate
/// third palette.
class AppTheme {
  AppTheme._();

  static final ThemeData light = _build(AppColors.light, Brightness.light);
  static final ThemeData dark = _build(AppColors.dark, Brightness.dark);

  static ThemeData _build(AppColors c, Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: c.primary,
      brightness: brightness,
    ).copyWith(
      primary: c.primary,
      surface: c.surface,
      error: c.critical,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
    );

    return base.copyWith(
      scaffoldBackgroundColor: c.background,
      cardColor: c.surface,
      dividerColor: c.border,
      textTheme: base.textTheme.apply(
        bodyColor: c.textPrimary,
        displayColor: c.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.surface,
        foregroundColor: c.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: c.border),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: c.surface,
        selectedIconTheme: IconThemeData(color: c.primary),
        selectedLabelTextStyle: TextStyle(color: c.primary, fontWeight: FontWeight.bold),
        unselectedLabelTextStyle: TextStyle(color: c.textSecondary),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        indicatorColor: c.primary.withValues(alpha: 0.15),
      ),
      dividerTheme: DividerThemeData(color: c.border),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.elevatedSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.border),
        ),
      ),
      extensions: [c],
    );
  }
}
