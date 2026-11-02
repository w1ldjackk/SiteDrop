// lib/data/services/notification_service.dart
import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../config/app_config.dart';
import '../../config/firebase_options.dart';
import '../../core/constants/api_constants.dart';
import '../../core/utils/app_logger.dart';
import 'api_service.dart';

/// Background FCM handler (must be top-level). Mobile only —
/// web uses `web/firebase-messaging-sw.js` instead.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Keep lightweight — no UI work here.
  AppLogger.d('FCM background: ${message.messageId}');
}

/// Push notifications via [firebase_messaging] + backend token registration.
class NotificationService {
  NotificationService._();

  static FirebaseMessaging? _messaging;
  static bool _initialized = false;
  static String? _fcmToken;

  /// Last token successfully POSTed to the backend this process lifetime.
  static String? _lastRegisteredToken;

  /// Coalesce concurrent register-token calls into one network request.
  static Future<void>? _registerInFlight;

  static String? get fcmToken => _fcmToken;

  /// Foreground pushes — apps listen to show a toast + refresh the inbox.
  static final StreamController<RemoteMessage> _foregroundController =
      StreamController<RemoteMessage>.broadcast();
  static Stream<RemoteMessage> get foregroundMessages =>
      _foregroundController.stream;

  /// Notification taps (incl. cold start) — apps listen to deep-link.
  static final StreamController<RemoteMessage> _openedController =
      StreamController<RemoteMessage>.broadcast();
  static Stream<RemoteMessage> get openedMessages => _openedController.stream;

  static Future<void> initialize() async {
    if (_initialized) return;
    if (!AppConfig.enableFirebase) {
      AppLogger.i('Firebase disabled — skip push notifications');
      return;
    }

    if (Firebase.apps.isEmpty) {
      AppLogger.w('No Firebase app — skip push notifications');
      return;
    }

    // Guard against stale hot-restart app still holding placeholder keys.
    final active = Firebase.app().options;
    if (FirebaseEnv.isPlaceholder(active)) {
      AppLogger.w(
        'Active Firebase app has invalid API key/options — skip FCM. '
        'Do a full browser refresh after fixing firebase_options.dart.',
      );
      return;
    }

    // Web needs SW + VAPID. Without VAPID, skip token fetch (avoids noisy errors
    // while still allowing Firebase.initializeApp for other features).
    if (kIsWeb && !AppConfig.enablePushNotifications) {
      AppLogger.i(
        'Web FCM push skipped — missing FIREBASE_VAPID_KEY. '
        'Service worker: web/firebase-messaging-sw.js. '
        'Run with --dart-define=FIREBASE_VAPID_KEY=… when ready.',
      );
      _initialized = true;
      return;
    }

    try {
      _messaging = FirebaseMessaging.instance;

      // Background handler is a native/mobile entry-point; web uses the SW.
      if (!kIsWeb) {
        FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      }

      final settings = await _messaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      AppLogger.i('FCM permission: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        await _refreshToken();
        _messaging!.onTokenRefresh.listen((token) {
          _fcmToken = token;
          registerTokenWithBackend(token);
        });
      }

      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpened);

      // Cold start from notification tap
      final initial = await _messaging!.getInitialMessage();
      if (initial != null) {
        _onMessageOpened(initial);
      }

      _initialized = true;
      AppLogger.i('NotificationService initialized');
    } catch (e, st) {
      AppLogger.e('NotificationService init failed', error: e, stackTrace: st);
    }
  }

  static Future<void> _refreshToken() async {
    try {
      if (kIsWeb) {
        final vapid = AppConfig.firebaseVapidKey.trim();
        if (vapid.isEmpty) {
          AppLogger.i('Web FCM token skipped — no VAPID key');
          return;
        }
        _fcmToken = await _messaging?.getToken(vapidKey: vapid);
      } else {
        // iOS needs APNS token first in some setups; ignore failures in dev.
        _fcmToken = await _messaging?.getToken();
      }

      if (_fcmToken != null && _fcmToken!.isNotEmpty) {
        final suffix = _fcmToken!.length > 8
            ? _fcmToken!.substring(_fcmToken!.length - 8)
            : _fcmToken!;
        AppLogger.i(
          'FCM token acquired (…$suffix, ${kIsWeb ? "web" : "mobile"})',
        );
        await registerTokenWithBackend(_fcmToken!);
      } else {
        AppLogger.w('FCM getToken returned empty — check permission / VAPID / SW');
      }
    } catch (e) {
      final msg = e.toString();
      // Common when SW is missing/mis-served or keys are wrong — keep soft.
      if (msg.contains('failed-service-worker-registration') ||
          msg.contains('unsupported MIME type') ||
          msg.contains('firebase-messaging-sw.js')) {
        AppLogger.w(
          'Could not get FCM token (service worker). '
          'Ensure web/firebase-messaging-sw.js is present and hard-reload. $e',
        );
        return;
      }
      if (msg.contains('API key not valid') ||
          msg.contains('INVALID_ARGUMENT') ||
          msg.contains('installations/request-failed')) {
        AppLogger.w(
          'Could not get FCM token (invalid Firebase API key / project). '
          'Confirm firebase_options.dart web keys match Console, then full refresh. $e',
        );
        return;
      }
      AppLogger.w('Could not get FCM token: $e');
    }
  }

  /// Register device token with Laravel `POST /notifications/register-token`.
  /// Requires an authenticated Sanctum session (guest tokens stay local only).
  ///
  /// Same token is only POSTed once per process (unless [force] or token rotates).
  static Future<void> registerTokenWithBackend(
    String token, {
    bool force = false,
  }) async {
    if (token.isEmpty) return;

    if (!force && _lastRegisteredToken == token) {
      AppLogger.d('FCM token already registered this session — skip');
      return;
    }

    if (_registerInFlight != null) {
      AppLogger.d('FCM register already in flight — joining');
      await _registerInFlight;
      return;
    }

    _registerInFlight = _doRegisterToken(token, force: force);
    try {
      await _registerInFlight;
    } finally {
      _registerInFlight = null;
    }
  }

  static Future<void> _doRegisterToken(
    String token, {
    bool force = false,
  }) async {
    try {
      ApiService.ensureInitialized();
      final authToken = await ApiService.getAuthToken();
      if (authToken == null || authToken.isEmpty) {
        AppLogger.d(
          'FCM token not sent to backend yet — user not signed in '
          '(will register after login via SessionBootstrap)',
        );
        return;
      }

      // Re-check after auth gate in case another waiter finished first.
      if (!force && _lastRegisteredToken == token) {
        AppLogger.d('FCM token already registered this session — skip');
        return;
      }

      await ApiService.post(
        ApiConstants.notificationRegisterToken,
        data: {
          'token': token,
          'platform': defaultTargetPlatform.name,
          'device_type': kIsWeb ? 'web' : defaultTargetPlatform.name,
        },
      );
      _lastRegisteredToken = token;
      AppLogger.i('FCM token registered with backend');
    } catch (e) {
      // Guest / offline / 401 — non-fatal
      AppLogger.w('FCM token registration skipped/failed: $e');
    }
  }

  /// Re-register the current device token after login (if already acquired).
  static Future<void> syncTokenWithBackend({bool force = false}) async {
    if (_fcmToken != null && _fcmToken!.isNotEmpty) {
      await registerTokenWithBackend(_fcmToken!, force: force);
      return;
    }
    if (_messaging != null) {
      await _refreshToken();
    }
  }

  /// Clear registration cache on logout so the next user can register.
  static void clearRegistrationCache() {
    _lastRegisteredToken = null;
    AppLogger.d('FCM registration cache cleared');
  }

  static void _onForegroundMessage(RemoteMessage message) {
    final title = message.notification?.title ?? message.data['title'];
    final body = message.notification?.body ?? message.data['body'];
    AppLogger.i('FCM foreground: $title — $body');
    if (!_foregroundController.isClosed) {
      _foregroundController.add(message);
    }
  }

  static void _onMessageOpened(RemoteMessage message) {
    AppLogger.i('FCM opened app: ${message.data}');
    if (!_openedController.isClosed) {
      _openedController.add(message);
    }
  }

  static Future<void> subscribeToTopic(String topic) async {
    await _messaging?.subscribeToTopic(topic);
  }

  static Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging?.unsubscribeFromTopic(topic);
  }
}
