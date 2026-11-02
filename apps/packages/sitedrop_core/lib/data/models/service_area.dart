// lib/data/models/service_area.dart
// A seller coverage area: a pinned point + human label + delivery radius.
// Serializes to {lat, lng, label, radius_km} — the backend stores the array
// as-is so truck/delivery matching can use it for nearby queries.

import 'package:sitedrop_core/maps/app_map_point.dart';

class ServiceArea {
  final AppMapPoint point;
  final String label;
  final double radiusKm;

  const ServiceArea({
    required this.point,
    this.label = '',
    this.radiusKm = 25,
  });

  String get displayLabel =>
      label.isEmpty ? point.label : label;

  factory ServiceArea.fromJson(dynamic json) {
    if (json is Map) {
      final lat = _num(
        json['lat'] ?? json['latitude'],
      );
      final lng = _num(
        json['lng'] ?? json['longitude'] ?? json['lon'],
      );
      return ServiceArea(
        point: AppMapPoint(lat ?? 0, lng ?? 0),
        label: json['label']?.toString() ?? '',
        radiusKm: _num(json['radius_km'] ?? json['radius']) ?? 25,
      );
    }
    return const ServiceArea(point: AppMapPoint(0, 0));
  }

  Map<String, dynamic> toJson() => {
    'lat': point.latitude,
    'lng': point.longitude,
    if (label.isNotEmpty) 'label': label,
    'radius_km': radiusKm,
  };

  static double? _num(dynamic v) {
    if (v == null) {
      return null;
    }
    if (v is num) {
      return v.toDouble();
    }
    return double.tryParse(v.toString());
  }
}
