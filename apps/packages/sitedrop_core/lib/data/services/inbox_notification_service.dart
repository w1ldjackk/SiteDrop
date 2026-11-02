// lib/data/services/inbox_notification_service.dart
// In-app notification inbox (Laravel Notification model via API).
import '../../core/constants/api_constants.dart';
import '../../core/utils/app_logger.dart';
import '../models/notification.dart';
import 'api_service.dart';

class InboxNotificationService {
  InboxNotificationService._();

  /// GET /notifications
  static Future<({List<AppNotificationModel> items, int unreadCount})>
      fetchInbox({bool unreadOnly = false}) async {
    try {
      final response = await ApiService.get<Map<String, dynamic>>(
        ApiConstants.notifications,
        queryParams: {
          if (unreadOnly) 'unread_only': 1,
          'per_page': 50,
        },
      );

      final data = response['data'] as Map<String, dynamic>? ?? {};
      final raw = data['notifications'] as List<dynamic>? ??
          response['notifications'] as List<dynamic>? ??
          [];

      final items = <AppNotificationModel>[];
      for (final row in raw) {
        if (row is Map<String, dynamic>) {
          items.add(AppNotificationModel.fromJson(row));
        } else if (row is Map) {
          items.add(
            AppNotificationModel.fromJson(Map<String, dynamic>.from(row)),
          );
        }
      }

      final unread = data['unread_count'] is int
          ? data['unread_count'] as int
          : int.tryParse('${data['unread_count'] ?? items.where((n) => !n.isRead).length}') ??
              items.where((n) => !n.isRead).length;

      return (items: items, unreadCount: unread);
    } catch (e) {
      AppLogger.e('Error fetching notifications: $e');
      rethrow;
    }
  }

  static Future<int> unreadCount() async {
    try {
      final response = await ApiService.get<Map<String, dynamic>>(
        '${ApiConstants.notifications}/unread-count',
      );
      final data = response['data'] as Map<String, dynamic>? ?? {};
      return int.tryParse('${data['unread_count'] ?? 0}') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> markAsRead(String id) async {
    await ApiService.post<Map<String, dynamic>>(
      ApiConstants.notificationMarkRead.replaceAll('{id}', id),
      data: {},
    );
  }

  static Future<void> markAllAsRead() async {
    await ApiService.post<Map<String, dynamic>>(
      ApiConstants.notificationMarkAllRead,
      data: {},
    );
  }

  static Future<void> delete(String id) async {
    await ApiService.delete<Map<String, dynamic>>(
      '${ApiConstants.notifications}/$id',
    );
  }
}
