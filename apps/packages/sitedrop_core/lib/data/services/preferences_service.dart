// lib/data/services/preferences_service.dart
// Client for Laravel Api\ProfileController preferences + SecurityController.

import '../../core/constants/api_constants.dart';
import '../../core/utils/app_logger.dart';
import 'api_service.dart';

/// Notification matrix keys (Settings → Notifications).
/// Categories: products, promos (& tips), partner offers × email/push/sms.
class NotifPrefs {
  static const categories = ['products', 'promos', 'partner'];
  static const channels = ['email', 'push', 'sms'];

  static String key(String category, String channel) =>
      'notif_${category}_$channel';

  /// Server defaults for fresh accounts (partner = opt-in).
  static const defaults = {
    'notif_products_email': true,
    'notif_products_push': true,
    'notif_products_sms': true,
    'notif_promos_email': true,
    'notif_promos_push': true,
    'notif_promos_sms': false,
    'notif_partner_email': false,
    'notif_partner_push': false,
    'notif_partner_sms': false,
  };
}

/// Supported app languages (Settings → Language).
class AppLanguages {
  static const supported = ['en', 'fr', 'tw', 'ha'];

  static const names = {
    'en': 'English',
    'fr': 'Français',
    'tw': 'Twi',
    'ha': 'Hausa',
  };

  static String nameOf(String code) => names[code] ?? names['en']!;

  static bool isSupported(String? code) =>
      code != null && supported.contains(code);
}

class PreferencesService {
  PreferencesService._();

  /// GET /profile/preferences → merged with local defaults.
  static Future<Map<String, dynamic>> getPreferences() async {
    try {
      final response = await ApiService.get<Map<String, dynamic>>(
        ApiConstants.profilePreferences,
      );
      final data = response['data'] as Map<String, dynamic>? ?? {};
      final prefs = data['preferences'];
      final map = prefs is Map<String, dynamic>
          ? prefs
          : prefs is Map
              ? Map<String, dynamic>.from(prefs)
              : <String, dynamic>{};
      return {...NotifPrefs.defaults, ...map};
    } catch (e) {
      AppLogger.e('❌ Error fetching preferences: $e');
      return {...NotifPrefs.defaults, 'language': 'en'};
    }
  }

  /// PUT /profile/preferences — partial updates supported.
  static Future<Map<String, dynamic>> updatePreferences(
    Map<String, dynamic> values,
  ) async {
    try {
      final response = await ApiService.put<Map<String, dynamic>>(
        ApiConstants.profilePreferences,
        data: values,
      );
      if (response['status'] != 'success') {
        throw Exception(
          response['message']?.toString() ?? 'Failed to save preferences',
        );
      }
      final data = response['data'] as Map<String, dynamic>? ?? {};
      final prefs = data['preferences'];
      if (prefs is Map<String, dynamic>) return prefs;
      if (prefs is Map) return Map<String, dynamic>.from(prefs);
      return values;
    } catch (e) {
      AppLogger.e('❌ Error updating preferences: $e');
      rethrow;
    }
  }

  static bool boolOf(Map<String, dynamic> prefs, String key,
      [bool fallback = true]) {
    final v = prefs[key];
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.toLowerCase().trim();
      if (s == '1' || s == 'true') return true;
      if (s == '0' || s == 'false') return false;
    }
    return fallback;
  }
}

class SecurityService {
  SecurityService._();

  /// POST /profile/password
  static Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final response = await ApiService.post<Map<String, dynamic>>(
      ApiConstants.profilePassword,
      data: {
        'current_password': currentPassword,
        'password': newPassword,
        'password_confirmation': confirmPassword,
      },
    );
    if (response['status'] != 'success') {
      throw Exception(
        response['message']?.toString() ?? 'Could not change password',
      );
    }
  }

  /// GET /profile/2fa/status → { enabled, confirmed }
  static Future<({bool enabled, bool confirmed})> twoFactorStatus() async {
    try {
      final response = await ApiService.get<Map<String, dynamic>>(
        ApiConstants.twoFactorStatus,
      );
      final data = response['data'] as Map<String, dynamic>? ?? {};
      return (
        enabled: data['enabled'] == true,
        confirmed: data['confirmed'] == true,
      );
    } catch (e) {
      AppLogger.e('❌ Error fetching 2FA status: $e');
      return (enabled: false, confirmed: false);
    }
  }

  /// POST /profile/2fa/enable → { secret, otpauth_url, recovery_codes }
  static Future<Map<String, dynamic>> enableTwoFactor() async {
    final response = await ApiService.post<Map<String, dynamic>>(
      ApiConstants.twoFactorEnable,
    );
    if (response['status'] != 'success') {
      throw Exception(
        response['message']?.toString() ?? 'Could not start 2FA setup',
      );
    }
    final data = response['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw Exception('Invalid 2FA setup response');
  }

  /// POST /profile/2fa/confirm { code }
  static Future<void> confirmTwoFactor(String code) async {
    final response = await ApiService.post<Map<String, dynamic>>(
      ApiConstants.twoFactorConfirm,
      data: {'code': code.trim()},
    );
    if (response['status'] != 'success') {
      throw Exception(
        response['message']?.toString() ?? 'Invalid authenticator code',
      );
    }
  }

  /// DELETE /profile/2fa
  static Future<void> disableTwoFactor() async {
    final response = await ApiService.delete<Map<String, dynamic>>(
      ApiConstants.twoFactorDisable,
    );
    if (response['status'] != 'success') {
      throw Exception(
        response['message']?.toString() ?? 'Could not disable 2FA',
      );
    }
  }
}
