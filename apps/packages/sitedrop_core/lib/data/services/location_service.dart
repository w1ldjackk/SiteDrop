// lib/data/services/location_service.dart
// GPS + geocoding. OSM-first (free, no API key); Google types kept as
// legacy data holders only.
import 'package:dio/dio.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import '../../config/app_config.dart';
import '../../maps/app_map_point.dart';

enum DistanceUnit {
  kilometers,
  miles,
  meters,
}

/// Location permission outcome for UI messaging.
enum LocationPermissionResult {
  granted,
  denied,
  deniedForever,
  serviceDisabled,
}

class LocationService {
  Position? _cachedPosition;
  DateTime? _cachedAt;
  final Duration cacheTtl;

  LocationService({this.cacheTtl = const Duration(seconds: 45)});

  Position? get lastKnownPosition => _cachedPosition;

  bool get hasFreshCache {
    if (_cachedPosition == null || _cachedAt == null) return false;
    return DateTime.now().difference(_cachedAt!) < cacheTtl;
  }

  void clearCache() {
    _cachedPosition = null;
    _cachedAt = null;
  }

  // ============================================================
  // PERMISSIONS
  // ============================================================

  Future<bool> isLocationEnabled() => Geolocator.isLocationServiceEnabled();

  Future<LocationPermissionResult> checkPermissionStatus() async {
    final enabled = await isLocationEnabled();
    if (!enabled) return LocationPermissionResult.serviceDisabled;

    final permission = await Geolocator.checkPermission();
    switch (permission) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return LocationPermissionResult.granted;
      case LocationPermission.deniedForever:
        return LocationPermissionResult.deniedForever;
      case LocationPermission.denied:
      case LocationPermission.unableToDetermine:
        return LocationPermissionResult.denied;
    }
  }

  /// Request permission. Returns whether access is usable.
  Future<bool> requestPermission() async {
    final result = await ensurePermission();
    return result == LocationPermissionResult.granted;
  }

  /// Full permission flow with distinct outcomes.
  Future<LocationPermissionResult> ensurePermission() async {
    final enabled = await isLocationEnabled();
    if (!enabled) {
      return LocationPermissionResult.serviceDisabled;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      final status = await ph.Permission.location.request();
      if (status.isGranted || status.isLimited) {
        return LocationPermissionResult.granted;
      }
      if (status.isPermanentlyDenied) {
        return LocationPermissionResult.deniedForever;
      }
      return LocationPermissionResult.denied;
    }

    if (permission == LocationPermission.deniedForever) {
      return LocationPermissionResult.deniedForever;
    }

    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      return LocationPermissionResult.granted;
    }

    return LocationPermissionResult.denied;
  }

  Future<void> openLocationSettings() => Geolocator.openLocationSettings();

  Future<void> openApplicationSettings() => ph.openAppSettings();

  // ============================================================
  // CURRENT LOCATION (with cache + GPS fallback)
  // ============================================================

  /// Returns current GPS, then last-known, then short-lived cache.
  Future<Position> getCurrentLocation({
    LocationAccuracy accuracy = LocationAccuracy.high,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && hasFreshCache) {
      return _cachedPosition!;
    }

    final permission = await ensurePermission();
    if (permission == LocationPermissionResult.serviceDisabled) {
      final fallback = await _fallbackPosition();
      if (fallback != null) return fallback;
      throw LocationException(
        'Location services are disabled. Enable GPS in settings.',
        result: permission,
      );
    }
    if (permission == LocationPermissionResult.deniedForever) {
      final fallback = await _fallbackPosition();
      if (fallback != null) return fallback;
      throw LocationException(
        'Location permission permanently denied. Open app settings to enable.',
        result: permission,
      );
    }
    if (permission != LocationPermissionResult.granted) {
      final fallback = await _fallbackPosition();
      if (fallback != null) return fallback;
      throw LocationException(
        'Location permission denied.',
        result: permission,
      );
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(accuracy: accuracy),
      );
      _storeCache(position);
      return position;
    } catch (e) {
      final fallback = await _fallbackPosition();
      if (fallback != null) return fallback;
      throw LocationException('Failed to get location: $e');
    }
  }

  Future<LatLng> getCurrentLatLng({bool forceRefresh = false}) async {
    final position = await getCurrentLocation(forceRefresh: forceRefresh);
    return LatLng(position.latitude, position.longitude);
  }

  /// OSM-first equivalent (free, no API key). Mirrors [getCurrentLatLng]
  /// but returns the provider-neutral [AppMapPoint].
  Future<AppMapPoint> getCurrentMapPoint({bool forceRefresh = false}) async {
    final position = await getCurrentLocation(forceRefresh: forceRefresh);
    return AppMapPoint(position.latitude, position.longitude);
  }

  Future<Position?> _fallbackPosition() async {
    if (hasFreshCache) return _cachedPosition;
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        _storeCache(last);
        return last;
      }
    } catch (_) {
      // Last-known position unavailable — fall back to cache/null.
    }
    return _cachedPosition;
  }

  void _storeCache(Position position) {
    _cachedPosition = position;
    _cachedAt = DateTime.now();
  }

  // ============================================================
  // DISTANCE
  // ============================================================

  double calculateDistance(
    LatLng start,
    LatLng end, {
    DistanceUnit unit = DistanceUnit.kilometers,
  }) {
    final meters = Geolocator.distanceBetween(
      start.latitude,
      start.longitude,
      end.latitude,
      end.longitude,
    );

    switch (unit) {
      case DistanceUnit.meters:
        return meters;
      case DistanceUnit.miles:
        return meters / 1609.34;
      case DistanceUnit.kilometers:
        return meters / 1000;
    }
  }

  Future<DistanceMatrixResult> getDistanceMatrix({
    required LatLng origin,
    required LatLng destination,
    String? apiKey,
  }) async {
    final key = apiKey ?? AppConfig.googleMapsApiKey;
    if (key.isEmpty) {
      final km = calculateDistance(origin, destination);
      return DistanceMatrixResult(
        status: 'FALLBACK',
        distanceMeters: (km * 1000).round(),
        distanceText: '${km.toStringAsFixed(1)} km',
      );
    }

    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

      final response = await dio.get<Map<String, dynamic>>(
        'https://maps.googleapis.com/maps/api/distancematrix/json',
        queryParameters: {
          'origins': '${origin.latitude},${origin.longitude}',
          'destinations':
              '${destination.latitude},${destination.longitude}',
          'key': key,
          'units': 'metric',
        },
      );

      return DistanceMatrixResult.fromGoogleJson(response.data ?? {});
    } catch (e) {
      // Soft fallback instead of hard fail
      final km = calculateDistance(origin, destination);
      return DistanceMatrixResult(
        status: 'FALLBACK_ERROR',
        distanceMeters: (km * 1000).round(),
        distanceText: '${km.toStringAsFixed(1)} km',
        durationText: null,
      );
    }
  }

  // ============================================================
  // ROUTING (free OSRM, no API key) — driver trip directions
  // ============================================================

  /// Driving route via public OSRM (no key). Returns polyline points +
  /// distance/duration, or null when unreachable. Throttle callers to
  /// significant moves (OSRM is a shared demo service).
  Future<
      ({
        List<AppMapPoint> points,
        double? distanceKm,
        double? durationMin,
      })?> fetchRoute(AppMapPoint from, AppMapPoint to) async {
    final detailed = await fetchDetailedRoute(from, to);
    if (detailed == null) return null;
    return (
      points: detailed.points,
      distanceKm: detailed.distanceKm,
      durationMin: detailed.durationMin,
    );
  }

  /// Driving route + turn-by-turn steps via public OSRM (no key, OSM-only).
  /// Used by the driver in-app navigator so directions never leave the app.
  Future<
      ({
        List<AppMapPoint> points,
        double? distanceKm,
        double? durationMin,
        List<RouteStep> steps,
      })?> fetchDetailedRoute(AppMapPoint from, AppMapPoint to) async {
    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 12),
          receiveTimeout: const Duration(seconds: 12),
          headers: {
            'User-Agent': OsmTiles.userAgentPackageName,
            'Accept': 'application/json',
          },
        ),
      );
      final response = await dio.get<Map<String, dynamic>>(
        'https://router.project-osrm.org/route/v1/driving/'
        '${from.longitude},${from.latitude};'
        '${to.longitude},${to.latitude}',
        queryParameters: {
          'overview': 'full',
          'geometries': 'geojson',
          'steps': 'true',
        },
      );
      final routes = response.data?['routes'];
      if (routes is! List || routes.isEmpty) return null;
      final first = routes.first;
      if (first is! Map) return null;
      final coords = first['geometry'] is Map
          ? (first['geometry'] as Map)['coordinates']
          : null;
      if (coords is! List) return null;
      final points = <AppMapPoint>[];
      for (final c in coords) {
        if (c is! List || c.length < 2) continue;
        final lng = (c[0] is num)
            ? (c[0] as num).toDouble()
            : double.tryParse('${c[0]}');
        final lat = (c[1] is num)
            ? (c[1] as num).toDouble()
            : double.tryParse('${c[1]}');
        if (lat != null && lng != null) points.add(AppMapPoint(lat, lng));
      }
      if (points.isEmpty) return null;
      final distM = first['distance'];
      final durS = first['duration'];
      return (
        points: points,
        distanceKm:
            distM is num ? distM.toDouble() / 1000 : null,
        durationMin:
            durS is num ? durS.toDouble() / 60 : null,
        steps: _parseOsrmSteps(first['legs']),
      );
    } catch (_) {
      return null;
    }
  }

  /// Flatten OSRM legs → ordered human-readable [RouteStep]s.
  List<RouteStep> _parseOsrmSteps(Object? legs) {
    final out = <RouteStep>[];
    if (legs is! List) return out;
    for (final leg in legs) {
      if (leg is! Map) continue;
      final steps = leg['steps'];
      if (steps is! List) continue;
      for (final s in steps) {
        if (s is! Map) continue;
        final maneuver = s['maneuver'];
        final type = maneuver is Map
            ? (maneuver['type']?.toString() ?? '')
            : '';
        final modifier = maneuver is Map
            ? maneuver['modifier']?.toString()
            : null;
        final name = (s['name']?.toString() ?? '').trim();
        final ref = (s['ref']?.toString() ?? '').trim();
        final road = ref.isNotEmpty
            ? (name.isNotEmpty ? '$name ($ref)' : ref)
            : name;
        final dist = s['distance'];
        final dur = s['duration'];
        final instruction = _stepInstruction(type, modifier, road);
        if (instruction.isEmpty) continue;
        out.add(
          RouteStep(
            instruction: instruction,
            distanceM: dist is num ? dist.toDouble() : 0,
            durationS: dur is num ? dur.toDouble() : 0,
            maneuverType: type,
            modifier: modifier,
            roadName: road,
          ),
        );
      }
    }
    return out;
  }

  /// Compose "Turn left onto Oxford St" style text from OSRM type/modifier.
  String _stepInstruction(String type, String? modifier, String road) {
    final mod = _modifierText(modifier);
    final on = road.isNotEmpty ? ' onto $road' : '';
    final onRoad = road.isNotEmpty ? ' on $road' : '';
    switch (type) {
      case 'arrive':
        return road.isNotEmpty
            ? 'Arrive at destination$onRoad'
            : 'Arrive at destination';
      case 'depart':
        return road.isNotEmpty
            ? 'Head out$onRoad'
            : (mod.isNotEmpty ? 'Head $mod' : 'Start trip');
      case 'roundabout':
      case 'rotary':
      case 'exit roundabout':
      case 'exit rotary':
        return road.isNotEmpty
            ? 'At the roundabout, take the exit$on'
            : 'At the roundabout, take the exit';
      case 'turn':
        return mod.isNotEmpty ? 'Turn $mod$on' : 'Turn$on';
      case 'continue':
      case 'new name':
        if (mod.isNotEmpty && mod != 'straight') {
          return 'Continue $mod$onRoad';
        }
        return road.isNotEmpty
            ? 'Continue straight$onRoad'
            : 'Continue straight';
      case 'merge':
        return 'Merge$on';
      case 'fork':
        return mod.isNotEmpty
            ? 'Keep $mod$on'
            : 'Fork$on';
      case 'on ramp':
        return 'Take the ramp$on';
      case 'off ramp':
        return 'Take the exit$on';
      case 'end of road':
        return mod.isNotEmpty ? 'Turn $mod$on' : 'Turn$on';
      case 'notification':
        return road.isNotEmpty
            ? 'Continue$onRoad'
            : 'Continue';
      default:
        if (type.isEmpty) return '';
        final label = type.replaceAll('_', ' ');
        final cap = label.isNotEmpty
            ? '${label[0].toUpperCase()}${label.substring(1)}'
            : label;
        return mod.isNotEmpty
            ? '$cap $mod$onRoad'
            : '$cap$onRoad';
    }
  }

  String _modifierText(String? modifier) {
    switch (modifier) {
      case 'uturn':
        return 'around (U-turn)';
      case 'sharp right':
        return 'sharp right';
      case 'right':
        return 'right';
      case 'slight right':
        return 'slight right';
      case 'straight':
        return 'straight';
      case 'slight left':
        return 'slight left';
      case 'left':
        return 'left';
      case 'sharp left':
        return 'sharp left';
      default:
        return modifier ?? '';
    }
  }

  // ============================================================
  // STREAM
  // ============================================================

  Stream<Position> watchLocation({
    int distanceFilterMeters = 10,
    LocationAccuracy accuracy = LocationAccuracy.high,
  }) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilterMeters,
      ),
    ).map((position) {
      _storeCache(position);
      return position;
    });
  }

  // ============================================================
  // GEOCODING (OSM-first: platform → free Nominatim, no API key)
  // ============================================================

  /// Reverse geocode via platform first, then free OSM Nominatim.
  /// [position] accepts legacy Google LatLng (data holder only, no key).
  Future<String> getAddressFromCoordinates(LatLng position) {
    return getAddressFromMapPoint(AppMapPoint.fromGoogle(position));
  }

  /// OSM-first reverse geocode (free, no API key).
  Future<String> getAddressFromMapPoint(AppMapPoint point) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        point.latitude,
        point.longitude,
      );
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final parts = [
          place.street,
          place.subLocality,
          place.locality,
          place.subAdministrativeArea,
          place.administrativeArea,
          place.country,
        ].whereType<String>().where((p) => p.trim().isNotEmpty).toList();

        if (parts.isNotEmpty) return parts.join(', ');
      }
    } catch (_) {
      // Platform geocoding unavailable (e.g. web) — try Nominatim below.
    }
    final nominatim = await _nominatimReverse(point);
    if (nominatim != null && nominatim.trim().isNotEmpty) return nominatim;
    return 'Unknown location';
  }

  Future<LatLng?> getCoordinatesFromAddress(String address) async {
    final point = await getMapPointFromAddress(address);
    return point?.toGoogle();
  }

  /// OSM-first forward geocode (free, no API key): platform → Nominatim.
  Future<AppMapPoint?> getMapPointFromAddress(String address) async {
    final query = address.trim();
    if (query.isEmpty) return null;
    try {
      final locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        final loc = locations.first;
        return AppMapPoint(loc.latitude, loc.longitude);
      }
    } catch (_) {
      // Platform geocoding unavailable — try Nominatim below.
    }
    return _nominatimSearch(query);
  }

  // -- Free OSM Nominatim (no API key) ---------------------------------
  // Usage policy: single request at a time from address forms, short
  // timeouts, proper User-Agent via OsmTiles.userAgentPackageName.

  Dio _nominatimClient() => Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          headers: {
            'User-Agent': OsmTiles.userAgentPackageName,
            'Accept': 'application/json',
          },
        ),
      );

  Future<String?> _nominatimReverse(AppMapPoint point) async {
    try {
      final response = await _nominatimClient().get<Map<String, dynamic>>(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {
          'lat': point.latitude,
          'lon': point.longitude,
          'format': 'jsonv2',
        },
      );
      final data = response.data;
      if (data == null) return null;
      final display = data['display_name']?.toString();
      if (display != null && display.trim().isNotEmpty) return display;
      final addr = data['address'];
      if (addr is Map) {
        final parts = [
          addr['road'],
          addr['suburb'],
          addr['city'] ?? addr['town'] ?? addr['village'],
          addr['state'],
          addr['country'],
        ].whereType<Object>().map((e) => e.toString()).where(
              (p) => p.trim().isNotEmpty,
            );
        if (parts.isNotEmpty) return parts.join(', ');
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<AppMapPoint?> _nominatimSearch(String query) async {
    final results = await searchPlaces(query, limit: 1);
    if (results.isEmpty) return null;
    return results.first.point;
  }

  /// Free OSM place autocomplete for search bars (no API key).
  /// Ghana-biased first, then global fallback — Bolt/Uber-style UX.
  Future<List<PlaceSuggestion>> searchPlaces(
    String query, {
    int limit = 5,
  }) async {
    final q = query.trim();
    if (q.length < 3) return const [];
    // Ghana bias: Accra viewbox (lon/lat) — keeps results local first.
    Future<List<PlaceSuggestion>> run({bool ghOnly = true}) async {
      final response = await _nominatimClient().get<List<dynamic>>(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'q': q,
          'format': 'jsonv2',
          'addressdetails': 1,
          'limit': limit.clamp(1, 10),
          if (ghOnly) ...{
            'countrycodes': 'gh',
            'viewbox': '-3.3,11.2,1.5,4.6',
            'bounded': 0,
          },
        },
      );
      final data = response.data ?? [];
      final out = <PlaceSuggestion>[];
      for (final item in data) {
        if (item is! Map) continue;
        final lat = double.tryParse(item['lat']?.toString() ?? '');
        final lon = double.tryParse(item['lon']?.toString() ?? '');
        final name = item['display_name']?.toString() ?? '';
        if (lat == null || lon == null || name.trim().isEmpty) continue;
        out.add(
          PlaceSuggestion(
            displayName: name,
            point: AppMapPoint(lat, lon),
          ),
        );
      }
      return out;
    }

    try {
      final gh = await run(ghOnly: true);
      if (gh.isNotEmpty) return gh;
      return await run(ghOnly: false);
    } catch (_) {
      return const [];
    }
  }
}

/// One turn-by-turn maneuver from OSRM (in-app navigation, OSM-only).
class RouteStep {
  final String instruction;
  final double distanceM;
  final double durationS;
  final String maneuverType;
  final String? modifier;
  final String roadName;

  const RouteStep({
    required this.instruction,
    required this.distanceM,
    required this.durationS,
    required this.maneuverType,
    this.modifier,
    this.roadName = '',
  });

  String get distanceText {
    if (distanceM < 1000) return '${distanceM.round()} m';
    return '${(distanceM / 1000).toStringAsFixed(1)} km';
  }
}

/// Free-text place result (Nominatim) for Uber/Bolt-style search bars.
class PlaceSuggestion {  final String displayName;
  final AppMapPoint point;

  const PlaceSuggestion({required this.displayName, required this.point});

  /// Short title (first segment) + remainder as subtitle — Bolt style.
  String get title {
    final parts = displayName.split(',');
    return parts.first.trim();
  }

  String get subtitle {
    final parts = displayName.split(',');
    if (parts.length < 2) return '';
    return parts.skip(1).join(',').trim();
  }
}

class LocationException implements Exception {
  final String message;
  final LocationPermissionResult? result;

  const LocationException(this.message, {this.result});

  String get userMessage => message;

  @override
  String toString() => message;
}

class DistanceMatrixResult {
  final String status;
  final List<String> originAddresses;
  final List<String> destinationAddresses;
  final int? distanceMeters;
  final int? durationSeconds;
  final String? distanceText;
  final String? durationText;

  const DistanceMatrixResult({
    required this.status,
    this.originAddresses = const [],
    this.destinationAddresses = const [],
    this.distanceMeters,
    this.durationSeconds,
    this.distanceText,
    this.durationText,
  });

  factory DistanceMatrixResult.fromGoogleJson(Map<String, dynamic> json) {
    final status = json['status']?.toString() ?? 'UNKNOWN';
    final origins = (json['origin_addresses'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];
    final destinations = (json['destination_addresses'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];

    int? distanceMeters;
    int? durationSeconds;
    String? distanceText;
    String? durationText;

    final rows = json['rows'] as List<dynamic>? ?? [];
    if (rows.isNotEmpty && rows.first is Map) {
      final elements =
          (rows.first as Map)['elements'] as List<dynamic>? ?? [];
      if (elements.isNotEmpty && elements.first is Map) {
        final el = Map<String, dynamic>.from(elements.first as Map);
        final dist = el['distance'] as Map<String, dynamic>?;
        final dur = el['duration'] as Map<String, dynamic>?;
        distanceMeters = dist?['value'] is int
            ? dist!['value'] as int
            : int.tryParse(dist?['value']?.toString() ?? '');
        durationSeconds = dur?['value'] is int
            ? dur!['value'] as int
            : int.tryParse(dur?['value']?.toString() ?? '');
        distanceText = dist?['text']?.toString();
        durationText = dur?['text']?.toString();
      }
    }

    return DistanceMatrixResult(
      status: status,
      originAddresses: origins,
      destinationAddresses: destinations,
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
      distanceText: distanceText,
      durationText: durationText,
    );
  }

  double? get distanceInKilometers =>
      distanceMeters != null ? distanceMeters! / 1000.0 : null;

  Duration? get duration =>
      durationSeconds != null ? Duration(seconds: durationSeconds!) : null;
}
