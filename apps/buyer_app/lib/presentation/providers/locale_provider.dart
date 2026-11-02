// lib/presentation/providers/locale_provider.dart
// App language: device-persisted, synced to backend preferences.language.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sitedrop_core/core/utils/app_logger.dart';
import 'package:sitedrop_core/data/services/preferences_service.dart';

const _localeKey = 'app_locale';

final localeProvider =
    NotifierProvider<AppLocaleNotifier, String>(AppLocaleNotifier.new);

class AppLocaleNotifier extends Notifier<String> {
  @override
  String build() {
    _loadLocal();
    return 'en';
  }

  Future<void> _loadLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_localeKey);
      if (code != null && AppLanguages.isSupported(code)) {
        state = code;
      }
    } catch (_) {}
  }

  Locale get locale => Locale(state);

  /// Persist locally + sync to account (best-effort when signed in).
  Future<void> setLocale(String code) async {
    if (!AppLanguages.isSupported(code)) return;
    state = code;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localeKey, code);
    } catch (_) {}
    try {
      await PreferencesService.updatePreferences({'language': code});
    } catch (e) {
      AppLogger.w('Language sync to server failed: $e');
    }
  }
}
