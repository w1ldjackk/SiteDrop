// Shared provider-neutral map types (OpenStreetMap-first, no API key).
//
// Google's `LatLng` is only a lat/lng data holder — it needs no API key by
// itself. The key is only needed to *render* Google tiles / call Google APIs.
// To stay vendor-neutral we define our own [AppMapPoint] and convert at the
// edges (Google legacy adapter / flutter_map OSM widget).

import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:latlong2/latlong.dart' as osm;

/// Vendor-neutral lat/lng point. Prefer this over `google_maps_flutter`
/// `LatLng` in new code — no API key required.
class AppMapPoint {
  final double latitude;
  final double longitude;

  const AppMapPoint(this.latitude, this.longitude);

  /// Accra CBD default (matches legacy buyer address form).
  static const accra = AppMapPoint(5.6037, -0.1870);

  // -- Converters: Google legacy ---------------------------------------
  factory AppMapPoint.fromGoogle(gmaps.LatLng p) =>
      AppMapPoint(p.latitude, p.longitude);

  gmaps.LatLng toGoogle() => gmaps.LatLng(latitude, longitude);

  // -- Converters: OSM (flutter_map / latlong2) -------------------------
  factory AppMapPoint.fromOsm(osm.LatLng p) =>
      AppMapPoint(p.latitude, p.longitude);

  osm.LatLng toOsm() => osm.LatLng(latitude, longitude);

  String get label =>
      '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';

  @override
  bool operator ==(Object other) =>
      other is AppMapPoint &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'AppMapPoint($latitude, $longitude)';
}

/// Vendor-neutral camera (mirrors `google_maps_flutter` CameraPosition).
class AppCameraPosition {
  final AppMapPoint target;
  final double zoom;

  const AppCameraPosition({required this.target, this.zoom = 12});

  factory AppCameraPosition.fromGoogle(gmaps.CameraPosition p) =>
      AppCameraPosition(
        target: AppMapPoint.fromGoogle(p.target),
        zoom: p.zoom,
      );

  gmaps.CameraPosition toGoogle() =>
      gmaps.CameraPosition(target: toGoogleTarget(), zoom: zoom);

  gmaps.LatLng toGoogleTarget() => target.toGoogle();
}

/// Vendor-neutral marker (mirrors the subset used by address forms).
class AppMapMarker {
  final String id;
  final AppMapPoint point;

  /// Tracker look: destination = red pin, driver = SiteDrop-style vehicle badge.
  final AppMarkerKind kind;

  const AppMapMarker({
    required this.id,
    required this.point,
    this.kind = AppMarkerKind.destination,
  });
}

/// Marker look for tracker maps. Address forms use the default.
enum AppMarkerKind { destination, driver }

/// Free OSM tile config — no API key. Keep in one place so all role apps
/// share attribution + tile URL.
abstract class OsmTiles {
  static const urlTemplate = 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// Package name sent as User-Agent (required by OSM tile usage policy).
  static const userAgentPackageName = 'com.sitedrop.app';

  static const attribution = '© OpenStreetMap contributors';
}

/// Which renderer to use. OSM is default (free, no key). Google is legacy.
enum MapProvider { osm, googleLegacy }
