// lib/data/models/trip.dart
// Maps to Laravel App\Models\TripLog for driver trip history.

class TripModel {
  final String id;
  final String? truckId;
  final String? driverId;
  final String? orderId;
  final String? deliveryId;
  final Map<String, dynamic>? startLocation;
  final Map<String, dynamic>? endLocation;
  final double? distanceKm;
  final int? durationMinutes;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final String status;
  final List<dynamic>? routePath;
  final List<dynamic>? waypoints;
  final double? averageSpeed;
  final double? maxSpeed;
  final String? notes;
  final DateTime? completedAt;

  const TripModel({
    required this.id,
    this.truckId,
    this.driverId,
    this.orderId,
    this.deliveryId,
    this.startLocation,
    this.endLocation,
    this.distanceKm,
    this.durationMinutes,
    this.startedAt,
    this.endedAt,
    required this.status,
    this.routePath,
    this.waypoints,
    this.averageSpeed,
    this.maxSpeed,
    this.notes,
    this.completedAt,
  });

  factory TripModel.fromJson(Map<String, dynamic> json) {
    return TripModel(
      id: '${json['id'] ?? ''}',
      truckId: json['truck_id']?.toString(),
      driverId: json['driver_id']?.toString(),
      orderId: json['order_id']?.toString(),
      deliveryId: json['delivery_id']?.toString(),
      startLocation: json['start_location'] is Map
          ? Map<String, dynamic>.from(json['start_location'] as Map)
          : null,
      endLocation: json['end_location'] is Map
          ? Map<String, dynamic>.from(json['end_location'] as Map)
          : null,
      distanceKm: _d(json['distance_km']),
      durationMinutes: int.tryParse('${json['duration_minutes'] ?? ''}'),
      startedAt: _dt(json['started_at']),
      endedAt: _dt(json['ended_at']),
      status: '${json['status'] ?? 'pending'}',
      routePath: json['route_path'] is List ? json['route_path'] as List : null,
      waypoints: json['waypoints'] is List ? json['waypoints'] as List : null,
      averageSpeed: _d(json['average_speed']),
      maxSpeed: _d(json['max_speed']),
      notes: json['notes']?.toString(),
      completedAt: _dt(json['completed_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'truck_id': truckId,
        'driver_id': driverId,
        'order_id': orderId,
        'delivery_id': deliveryId,
        'start_location': startLocation,
        'end_location': endLocation,
        'distance_km': distanceKm,
        'duration_minutes': durationMinutes,
        'started_at': startedAt?.toIso8601String(),
        'ended_at': endedAt?.toIso8601String(),
        'status': status,
        'route_path': routePath,
        'waypoints': waypoints,
        'average_speed': averageSpeed,
        'max_speed': maxSpeed,
        'notes': notes,
        'completed_at': completedAt?.toIso8601String(),
      };

  static DateTime? _dt(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }

  static double? _d(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}
