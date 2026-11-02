// lib/config/app_config.dart
import 'package:flutter/foundation.dart';

import 'app_flavor.dart';

class AppConfig {
  // ============================================================
  // APP ROLE / FLAVOR
  // ============================================================
  /// Compile-time role: `--dart-define=APP_ROLE=buyer|seller|driver`
  /// Prefer this over mutating [flavor] so release builds are locked.
  static const String _appRoleDefine = String.fromEnvironment(
    'APP_ROLE',
    defaultValue: '',
  );

  /// Runtime override (optional). Prefer [applyRoleFromDefines] in main().
  static AppFlavor? _flavorOverride;

  /// Effective role. Order: override → APP_ROLE define → buyer default.
  static AppFlavor get flavor {
    if (_flavorOverride != null) return _flavorOverride!;
    return AppFlavor.fromString(_appRoleDefine) ?? AppFlavor.buyer;
  }

  /// Alias for [flavor] (docs / migration plan use `AppConfig.role`).
  static AppFlavor get role => flavor;

  /// `buyer` | `seller` | `driver` string for API register / analytics.
  static String get roleName => flavor.apiRole;

  /// Call once at startup if you set role only in code (not dart-define).
  static void setFlavor(AppFlavor value) => _flavorOverride = value;

  /// Apply dart-define APP_ROLE (no-op if empty; keeps default).
  static void applyRoleFromDefines() {
    final parsed = AppFlavor.fromString(_appRoleDefine);
    if (parsed != null) _flavorOverride = parsed;
  }

  // ============================================================
  // ENVIRONMENT
  // ============================================================
  static const bool isProduction = bool.fromEnvironment(
    'dart.vm.product',
    defaultValue: false,
  );

  static bool get isDevelopment => !isProduction;
  static bool get isWeb => kIsWeb;
  static bool get isMobile => !kIsWeb;

  // ============================================================
  // API CONFIGURATION
  // ============================================================
  /// Override host, e.g.:
  ///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
  ///   flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000
  static const String apiBaseUrlOverride = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  /// When true (default on Android), use 10.0.2.2 for the host machine.
  /// Set false + run tools/fix-emulator-network.ps1 (adb reverse) to use localhost.
  static const bool useAndroidEmulatorLoopback = bool.fromEnvironment(
    'USE_ANDROID_EMULATOR_LOOPBACK',
    defaultValue: true,
  );

  static const String prodBaseUrl = 'https://api.sitedrop.com';

  /// Android emulator special alias → host PC 127.0.0.1
  static const String androidEmulatorHost = 'http://10.0.2.2:8000';

  /// Works on desktop / iOS sim / after `adb reverse tcp:8000 tcp:8000`
  static const String localhostHost = 'http://localhost:8000';

  /// Dev API origin (scheme + host + port, no path).
  static String get devBaseUrl {
    final override = apiBaseUrlOverride.trim();
    if (override.isNotEmpty) {
      return _normalizeDevOrigin(override.replaceAll(RegExp(r'/+$'), ''));
    }

    if (kIsWeb) return localhostHost;

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // Emulator cannot use localhost unless adb reverse is set up.
        return useAndroidEmulatorLoopback
            ? androidEmulatorHost
            : localhostHost;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return localhostHost;
    }
  }

  /// `10.0.2.2` is only valid inside the Android emulator.
  /// On web / desktop / iOS, always map it to localhost.
  static String _normalizeDevOrigin(String origin) {
    final onlyAndroidEmulator =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    if (onlyAndroidEmulator) return origin;

    return origin
        .replaceAll('http://10.0.2.2', 'http://localhost')
        .replaceAll('https://10.0.2.2', 'https://localhost')
        .replaceAll('//10.0.2.2', '//localhost');
  }

  /// Final API base including `/api/v1`. Always sanitized for the current platform.
  static String get apiBaseUrl {
    final origin = isProduction ? prodBaseUrl : devBaseUrl;
    return _normalizeDevOrigin('$origin/api/v1');
  }

  /// Same as [apiBaseUrl] (web uses identical host rules after normalize).
  static String get webApiUrl => apiBaseUrl;

  static String get apiUrl => apiBaseUrl;

  // ============================================================
  // APP INFO
  // ============================================================
  static const String appName = 'SiteDrop';
  static const String appVersion = '1.0.0';

  /// Display name includes role when not generic.
  static String get appDisplayName => switch (flavor) {
        AppFlavor.buyer => 'SiteDrop',
        AppFlavor.seller => 'SiteDrop Seller',
        AppFlavor.driver => 'SiteDrop Driver',
      };
  static const String appPackageName = 'com.sitedrop.app';

  /// Public web base for product share links (no trailing slash).
  /// Override: `--dart-define=SHARE_BASE_URL=https://sitedrop.com`
  static const String shareBaseUrl = String.fromEnvironment(
    'SHARE_BASE_URL',
    defaultValue: 'https://sitedrop.com',
  );

  /// Deep-link / web URL for a product detail page.
  static String productShareUrl(String productId) {
    final base = shareBaseUrl.replaceAll(RegExp(r'/+$'), '');
    return '$base/products/$productId';
  }

  // ============================================================
  // FEATURE FLAGS
  // ============================================================
  /// Skip Firebase when keys are placeholders (avoids noise offline / misconfig).
  static bool get enableFirebase {
    // Allow force-disable: --dart-define=ENABLE_FIREBASE=false
    const forced = String.fromEnvironment('ENABLE_FIREBASE', defaultValue: '');
    if (forced == 'false') return false;
    if (forced == 'true') return true;
    return true;
  }

  /// Web Push (VAPID) **public** key — Firebase Console → Cloud Messaging.
  /// Required for `FirebaseMessaging.getToken` on web.
  /// Override: `--dart-define=FIREBASE_VAPID_KEY=BNxxxx…`
  /// Runtime override via [setFirebaseVapidKey] (public config API).
  /// Never put the VAPID **private** key in the client.
  static const String _firebaseVapidKeyDefine = String.fromEnvironment(
    'FIREBASE_VAPID_KEY',
    defaultValue:
        'BEHkItGxhCP01qFdG69Ji597oAPWZpvv3_7aInk8ZgcbEZDEJYRqSZG6Ekoo9C3Wgx34rMjnjaDYjXUk1qjLSMs',
  );

  static String? _firebaseVapidKeyRuntime;

  static String get firebaseVapidKey {
    final runtime = _firebaseVapidKeyRuntime?.trim() ?? '';
    if (runtime.isNotEmpty) return runtime;
    return _firebaseVapidKeyDefine.trim();
  }

  static void setFirebaseVapidKey(String? key) {
    final v = key?.trim() ?? '';
    _firebaseVapidKeyRuntime = v.isEmpty ? null : v;
  }

  static bool get hasFirebaseVapidKey => firebaseVapidKey.isNotEmpty;

  static bool get enableAnalytics => isProduction;
  static bool get enableCrashReporting => isProduction;

  /// Mobile: follows [enableFirebase].
  /// Web: only when VAPID is configured (SW alone is not enough for getToken).
  static bool get enablePushNotifications {
    if (!enableFirebase) return false;
    if (kIsWeb) return hasFirebaseVapidKey;
    return true;
  }

  static bool get enableGoogleMaps => true;
  static bool get enablePaystack => isProduction;

  /// Driver-only: background location / trip tracking.
  /// `--dart-define=BACKGROUND_LOCATION=true`
  static const bool backgroundLocation = bool.fromEnvironment(
    'BACKGROUND_LOCATION',
    defaultValue: false,
  );

  /// Feature gates by role (use in UI instead of hard-coding screens).
  static bool get allowsGuestBrowse => role.isBuyer;
  static bool get requiresAuthAtLaunch => !role.isBuyer;
  static bool get enablesCartWishlist => role.isBuyer;
  static bool get enablesSellerCatalog => role.isSeller;
  static bool get enablesDriverTracking =>
      role.isDriver || backgroundLocation;

  // ============================================================
  // MAPS / LOCATION
  // ============================================================
  /// Compile-time fallback: `--dart-define=GOOGLE_MAPS_API_KEY=…`
  static const String _googleMapsApiKeyDefine = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: '',
  );

  /// Runtime key from Laravel `GET /api/v1/config` (preferred).
  static String? _googleMapsApiKeyRuntime;

  /// Effective Maps key: runtime (publicConfig) → dart-define → empty.
  static String get googleMapsApiKey {
    final runtime = _googleMapsApiKeyRuntime?.trim() ?? '';
    if (runtime.isNotEmpty) return runtime;
    return _googleMapsApiKeyDefine.trim();
  }

  /// Apply key from SystemSettingController publicConfig / admin settings.
  static void setGoogleMapsApiKey(String? key) {
    final v = key?.trim() ?? '';
    _googleMapsApiKeyRuntime = v.isEmpty ? null : v;
  }

  static bool get hasGoogleMapsApiKey => googleMapsApiKey.isNotEmpty;
}
