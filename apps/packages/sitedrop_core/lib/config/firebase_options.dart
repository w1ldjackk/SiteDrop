// lib/config/firebase_options.dart
import 'package:firebase_core/firebase_core.dart' show Firebase, FirebaseApp, FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

import '../core/utils/app_logger.dart';

/// Default [FirebaseOptions] for each platform.
///
/// Web options match Firebase project `sitedrop-eb666` (Console → Project settings).
/// Keep `web/firebase-messaging-sw.js` in sync with [FirebaseOptionsConfig.web].
class FirebaseOptionsConfig {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        // Desktop Windows uses the web app credentials when no native app exists.
        return web;
      case TargetPlatform.linux:
        return web;
      case TargetPlatform.fuchsia:
        return web;
    }
  }

  // ============================================================
  // WEB CONFIGURATION (live — sitedrop-eb666)
  // ============================================================
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAa331pMsUyRe1hsawxYUtOxPJgkby5AKU',
    appId: '1:865592120613:web:b74ecba6ee5f84cb9f36cc',
    messagingSenderId: '865592120613',
    projectId: 'sitedrop-eb666',
    authDomain: 'sitedrop-eb666.firebaseapp.com',
    storageBucket: 'sitedrop-eb666.appspot.com',
    measurementId: 'G-Z04D88MJW9',
  );

  // ============================================================
  // ANDROID — replace via `flutterfire configure` when ready
  // ============================================================
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
    appId: '1:123456789:android:abcdef1234567890',
    messagingSenderId: '865592120613',
    projectId: 'sitedrop-eb666',
    storageBucket: 'sitedrop-eb666.appspot.com',
  );

  // ============================================================
  // iOS — replace via `flutterfire configure` when ready
  // ============================================================
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
    appId: '1:123456789:ios:abcdef1234567890',
    messagingSenderId: '865592120613',
    projectId: 'sitedrop-eb666',
    storageBucket: 'sitedrop-eb666.appspot.com',
    iosClientId:
        '123456789-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx.apps.googleusercontent.com',
    iosBundleId: 'com.sitedrop.sitedropMobile',
  );

  // ============================================================
  // macOS — replace via `flutterfire configure` when ready
  // ============================================================
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
    appId: '1:123456789:ios:abcdef1234567890',
    messagingSenderId: '865592120613',
    projectId: 'sitedrop-eb666',
    storageBucket: 'sitedrop-eb666.appspot.com',
    iosClientId:
        '123456789-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx.apps.googleusercontent.com',
    iosBundleId: 'com.sitedrop.sitedropMobile',
  );
}

// ============================================================
// ENVIRONMENT SELECTOR + SAFE INIT
// ============================================================
class FirebaseEnv {
  static const bool isProduction = bool.fromEnvironment(
    'dart.vm.product',
    defaultValue: false,
  );

  /// Resolved options for the current platform (never silent stub for web).
  static FirebaseOptions get options {
    final platform = FirebaseOptionsConfig.currentPlatform;
    if (isPlaceholder(platform)) {
      // Prefer live web credentials over broken placeholders on desktop/dev.
      if (!isPlaceholder(FirebaseOptionsConfig.web)) {
        return FirebaseOptionsConfig.web;
      }
      return platform;
    }
    return platform;
  }

  static bool get hasValidOptions => !isPlaceholder(options);

  static bool isPlaceholder(FirebaseOptions o) {
    final key = o.apiKey.trim();
    final appId = o.appId.trim();
    return key.isEmpty ||
        key.contains('xxxx') ||
        key.contains('XXXX') ||
        key == 'YOUR_API_KEY' ||
        key.startsWith('AIzaSyBxxxxx') ||
        appId.contains('123456789') ||
        o.projectId == 'sitedrop-dev' ||
        o.messagingSenderId == '123456789';
  }

  static bool _optionsMatch(FirebaseOptions a, FirebaseOptions b) {
    return a.apiKey == b.apiKey &&
        a.appId == b.appId &&
        a.projectId == b.projectId &&
        a.messagingSenderId == b.messagingSenderId;
  }

  /// Idempotent init. Replaces a stale/wrong default app (hot restart on web).
  static Future<FirebaseApp?> ensureInitialized() async {
    final desired = options;

    if (isPlaceholder(desired)) {
      AppLogger.w(
        'Firebase options look like placeholders — skip init. '
        'Run `flutterfire configure` or set real keys in firebase_options.dart.',
      );
      return null;
    }

    try {
      if (Firebase.apps.isNotEmpty) {
        final existing = Firebase.app();
        if (_optionsMatch(existing.options, desired)) {
          AppLogger.i(
            'ℹ️ Firebase already initialized '
            '(${existing.name}, project=${desired.projectId})',
          );
          return existing;
        }

        // Stale default app (common after web hot restart with old placeholders).
        // Replacing it is expected recovery, not a failure.
        AppLogger.i(
          '♻️ Replacing stale Firebase app with current project config '
          '(${desired.projectId})',
        );
        await existing.delete();
      }

      final app = await Firebase.initializeApp(options: desired);
      AppLogger.i(
        '✅ Firebase ready '
        '(${isProduction ? "PRODUCTION" : "DEVELOPMENT"}, '
        'project=${desired.projectId})',
      );
      return app;
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('duplicate-app') && Firebase.apps.isNotEmpty) {
        final app = Firebase.app();
        if (_optionsMatch(app.options, desired)) {
          AppLogger.w('Firebase duplicate-app race; using existing default app');
          return app;
        }
        try {
          await app.delete();
          final recreated = await Firebase.initializeApp(options: desired);
          AppLogger.i('✅ Firebase re-created after duplicate-app');
          return recreated;
        } catch (e2) {
          AppLogger.e('❌ Firebase re-init failed: $e2');
          return Firebase.apps.isNotEmpty ? Firebase.app() : null;
        }
      }
      AppLogger.e('❌ Firebase initialization error: $e');
      return null;
    }
  }
}
