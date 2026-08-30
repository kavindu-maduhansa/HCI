import 'package:flutter/material.dart';

/// Centralised colour tokens for LifeLink's Light and Dark themes.
///
/// This is a [ThemeExtension] so any widget can reach the exact palette
/// via `Theme.of(context).extension<AppColors>()` (or the `context.colors`
/// shortcut below) instead of hard-coding hex values inside screens.
///
/// Semantic usage (kept consistent across the whole Doctor module):
///   critical -> blood-related / emergency / destructive actions
///   primary  -> active / live / interactive / selected
///   success  -> verified / completed
///   warning  -> pending / needs attention
///   textSecondary / neutral -> non-critical, informational text
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.elevatedSurface,
    required this.primary,
    required this.champagne,
    required this.critical,
    required this.success,
    required this.warning,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.chartPalette,
  });

  final Color background;
  final Color surface;
  final Color elevatedSurface;

  /// Burgundy - the Doctor / Blood Bank module's identity color.
  /// Used for primary buttons, selected states, and branding accents.
  final Color primary;

  /// Champagne - the premium accent color. Used sparingly for
  /// highlights (e.g. a "best match" ribbon, a premium stat, a subtle
  /// icon tint) - never as a large fill, per the "avoid excessive
  /// gold" visual direction.
  final Color champagne;

  final Color critical;
  final Color success;
  final Color warning;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;

  /// #33 - Distinct hues for multi-series charts (pie/donut, stacked
  /// bars) so categories (e.g. the 8 blood groups) read apart at a
  /// glance. Kept muted/sophisticated rather than neon, to match the
  /// Obsidian + Burgundy + Champagne + Ivory identity. Order is
  /// stable so the same category always gets the same color.
  final List<Color> chartPalette;

  /// Light theme - Obsidian + Burgundy + Champagne + Ivory, "clean
  /// medical space" variant: ivory background, white surfaces, a
  /// warm champagne accent, and burgundy carrying the Doctor/Blood
  /// Bank identity through buttons and selected states.
  static const light = AppColors(
    background: Color(0xFFF6F2ED),
    surface: Color(0xFFFFFFFF),
    elevatedSurface: Color(0xFFEEE8E3),
    primary: Color(0xFF6E1F3A),
    champagne: Color(0xFFA98248),
    critical: Color(0xFFB83D52),
    success: Color(0xFF3E8065),
    warning: Color(0xFFC98F3D),
    textPrimary: Color(0xFF261E21),
    textSecondary: Color(0xFF786D70),
    border: Color(0xFFE1D8D0),
    chartPalette: [
      Color(0xFF6E1F3A), // burgundy
      Color(0xFFA98248), // champagne
      Color(0xFF3E8065), // sage/success green
      Color(0xFF3D6E80), // muted teal
      Color(0xFFB05C3E), // terracotta
      Color(0xFF5C5580), // dusty plum
      Color(0xFFC98F3D), // warm amber
      Color(0xFFB83D52), // muted red
    ],
  );

  /// Dark theme - Obsidian + Burgundy + Champagne + Ivory, "premium
  /// healthcare command center" variant: near-black obsidian
  /// background/surfaces, a brighter champagne accent for legibility,
  /// and burgundy still carrying the module identity.
  static const dark = AppColors(
    background: Color(0xFF0F0C0D),
    surface: Color(0xFF181315),
    elevatedSurface: Color(0xFF221B1E),
    primary: Color(0xFF6E1F3A),
    champagne: Color(0xFFD2B278),
    critical: Color(0xFFB83D52),
    success: Color(0xFF3E8065),
    warning: Color(0xFFC98F3D),
    textPrimary: Color(0xFFF5EEE5),
    textSecondary: Color(0xFF9E9295),
    border: Color(0xFF332A2E),
    chartPalette: [
      Color(0xFFD2B278), // champagne
      Color(0xFFB0577A), // brightened burgundy
      Color(0xFF5CA98A), // sage/success green
      Color(0xFF5C9AAD), // muted teal
      Color(0xFFC98860), // terracotta
      Color(0xFF9089B8), // dusty plum
      Color(0xFFC98F3D), // warm amber
      Color(0xFFB83D52), // muted red
    ],
  );

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? elevatedSurface,
    Color? primary,
    Color? champagne,
    Color? critical,
    Color? success,
    Color? warning,
    Color? textPrimary,
    Color? textSecondary,
    Color? border,
    List<Color>? chartPalette,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      elevatedSurface: elevatedSurface ?? this.elevatedSurface,
      primary: primary ?? this.primary,
      champagne: champagne ?? this.champagne,
      critical: critical ?? this.critical,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      border: border ?? this.border,
      chartPalette: chartPalette ?? this.chartPalette,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    final palette = <Color>[
      for (var i = 0; i < chartPalette.length; i++)
        Color.lerp(chartPalette[i], i < other.chartPalette.length ? other.chartPalette[i] : chartPalette[i], t)!,
    ];
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      elevatedSurface: Color.lerp(elevatedSurface, other.elevatedSurface, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      champagne: Color.lerp(champagne, other.champagne, t)!,
      critical: Color.lerp(critical, other.critical, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      border: Color.lerp(border, other.border, t)!,
      chartPalette: palette,
    );
  }
}

/// Shortcut so screens can write `context.colors.critical` instead of the
/// longer `Theme.of(context).extension<AppColors>()!` call everywhere.
extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>() ?? AppColors.light;
}
