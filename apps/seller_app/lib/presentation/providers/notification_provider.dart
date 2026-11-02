// lib/presentation/providers/notification_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sitedrop_core/data/models/notification.dart';
import 'package:sitedrop_core/data/services/inbox_notification_service.dart';
import 'package:sitedrop_core/data/services/storage_service.dart';

final notificationsProvider =
    AsyncNotifierProvider<NotificationsNotifier, List<AppNotificationModel>>(
  NotificationsNotifier.new,
);

/// Server-reported unread count (kept in sync when inbox loads / mark-read).
final notificationServerUnreadProvider =
    NotifierProvider<NotificationServerUnreadNotifier, int>(
  NotificationServerUnreadNotifier.new,
);

/// Badge count for app-level bell icons.
final notificationUnreadCountProvider = Provider<int>((ref) {
  final server = ref.watch(notificationServerUnreadProvider);
  final async = ref.watch(notificationsProvider);
  final fromList = async.maybeWhen(
    data: (items) => items.where((n) => !n.isRead).length,
    orElse: () => null,
  );
  // Prefer list when loaded (accurate after local mark-read); else server count.
  if (fromList != null && async.hasValue) return fromList;
  return server;
});

/// Ensures unread count is available for bells without a second parallel fetch.
/// Prefers the inbox response (already loaded by SessionBootstrap); only hits
/// `/unread-count` when the inbox is not yet available.
final notificationBadgeBootstrapProvider = FutureProvider<void>((ref) async {
  final token = await StorageService.getAuthToken();
  if (token == null || token.isEmpty) {
    ref.read(notificationServerUnreadProvider.notifier).set(0);
    return;
  }

  // If inbox already loaded (SessionBootstrap), unread is already set — done.
  final inbox = ref.read(notificationsProvider);
  if (inbox.hasValue) {
    final fromList = inbox.value!.where((n) => !n.isRead).length;
    ref.read(notificationServerUnreadProvider.notifier).set(fromList);
    return;
  }

  // Join in-flight inbox load instead of starting unread-count + invalidate.
  try {
    await ref.read(notificationsProvider.future);
  } catch (_) {
    final count = await InboxNotificationService.unreadCount();
    ref.read(notificationServerUnreadProvider.notifier).set(count);
  }
});

class NotificationServerUnreadNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void set(int value) => state = value < 0 ? 0 : value;

  void decrement([int by = 1]) {
    state = (state - by).clamp(0, 999999);
  }

  void clear() => state = 0;
}

class NotificationsNotifier
    extends AsyncNotifier<List<AppNotificationModel>> {
  @override
  Future<List<AppNotificationModel>> build() async {
    final token = await StorageService.getAuthToken();
    if (token == null || token.isEmpty) {
      ref.read(notificationServerUnreadProvider.notifier).clear();
      return const [];
    }
    try {
      final result = await InboxNotificationService.fetchInbox();
      ref
          .read(notificationServerUnreadProvider.notifier)
          .set(result.unreadCount);
      return result.items;
    } catch (_) {
      return const [];
    }
  }

  Future<void> refresh() async {
    final token = await StorageService.getAuthToken();
    if (token == null || token.isEmpty) {
      state = const AsyncData([]);
      ref.read(notificationServerUnreadProvider.notifier).clear();
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final result = await InboxNotificationService.fetchInbox();
      ref
          .read(notificationServerUnreadProvider.notifier)
          .set(result.unreadCount);
      return result.items;
    });
  }

  Future<void> markAsRead(String id) async {
    final current = state.value ?? const <AppNotificationModel>[];
    final wasUnread = current.any((n) => n.id == id && !n.isRead);
    state = AsyncData([
      for (final n in current)
        if (n.id == id) n.markAsRead() else n,
    ]);
    if (wasUnread) {
      ref.read(notificationServerUnreadProvider.notifier).decrement();
    }
    try {
      await InboxNotificationService.markAsRead(id);
    } catch (_) {
      await refresh();
    }
  }

  Future<void> markAllAsRead() async {
    final current = state.value ?? const <AppNotificationModel>[];
    state = AsyncData([
      for (final n in current) n.markAsRead(),
    ]);
    ref.read(notificationServerUnreadProvider.notifier).clear();
    try {
      await InboxNotificationService.markAllAsRead();
    } catch (_) {
      await refresh();
    }
  }

  Future<void> remove(String id) async {
    final current = state.value ?? const <AppNotificationModel>[];
    final wasUnread = current.any((n) => n.id == id && !n.isRead);
    state = AsyncData(current.where((n) => n.id != id).toList());
    if (wasUnread) {
      ref.read(notificationServerUnreadProvider.notifier).decrement();
    }
    try {
      await InboxNotificationService.delete(id);
    } catch (_) {
      await refresh();
    }
  }
}
