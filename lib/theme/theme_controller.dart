import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the app's current light/dark setting and persists it across app
/// restarts. One instance lives for the whole app — [themeController] below
/// — and MyApp listens to it to rebuild with the right theme whenever the
/// user flips the toggle.
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController() : super(ThemeMode.light);

  static const _prefsKey = 'themeMode';

  /// Call once at startup, before runApp, to restore the user's saved
  /// choice. Defaults to light mode until they've picked dark at least once.
  Future<void> loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    value = prefs.getString(_prefsKey) == 'dark'
        ? ThemeMode.dark
        : ThemeMode.light;
  }

  Future<void> toggle() async {
    value = value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      value == ThemeMode.dark ? 'dark' : 'light',
    );
  }
}

/// App-wide singleton. Import this file wherever you need to read the
/// current mode or toggle it (e.g. a settings switch on any screen).
final themeController = ThemeController();
