// lib/data/models/delivery.dart
// Maps to Laravel App\Models\Delivery for driver / order tracking clients.

import '../../core/constants/api_constants.dart';
import '../../maps/app_map_point.dart';

class DeliveryModel {
  final String id;
  final String orderId;
  final String? driverId;
  final String? trackingNumber;
  final String status;
  final Map<String, dynamic>? currentLocation;
  final DateTime? pickedUpAt;
  final DateTime? estimatedArrival;
  final DateTime? actualArrival;
  final String? deliveryNotes;
  final List<String> proofImages;
  final double? distanceKm;
  final int? estimatedDuration;
  final List<dynamic>? routePath;
  final double? deliveryFee;
  final double? driverPayout;
  final DateTime? assignedAt;
  final DateTime? acceptedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? vehicleId;
  final String? dispatchNotes;

  /// Nested driver (Delivery::with('driver')) — buyer tracker card.
  final String? driverName;
  final String? driverPhone;
  final String? driverAvatar;

  /// Vehicle label from nested `vehicle` (model · plate) when present.
  final String? vehicleLabel;

  /// Nested order snapshot (`with('order')`) — driver cards + call buyer.
  final String? orderNumber;
  final String? buyerName;
  final String? buyerPhone;
  final String? dropAddress;

  /// Buyer trip rating (`delivery_rating`) — driver profile average.
  final double? deliveryRating;
  final String? deliveryComment;

  /// Buyer destination from nested `order.delivery_coordinates`.
  final AppMapPoint? destination;

  const DeliveryModel({
    required this.id,
    required this.orderId,
    this.driverId,
    this.trackingNumber,
    required this.status,
    this.currentLocation,
    this.pickedUpAt,
    this.estimatedArrival,
    this.actualArrival,
    this.deliveryNotes,
    this.proofImages = const [],
    this.distanceKm,
    this.estimatedDuration,
    this.routePath,
    this.deliveryFee,
    this.driverPayout,
    this.assignedAt,
    this.acceptedAt,
    this.startedAt,
    this.completedAt,
    this.vehicleId,
    this.dispatchNotes,
    this.driverName,
    this.driverPhone,
    this.driverAvatar,
    this.vehicleLabel,
    this.orderNumber,
    this.buyerName,
    this.buyerPhone,
    this.dropAddress,
    this.deliveryRating,
    this.deliveryComment,
    this.destination,
  });

  factory DeliveryModel.fromJson(Map<String, dynamic> json) {
    final proofs = json['proof_images'];
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
    driverName ??= json['driver_name']?.toString();
    driverPhone ??= json['driver_phone']?.toString();
    String? vehicleLabel;
    final vehicle = json['vehicle'];
    if (vehicle is Map) {
      final plate = vehicle['plate_number']?.toString() ??
          vehicle['license_plate']?.toString();
      final model = vehicle['model']?.toString() ??
          vehicle['vehicle_type']?.toString();
      final label = [model, plate]
          .where((e) => e != null && e.trim().isNotEmpty)
          .join(' · ');
      if (label.trim().isNotEmpty) vehicleLabel = label;
    }
    String? orderNumber;
    String? buyerName;
    String? buyerPhone;
    String? dropAddress;
    AppMapPoint? destination;
    final order = json['order'];
    if (order is Map) {
      orderNumber = order['order_number']?.toString();
      dropAddress = order['delivery_address']?.toString();
      buyerPhone = order['delivery_phone']?.toString();
      final coords = order['delivery_coordinates'];
      if (coords is Map) {
        final lat = _d(coords['lat'] ?? coords['latitude']);
        final lng = _d(
            coords['lng'] ?? coords['longitude'] ?? coords['lon']);
        if (lat != null && lng != null) {
          destination = AppMapPoint(lat, lng);
        }
      }
      final buyer = order['buyer'];
      if (buyer is Map) {
        buyerName = buyer['name']?.toString();
        buyerPhone ??= buyer['phone']?.toString() ??
            buyer['phone_number']?.toString();
      }
    }
    return DeliveryModel(
      id: '${json['id'] ?? ''}',
      orderId: '${json['order_id'] ?? ''}',
      driverId: json['driver_id']?.toString(),
      trackingNumber: json['tracking_number']?.toString(),
      status: '${json['status'] ?? 'pending'}',
      currentLocation: json['current_location'] is Map
          ? Map<String, dynamic>.from(json['current_location'] as Map)
          : null,
      pickedUpAt: _dt(json['picked_up_at']),
      estimatedArrival: _dt(json['estimated_arrival']),
      actualArrival: _dt(json['actual_arrival']),
      deliveryNotes: json['delivery_notes']?.toString(),
      proofImages: proofs is List
          ? proofs
              .map((e) => ApiConstants.resolveAssetUrl(e.toString()))
              .toList()
          : const [],
      distanceKm: _d(json['distance_km']),
      estimatedDuration: int.tryParse('${json['estimated_duration'] ?? ''}'),
      routePath: json['route_path'] is List ? json['route_path'] as List : null,
      deliveryFee: _d(json['delivery_fee']),
      driverPayout: _d(json['driver_payout']),
      assignedAt: _dt(json['assigned_at']),
      acceptedAt: _dt(json['accepted_at']),
      startedAt: _dt(json['started_at']),
      completedAt: _dt(json['completed_at']),
      vehicleId: json['vehicle_id']?.toString(),
      dispatchNotes: json['dispatch_notes']?.toString(),
      driverName: driverName,
      driverPhone: driverPhone,
      driverAvatar: driverAvatar == null || driverAvatar.isEmpty
          ? driverAvatar
          : ApiConstants.resolveAssetUrl(driverAvatar),
      vehicleLabel: vehicleLabel,
      orderNumber: orderNumber,
      buyerName: buyerName,
      buyerPhone: buyerPhone,
      dropAddress: dropAddress,
      deliveryRating: _d(json['delivery_rating']),
      deliveryComment: json['delivery_comment']?.toString(),
      destination: destination,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'order_id': orderId,
        'driver_id': driverId,
        'tracking_number': trackingNumber,
        'status': status,
        'current_location': currentLocation,
        'picked_up_at': pickedUpAt?.toIso8601String(),
        'estimated_arrival': estimatedArrival?.toIso8601String(),
        'actual_arrival': actualArrival?.toIso8601String(),
        'delivery_notes': deliveryNotes,
        'proof_images': proofImages,
        'distance_km': distanceKm,
        'estimated_duration': estimatedDuration,
        'route_path': routePath,
        'delivery_fee': deliveryFee,
        'assigned_at': assignedAt?.toIso8601String(),
        'accepted_at': acceptedAt?.toIso8601String(),
        'started_at': startedAt?.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
        'vehicle_id': vehicleId,
        'dispatch_notes': dispatchNotes,
      };

  static DateTime? _dt(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }

  // ============================================================
  // TRACKER HELPERS (buyer live map)
  // ============================================================
  bool get hasDriver =>
      driverName != null && driverName!.trim().isNotEmpty;

  /// What the driver earns for this trip (GHS). Prefers the server
  /// `driver_payout` (floored so free-delivery promos still pay);
  /// falls back to 70% of the fee for older payloads.
  double get effectivePayout => driverPayout ?? (deliveryFee ?? 0) * 0.70;

  /// Live driver point from `current_location {lat, lng}` (free, no key).
  AppMapPoint? get driverPoint {
    final loc = currentLocation;
    if (loc == null) return null;
    final lat = _d(loc['lat'] ?? loc['latitude']);
    final lng = _d(loc['lng'] ?? loc['longitude'] ?? loc['lon']);
    if (lat == null || lng == null) return null;
    return AppMapPoint(lat, lng);
  }

  DateTime? get driverPointAt {
    final loc = currentLocation;
    if (loc == null) return null;
    return _dt(loc['timestamp']);
  }

  /// Breadcrumb trail (`route_path [{lat, lng}…]`) for the route line.
  List<AppMapPoint> get routePoints {
    final out = <AppMapPoint>[];
    for (final p in routePath ?? const []) {
      if (p is! Map) continue;
      final lat = _d(p['lat'] ?? p['latitude']);
      final lng = _d(p['lng'] ?? p['longitude'] ?? p['lon']);
      if (lat != null && lng != null) out.add(AppMapPoint(lat, lng));
    }
    return out;
  }

  static double? _d(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}
