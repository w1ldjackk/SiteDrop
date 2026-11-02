// lib/data/services/settings_service.dart
// Client for Laravel Api\SettingController
import '../../core/constants/api_constants.dart';
import 'api_service.dart';

class SettingsService {
  SettingsService._();

  /// GET /settings/appearance → { theme_mode: system|light|dark }
  static Future<String> getThemeMode() async {
    try {
      final response = await ApiService.get<Map<String, dynamic>>(
        ApiConstants.settingsAppearance,
      );
      final data = response['data'] as Map<String, dynamic>? ?? {};
      return data['theme_mode']?.toString() ?? 'system';
    } catch (_) {
      // Fallback: full settings payload
      try {
        final response = await ApiService.get<Map<String, dynamic>>(
          ApiConstants.settings,
        );
        final data = response['data'] as Map<String, dynamic>? ?? {};
        final settings = data['settings'] as Map<String, dynamic>? ?? data;
        return settings['theme_mode']?.toString() ?? 'system';
      } catch (e) {
        rethrow;
      }
    }
  }

  /// PUT /settings/appearance  body: { theme_mode }
  static Future<String> setThemeMode(String themeMode) async {
    final response = await ApiService.put<Map<String, dynamic>>(
      ApiConstants.settingsAppearance,
      data: {'theme_mode': themeMode},
    );

    if (response['status'] != 'success') {
      throw Exception(
        response['message']?.toString() ?? 'Failed to save appearance',
      );
    }

    final data = response['data'] as Map<String, dynamic>? ?? {};
    return data['theme_mode']?.toString() ?? themeMode;
  }

  /// GET /settings — all user settings map
  static Future<Map<String, dynamic>> getAll() async {
    final response = await ApiService.get<Map<String, dynamic>>(
      ApiConstants.settings,
    );
    final data = response['data'] as Map<String, dynamic>? ?? {};
    final settings = data['settings'];
    if (settings is Map<String, dynamic>) return settings;
    if (settings is Map) return Map<String, dynamic>.from(settings);
    return {};
  }

  /// PUT /settings/{key}  body: { val }
  static Future<dynamic> setKey(String key, dynamic value) async {
    final response = await ApiService.put<Map<String, dynamic>>(
      ApiConstants.settingKey(key),
      data: {'val': value},
    );
    final data = response['data'] as Map<String, dynamic>? ?? {};
    return data['val'];
  }
}
