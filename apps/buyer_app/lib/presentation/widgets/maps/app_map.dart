// lib/presentation/widgets/maps/app_map.dart
// Switch between OSM (default, free, no key) and Google legacy.
//
// Usage (same shape as the old AppGoogleMap call site):
// ```dart
// AppMap(
//   initialCameraPosition: AppCameraPosition(target: point, zoom: 16),
//   controller: _mapController,
//   onTap: (p) => _setPin(p),
//   markers: { if (hasPin) AppMapMarker(id: 'delivery_pin', point: pin) },
// )
// ```
//
// To re-enable Google, set [provider] to MapProvider.googleLegacy and
// uncomment the LEGACY block below (requires GOOGLE_MAPS_API_KEY).
import 'package:flutter/material.dart';
import 'package:sitedrop_core/sitedrop_core.dart';

import 'app_google_map.dart';
import 'app_osm_map.dart';

/// Default map for buyer_app. OSM-first; Google kept as legacy backup.
/// Set [provider] to MapProvider.googleLegacy to use Google Maps.
class AppMap extends StatelessWidget {
  const AppMap({
    super.key,
    required this.initialCameraPosition,
    this.controller,
    this.onTap,
    this.markers = const {},
    this.interactive = true,
    this.provider = MapProvider.osm,
    this.onCameraChanged,
    this.hideAttribution = false,
    this.routePoints = const [],
  });

  final AppCameraPosition initialCameraPosition;
  final AppMapController? controller;
  final ValueChanged<AppMapPoint>? onTap;
  final Set<AppMapMarker> markers;
  final bool interactive;
  final MapProvider provider;
  final void Function(AppMapPoint center, double zoom, bool hasGesture)?
      onCameraChanged;
  final bool hideAttribution;

  /// Route line for the live tracker (driver breadcrumb trail).
  final List<AppMapPoint> routePoints;

  @override
  Widget build(BuildContext context) {
    // OSM default — free, no API key.
    if (provider == MapProvider.osm) {
      return AppOsmMap(
        initialCameraPosition: initialCameraPosition,
        controller: controller,
        onTap: interactive ? onTap : null,
        markers: markers,
        interactive: interactive,
        onCameraChanged: onCameraChanged,
        hideAttribution: hideAttribution,
        routePoints: routePoints,
      );
    }

    // Google Maps legacy — requires GOOGLE_MAPS_API_KEY + web JS bootstrap.
    return AppGoogleMap(
      initialCameraPosition: initialCameraPosition,
      controller: controller,
      onTap: interactive ? onTap : null,
      markers: markers,
      interactive: interactive,
      onCameraChanged: onCameraChanged,
      hideAttribution: hideAttribution,
      routePoints: routePoints,
    );
  }
}
