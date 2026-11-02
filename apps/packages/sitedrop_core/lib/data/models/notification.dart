// lib/data/models/notification.dart
// Maps to Laravel App\Models\Notification
import 'package:flutter/material.dart';

import '../../app/theme/colors.dart';
import '../../core/constants/api_constants.dart';

/// Backend: Notification::TYPE_*
enum NotificationType {
  order,
  payment,
  delivery,
  system,
  promotion,
  site,
  truck,
  review,
}

/// Backend: Notification::CHANNEL_*
enum NotificationChannel {
  push,
  email,
  sms,
  inApp,
}

/// Backend: Notification::PRIORITY_*
enum NotificationPriority {
  high,
  normal,
  low,
}

/// Backend: Notification::DELIVERY_*
enum NotificationDeliveryStatus {
  pending,
  sent,
  delivered,
  failed,
}

/// Named AppNotificationModel to avoid clashing with Flutter's Notification.
class AppNotificationModel {
  final String id;
  final String? userId;
  final NotificationType type;
  final String title;
  final String body;
  final Map<String, dynamic>? data;
  final String? actionUrl;
  final String? imageUrl;
  final DateTime? readAt;
  final DateTime? sentAt;
  final NotificationDeliveryStatus deliveryStatus;
  final NotificationChannel channel;
  final NotificationPriority priority;
  final DateTime? expiresAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AppNotificationModel({
    required this.id,
    this.userId,
    required this.type,
    required this.title,
    required this.body,
    this.data,
    this.actionUrl,
    this.imageUrl,
    this.readAt,
    this.sentAt,
    this.deliveryStatus = NotificationDeliveryStatus.pending,
    this.channel = NotificationChannel.inApp,
    this.priority = NotificationPriority.normal,
    this.expiresAt,
    this.createdAt,
    this.updatedAt,
  });

  // ============================================================
  // PARSE HELPERS
  // ============================================================
  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  static Map<String, dynamic>? _parseMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  // ============================================================
  // FROM JSON
  // ============================================================
  factory AppNotificationModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> data = json;
    if (json['notification'] is Map<String, dynamic>) {
      data = json['notification'] as Map<String, dynamic>;
    }

    return AppNotificationModel(
      id: data['id']?.toString() ?? '',
      userId: data['user_id']?.toString(),
      type: NotificationTypeX.fromApi(data['type']?.toString()),
      title: data['title']?.toString() ?? '',
      body: data['body']?.toString() ?? data['message']?.toString() ?? '',
      data: _parseMap(data['data']),
      actionUrl: data['action_url']?.toString(),
      imageUrl: data['image_url']?.toString() == null ||
              data['image_url']?.toString().isEmpty == true
          ? data['image_url']?.toString()
          : ApiConstants.resolveAssetUrl(data['image_url']?.toString()),
      readAt: _parseDate(data['read_at']),
      sentAt: _parseDate(data['sent_at']),
      deliveryStatus: NotificationDeliveryStatusX.fromApi(
        data['delivery_status']?.toString(),
      ),
      channel: NotificationChannelX.fromApi(data['channel']?.toString()),
      priority: NotificationPriorityX.fromApi(data['priority']?.toString()),
      expiresAt: _parseDate(data['expires_at']),
      createdAt: _parseDate(data['created_at']),
      updatedAt: _parseDate(data['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'type': type.apiValue,
      'title': title,
      'body': body,
      'data': data,
      'action_url': actionUrl,
      'image_url': imageUrl,
      'read_at': readAt?.toIso8601String(),
      'sent_at': sentAt?.toIso8601String(),
      'delivery_status': deliveryStatus.apiValue,
      'channel': channel.apiValue,
      'priority': priority.apiValue,
      'expires_at': expiresAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  AppNotificationModel copyWith({
    String? id,
    String? userId,
    NotificationType? type,
    String? title,
    String? body,
    Map<String, dynamic>? data,
    String? actionUrl,
    String? imageUrl,
    DateTime? readAt,
    DateTime? sentAt,
    NotificationDeliveryStatus? deliveryStatus,
    NotificationChannel? channel,
    NotificationPriority? priority,
    DateTime? expiresAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppNotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      data: data ?? this.data,
      actionUrl: actionUrl ?? this.actionUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      readAt: readAt ?? this.readAt,
      sentAt: sentAt ?? this.sentAt,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      channel: channel ?? this.channel,
      priority: priority ?? this.priority,
      expiresAt: expiresAt ?? this.expiresAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // ============================================================
  // DOMAIN HELPERS (mirror backend accessors)
  // ============================================================
  bool get isRead => readAt != null;

  bool get isExpired {
    if (expiresAt == null) return false;
    return expiresAt!.isBefore(DateTime.now());
  }

  AppNotificationModel markAsRead() {
    return copyWith(readAt: DateTime.now());
  }
}

// ============================================================
// TYPE
// ============================================================
extension NotificationTypeX on NotificationType {
  String get apiValue {
    switch (this) {
      case NotificationType.order:
        return 'order';
      case NotificationType.payment:
        return 'payment';
      case NotificationType.delivery:
        return 'delivery';
      case NotificationType.system:
        return 'system';
      case NotificationType.promotion:
        return 'promotion';
      case NotificationType.site:
        return 'site';
      case NotificationType.truck:
        return 'truck';
      case NotificationType.review:
        return 'review';
    }
  }

  String get displayName {
    switch (this) {
      case NotificationType.order:
        return 'Order';
      case NotificationType.payment:
        return 'Payment';
      case NotificationType.delivery:
        return 'Delivery';
      case NotificationType.system:
        return 'System';
      case NotificationType.promotion:
        return 'Promotion';
      case NotificationType.site:
        return 'Site';
      case NotificationType.truck:
        return 'Truck';
      case NotificationType.review:
        return 'Review';
    }
  }

  IconData get icon {
    switch (this) {
      case NotificationType.order:
        return Icons.shopping_bag_outlined;
      case NotificationType.payment:
        return Icons.credit_card;
      case NotificationType.delivery:
        return Icons.local_shipping_outlined;
      case NotificationType.system:
        return Icons.settings_outlined;
      case NotificationType.promotion:
        return Icons.card_giftcard_outlined;
      case NotificationType.site:
        return Icons.construction_outlined;
      case NotificationType.truck:
        return Icons.airport_shuttle_outlined;
      case NotificationType.review:
        return Icons.star_outline;
    }
  }

  Color get color {
    switch (this) {
      case NotificationType.order:
        return AppColors.primary;
      case NotificationType.payment:
        return AppColors.success;
      case NotificationType.delivery:
        return Colors.blue;
      case NotificationType.system:
        return AppColors.grey600;
      case NotificationType.promotion:
        return Colors.orange;
      case NotificationType.site:
        return Colors.brown;
      case NotificationType.truck:
        return Colors.indigo;
      case NotificationType.review:
        return Colors.amber.shade700;
    }
  }

  static NotificationType fromApi(String? value) {
    switch (value?.toLowerCase().trim()) {
      case 'order':
        return NotificationType.order;
      case 'payment':
        return NotificationType.payment;
      case 'delivery':
        return NotificationType.delivery;
      case 'promotion':
      case 'promo':
        return NotificationType.promotion;
      case 'site':
        return NotificationType.site;
      case 'truck':
        return NotificationType.truck;
      case 'review':
        return NotificationType.review;
      case 'chat':
      case 'system':
      default:
        return NotificationType.system;
    }
  }
}

// ============================================================
// CHANNEL
// ============================================================
extension NotificationChannelX on NotificationChannel {
  String get apiValue {
    switch (this) {
      case NotificationChannel.push:
        return 'push';
      case NotificationChannel.email:
        return 'email';
      case NotificationChannel.sms:
        return 'sms';
      case NotificationChannel.inApp:
        return 'in_app';
    }
  }

  static NotificationChannel fromApi(String? value) {
    switch (value?.toLowerCase().trim()) {
      case 'push':
        return NotificationChannel.push;
      case 'email':
        return NotificationChannel.email;
      case 'sms':
        return NotificationChannel.sms;
      case 'in_app':
      default:
        return NotificationChannel.inApp;
    }
  }
}

// ============================================================
// PRIORITY
// ============================================================
extension NotificationPriorityX on NotificationPriority {
  String get apiValue {
    switch (this) {
      case NotificationPriority.high:
        return 'high';
      case NotificationPriority.normal:
        return 'normal';
      case NotificationPriority.low:
        return 'low';
    }
  }

  static NotificationPriority fromApi(String? value) {
    switch (value?.toLowerCase().trim()) {
      case 'high':
        return NotificationPriority.high;
      case 'low':
        return NotificationPriority.low;
      case 'normal':
      default:
        return NotificationPriority.normal;
    }
  }
}

// ============================================================
// DELIVERY STATUS
// ============================================================
extension NotificationDeliveryStatusX on NotificationDeliveryStatus {
  String get apiValue {
    switch (this) {
      case NotificationDeliveryStatus.pending:
        return 'pending';
      case NotificationDeliveryStatus.sent:
        return 'sent';
      case NotificationDeliveryStatus.delivered:
        return 'delivered';
      case NotificationDeliveryStatus.failed:
        return 'failed';
    }
  }

  static NotificationDeliveryStatus fromApi(String? value) {
    switch (value?.toLowerCase().trim()) {
      case 'sent':
        return NotificationDeliveryStatus.sent;
      case 'delivered':
        return NotificationDeliveryStatus.delivered;
      case 'failed':
        return NotificationDeliveryStatus.failed;
      case 'pending':
      default:
        return NotificationDeliveryStatus.pending;
    }
  }
}
