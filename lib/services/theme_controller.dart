import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide Appearance (Light / Dark / System) controller.
///
/// Single source of truth for [ThemeMode], following the same
/// singleton pattern already used by `RequestService` in this project.
/// Persisted with SharedPreferences so the selected mode survives an
/// app restart; if preferences are unavailable for any reason this
/// falls back to System mode rather than crashing app startup.
class ThemeController extends ChangeNotifier {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  static const _prefsKey = 'lifelink_theme_mode';

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  /// Call once, before `runApp`, so the saved preference is applied on
  /// the very first frame instead of flashing System theme first.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      _mode = switch (saved) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    } catch (_) {
      _mode = ThemeMode.system;
    }
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };
      await prefs.setString(_prefsKey, value);
    } catch (_) {
      // Persistence failing should not block the mode change itself -
      // the user still sees the theme switch for this session.
    }
  }
}
