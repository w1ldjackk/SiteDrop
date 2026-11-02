// lib/data/services/public_config_service.dart
// Loads GET /api/v1/config (SystemSettingController::publicConfig).
import 'package:flutter/foundation.dart';
import '../../core/utils/app_logger.dart';

import '../../config/app_config.dart';
import '../../core/constants/api_constants.dart';
import 'api_service.dart';

class PublicConfigService {
  PublicConfigService._();

  static Map<String, dynamic>? _lastPayload;

  static Map<String, dynamic>? get lastPayload => _lastPayload;

  static String? _str(String key) {
    final v = _lastPayload?[key]?.toString().trim();
    return (v == null || v.isEmpty) ? null : v;
  }

  /// Admin-configured support contacts (/admin/system-settings → General).
  static String? get supportEmail => _str('support_email');
  static String? get supportPhone => _str('support_phone');
  static String? get supportWhatsapp => _str('support_whatsapp');

  /// wa.me digits derived from the WhatsApp number, else the support phone.
  static String? get supportWhatsappDigits {
    final raw = supportWhatsapp ?? supportPhone;
    if (raw == null) return null;
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 9) return null;
    return digits.startsWith('0') && digits.length == 10
        ? '233${digits.substring(1)}'
        : digits;
  }

  static String get _platform {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return 'ios';
      default:
        return 'android';
    }
  }

  /// Fetch public bootstrap config and apply known values (Maps key, etc.).
  /// Safe to call at startup; failures are non-fatal.
  static Future<Map<String, dynamic>?> fetchAndApply() async {
    try {
      ApiService.ensureInitialized();
      final response = await ApiService.get<Map<String, dynamic>>(
        ApiConstants.publicConfig,
        queryParams: {'platform': _platform},
      );

      final data = response['data'];
      if (data is! Map) return null;

      final map = Map<String, dynamic>.from(data);
      _lastPayload = map;
      _applyMapsKey(map);
      _applyFirebaseVapidKey(map);
      return map;
    } catch (e) {
      if (kDebugMode) {
        AppLogger.e('⚠️ Public config load failed: $e');
      }
      return null;
    }
  }

  static void _applyMapsKey(Map<String, dynamic> data) {
    String? key = data['google_maps_api_key']?.toString();

    final maps = data['maps'];
    if ((key == null || key.isEmpty) && maps is Map) {
      key = maps['api_key']?.toString() ?? maps['apiKey']?.toString();
    }

    final settings = data['settings'];
    if ((key == null || key.isEmpty) && settings is Map) {
      key = settings['google_maps_api_key']?.toString();
    }

    if (key != null && key.trim().isNotEmpty) {
      AppConfig.setGoogleMapsApiKey(key);
      if (kDebugMode) {
        AppLogger.i('✅ Google Maps API key applied from public config');
      }
    }
  }

  /// Apply Web Push VAPID **public** key only (never expect private from API).
  static void _applyFirebaseVapidKey(Map<String, dynamic> data) {
    String? key = data['firebase_vapid_public_key']?.toString();

    final firebase = data['firebase'];
    if ((key == null || key.isEmpty) && firebase is Map) {
      key = firebase['vapidKey']?.toString() ??
          firebase['vapid_public_key']?.toString();
      final platforms = firebase['platforms'];
      if ((key == null || key.isEmpty) && platforms is Map) {
        final web = platforms['web'];
        if (web is Map) {
          key = web['vapidKey']?.toString() ?? web['vapid_public_key']?.toString();
        }
      }
    }

    final settings = data['settings'];
    if ((key == null || key.isEmpty) && settings is Map) {
      key = settings['firebase_vapid_public_key']?.toString();
    }

    if (key != null && key.trim().isNotEmpty) {
      AppConfig.setFirebaseVapidKey(key);
      if (kDebugMode) {
        AppLogger.i('✅ Firebase VAPID public key applied from public config');
      }
    }
  }
}
