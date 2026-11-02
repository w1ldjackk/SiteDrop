// lib/presentation/providers/location_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:sitedrop_core/data/services/location_service.dart';
import 'service_providers.dart';

export 'service_providers.dart' show locationServiceProvider;

/// One-shot current position (null if permission denied / error).
final currentPositionProvider =
    FutureProvider.autoDispose<Position?>((ref) async {
  try {
    return await ref.watch(locationServiceProvider).getCurrentLocation();
  } catch (_) {
    return null;
  }
});

/// Current position as LatLng for map widgets.
final currentLatLngProvider = FutureProvider.autoDispose<LatLng?>((ref) async {
  try {
    return await ref.watch(locationServiceProvider).getCurrentLatLng();
  } catch (_) {
    return null;
  }
});

/// Whether device location services are enabled.
final locationEnabledProvider = FutureProvider.autoDispose<bool>((ref) {
  return ref.watch(locationServiceProvider).isLocationEnabled();
});

/// Detailed permission status for UI banners.
final locationPermissionProvider =
    FutureProvider.autoDispose<LocationPermissionResult>((ref) {
  return ref.watch(locationServiceProvider).checkPermissionStatus();
});
