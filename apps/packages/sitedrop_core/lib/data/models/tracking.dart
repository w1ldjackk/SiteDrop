// lib/data/models/tracking.dart
// Live order tracking: timeline events + buyer-facing delivery snapshot.
// Maps to Laravel OrderTimeline + Delivery (buyer-scoped JSON).

import '../../core/utils/display_names.dart';
import '../../maps/app_map_point.dart';

/// One row of `GET /orders/{id}/timeline` (or `order.show → timeline`).
class OrderTimelineEvent {
  final String status;
  final String description;
  final DateTime? createdAt;
  final String? creatorName;

  const OrderTimelineEvent({
    required this.status,
    required this.description,
    this.createdAt,
    this.creatorName,
  });

  factory OrderTimelineEvent.fromJson(Map<String, dynamic> json) {
    final creator = json['creator'];
    String? creatorName;
    if (creator is Map) {
      creatorName = creator['name']?.toString();
    }
    final rawStatus = json['status']?.toString() ?? '';
    return OrderTimelineEvent(
      status: rawStatus,
      description: json['description']?.toString() ?? rawStatus,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      creatorName: creatorName,
    );
  }

  String get label {
    if (description.trim().isNotEmpty) return description;
    // Never leak raw snake_case to users.
    return DisplayNames.titleCase(status);
  }
}

/// Buyer-facing delivery snapshot for the live tracker.
/// Built from `GET /deliveries` (matched by order_id) — full Delivery JSON
/// with nested `driver` when assigned.
class TrackingDelivery {
  final String id;
  final String orderId;
  final String status;
  final String? trackingNumber;
  final String? driverName;
  final String? driverPhone;
  final String? driverAvatar;
  final String? vehicleLabel;
  final AppMapPoint? driverPoint;
  final DateTime? driverPointAt;
  final List<AppMapPoint> routePoints;
  final DateTime? estimatedArrival;
  final double? distanceKm;
  final int? estimatedDurationMinutes;

  const TrackingDelivery({
    required this.id,
    required this.orderId,
    required this.status,
    this.trackingNumber,
    this.driverName,
    this.driverPhone,
    this.driverAvatar,
    this.vehicleLabel,
    this.driverPoint,
    this.driverPointAt,
    this.routePoints = const [],
    this.estimatedArrival,
    this.distanceKm,
    this.estimatedDurationMinutes,
  });

  bool get hasDriver => driverName != null && driverName!.trim().isNotEmpty;
  bool get hasLivePoint => driverPoint != null;

  factory TrackingDelivery.fromJson(Map<String, dynamic> json) {
    // Nested driver (Delivery::with('driver')) — tolerant to shapes.
    String? driverName;
    String? driverPhone;
    String? driverAvatar;
    final driver = json['driver'];
    if (driver is Map) {
      driverName = driver['name']?.toString();
      driverPhone =
          driver['phone']?.toString() ?? driver['phone_number']?.toString();
      driverAvatar = driver['avatar']?.toString() ??
          driver['avatar_url']?.toString() ??
          driver['profile_photo']?.toString();
    }
    // Flat fallbacks (older payloads).
    driverName ??= json['driver_name']?.toString();
    driverPhone ??= json['driver_phone']?.toString();

    String? vehicleLabel;
    final vehicle = json['vehicle'];
    if (vehicle is Map) {
      final plate = vehicle['plate_number']?.toString() ??
          vehicle['license_plate']?.toString();
      final model = vehicle['model']?.toString() ??
          vehicle['vehicle_type']?.toString();
      vehicleLabel = [model, plate]
          .where((e) => e != null && e.trim().isNotEmpty)
          .join(' · ');
      if (vehicleLabel.trim().isEmpty) vehicleLabel = null;
    }

    AppMapPoint? driverPoint;
    DateTime? driverPointAt;
    final loc = json['current_location'];
    if (loc is Map) {
      final lat = _d(loc['lat'] ?? loc['latitude']);
      final lng = _d(loc['lng'] ?? loc['longitude'] ?? loc['lon']);
      if (lat != null && lng != null) {
        driverPoint = AppMapPoint(lat, lng);
        driverPointAt = DateTime.tryParse(loc['timestamp']?.toString() ?? '');
      }
    }

    final routePoints = <AppMapPoint>[];
    final route = json['route_path'];
    if (route is List) {
      for (final p in route) {
        if (p is! Map) continue;
        final lat = _d(p['lat'] ?? p['latitude']);
        final lng = _d(p['lng'] ?? p['longitude'] ?? p['lon']);
        if (lat != null && lng != null) routePoints.add(AppMapPoint(lat, lng));
      }
    }

    return TrackingDelivery(
      id: json['id']?.toString() ?? '',
      orderId: json['order_id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      trackingNumber: json['tracking_number']?.toString(),
      driverName: driverName,
      driverPhone: driverPhone,
      driverAvatar: driverAvatar,
      vehicleLabel: vehicleLabel,
      driverPoint: driverPoint,
      driverPointAt: driverPointAt,
      routePoints: routePoints,
      estimatedArrival: _dt(
        json['estimated_arrival'] ?? json['estimatedArrival'],
      ),
      distanceKm: _d(json['distance_km']),
      estimatedDurationMinutes: _i(
        json['estimated_duration'] ?? json['eta_minutes'],
      ),
    );
  }

  static DateTime? _dt(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }

  static double? _d(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static int? _i(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }
}

/// One SiteDrop-style trip request (`GET /deliveries/offers` item).
/// First-accept wins — the offer can expire or be taken meanwhile.
class DeliveryOfferModel {
  final String id;
  final String status;
  final DateTime? expiresAt;
  final int secondsLeft;
  final String deliveryId;
  final String trackingNumber;
  final String deliveryStatus;
  final double deliveryFee;
  final double? driverPayout;
  final double? distanceKm;  final String orderId;
  final String orderNumber;
  final String deliveryAddress;
  final AppMapPoint? destination;
  final double totalAmount;
  final int itemCount;

  const DeliveryOfferModel({
    required this.id,
    required this.status,
    this.expiresAt,
    this.secondsLeft = 0,
    required this.deliveryId,
    required this.trackingNumber,
    required this.deliveryStatus,
    required this.deliveryFee,
    this.driverPayout,
    this.distanceKm,
    required this.orderId,
    required this.orderNumber,
    required this.deliveryAddress,
    this.destination,
    required this.totalAmount,
    required this.itemCount,
  });

  factory DeliveryOfferModel.fromJson(Map<String, dynamic> json) {
    final delivery = json['delivery'] is Map
        ? Map<String, dynamic>.from(json['delivery'] as Map)
        : const <String, dynamic>{};
    final order = json['order'] is Map
        ? Map<String, dynamic>.from(json['order'] as Map)
        : const <String, dynamic>{};
    AppMapPoint? destination;
    final coords = order['delivery_coordinates'];
    if (coords is Map) {
      final lat = _d(coords['lat'] ?? coords['latitude']);
      final lng = _d(coords['lng'] ?? coords['longitude'] ?? coords['lon']);
      if (lat != null && lng != null) destination = AppMapPoint(lat, lng);
    }
    return DeliveryOfferModel(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'offered',
      expiresAt: DateTime.tryParse(json['expires_at']?.toString() ?? ''),
      secondsLeft:
          int.tryParse(json['seconds_left']?.toString() ?? '') ?? 0,
      deliveryId: delivery['id']?.toString() ?? '',
      trackingNumber: delivery['tracking_number']?.toString() ?? '',
      deliveryStatus: delivery['status']?.toString() ?? 'pending',
      deliveryFee: _d(delivery['delivery_fee']) ?? 0,
      driverPayout: _d(delivery['driver_payout']),
      distanceKm: _d(delivery['distance_km']),
      orderId: order['id']?.toString() ?? '',
      orderNumber: order['order_number']?.toString() ?? '',
      deliveryAddress: order['delivery_address']?.toString() ?? '',
      destination: destination,
      totalAmount: _d(order['total_amount']) ?? 0,
      itemCount: int.tryParse(order['item_count']?.toString() ?? '') ?? 0,
    );
  }

  static double? _d(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  /// What the driver earns for this trip (GHS). Prefers the server
  /// `driver_payout` (floored so free-delivery promos still pay);
  /// falls back to 70% of the fee for older payloads.
  double get effectivePayout => driverPayout ?? deliveryFee * 0.70;
}
