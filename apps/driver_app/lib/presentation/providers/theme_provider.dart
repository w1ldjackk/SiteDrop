// lib/presentation/providers/theme_provider.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sitedrop_core/core/utils/app_logger.dart';
import 'package:sitedrop_core/data/services/settings_service.dart';
import 'package:sitedrop_core/data/services/storage_service.dart';

const _themeModeKey = 'theme_mode';

/// App theme mode: system / light / dark.
/// Local cache + API sync (settings.theme_mode) when authenticated.
final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  bool _syncing = false;

  @override
  ThemeMode build() {
    // Default follows device system appearance until user picks a preference.
    _loadLocal();
    Future.microtask(_syncFromApiIfAuthenticated);
    return ThemeMode.system;
  }

  Future<void> _loadLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_themeModeKey);
      // No saved preference → stay on system (do not force light/dark).
      if (raw == null || raw.trim().isEmpty) {
        state = ThemeMode.system;
        return;
      }
      state = _fromString(raw);
    } catch (_) {
      state = ThemeMode.system;
    }
  }

  Future<void> _saveLocal(ThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeModeKey, _toString(mode));
    } catch (_) {
      // Local theme cache write failed — non-fatal.
    }
  }

  Future<bool> _hasAuthToken() async {
    try {
      final token = await StorageService.getAuthToken();
      return token != null && token.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _syncFromApiIfAuthenticated() async {
    if (_syncing) return;
    if (!await _hasAuthToken()) return;

    _syncing = true;
    try {
      final remote = await SettingsService.getThemeMode();
      // Empty/unknown server value → treat as system default
      final mode = remote.trim().isEmpty
          ? ThemeMode.system
          : _fromString(remote);
      if (mode != state) {
        state = mode;
      }
      await _saveLocal(mode);
    } catch (_) {
      // Offline / guest — keep local or system
    } finally {
      _syncing = false;
    }
  }

  /// Call after login to pull server preference.
  Future<void> syncFromServer() => _syncFromApiIfAuthenticated();

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await _saveLocal(mode);

    if (!await _hasAuthToken()) return;

    try {
      await SettingsService.setThemeMode(_toString(mode));
    } catch (e) {
      AppLogger.w('Theme API save failed: $e');
    }
  }

  Future<void> cycle() async {
    final next = switch (state) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    };
    await setThemeMode(next);
  }

  String get label => switch (state) {
        ThemeMode.system => 'System',
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
      };

  static ThemeMode _fromString(String raw) {
    return switch (raw.toLowerCase().trim()) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  static String _toString(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
  }
}
