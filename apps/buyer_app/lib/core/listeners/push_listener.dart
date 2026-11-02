// lib/core/listeners/push_listener.dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sitedrop_core/core/utils/app_logger.dart';
import 'package:sitedrop_core/core/utils/helpers.dart';
import 'package:sitedrop_core/data/services/notification_service.dart';

import '../../app/routes/app_router.dart';
import '../../presentation/providers/notification_provider.dart';

/// Wires FCM pushes into the UI:
/// - foreground message → toast + inbox/badge refresh
/// - notification tap (or cold start) → inbox refresh + deep-link route
class PushListener {
  static StreamSubscription? _foregroundSub;
  static StreamSubscription? _openedSub;

  static void setup(WidgetRef ref) {
    _foregroundSub ??= NotificationService.foregroundMessages.listen((message) {
      _refreshInbox(ref);

      final title =
          message.notification?.title ?? message.data['title']?.toString();
      final body =
          message.notification?.body ?? message.data['body']?.toString();
      if (body != null && body.isNotEmpty) {
        Helpers.showInfoToast(body, title: title ?? 'Notification');
      }
    });

    _openedSub ??= NotificationService.openedMessages.listen((message) {
      _refreshInbox(ref);

      final route = message.data['route']?.toString();
      if (route != null && route.startsWith('/')) {
        AppLogger.i('Push tap → $route');
        try {
          ref.read(appRouterProvider).go(route);
        } catch (e) {
          AppLogger.w('Push deep-link failed: $e');
        }
      }
    });
  }

  static void _refreshInbox(WidgetRef ref) {
    try {
      ref.invalidate(notificationsProvider);
      ref.invalidate(notificationBadgeBootstrapProvider);
    } catch (e) {
      AppLogger.w('Inbox refresh after push failed: $e');
    }
  }
}
