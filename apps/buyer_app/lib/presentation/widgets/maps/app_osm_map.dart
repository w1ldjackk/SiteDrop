// lib/presentation/widgets/maps/app_osm_map.dart
// OpenStreetMap map widget — FREE, no API key.
//
// API intentionally mirrors [AppGoogleMap] (legacy):
//   - [initialCameraPosition] instead of Google's CameraPosition → [AppCameraPosition]
//   - [onTap] gives an [AppMapPoint] instead of Google's LatLng
//   - [markers] is a set of [AppMapMarker] instead of Google Markers
//   - [controller] is an [AppMapController] with `moveTo(point, zoom)`
//     instead of GoogleMapController + CameraUpdate
//
// Tiles: https://tile.openstreetmap.org (see [OsmTiles] in sitedrop_core).
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sitedrop_core/sitedrop_core.dart';

/// Programmatic controller — mirrors the subset of GoogleMapController used
/// by address forms (`moveCamera` / `animateCamera` → [moveTo]).
/// Works with both OSM (flutter_map) and Google (google_maps_flutter) backends.
class AppMapController {
  fm.MapController? _inner;
  GoogleMapController? _google;

  // Last known camera (tracked manually since GoogleMapController has no
  // synchronous cameraPosition getter — only async getCameraPosition()).
  AppMapPoint? _lastCenter;
  double? _lastZoom;

  void attach(fm.MapController c) => _inner = c;

  /// Attach a Google Maps controller (used by [AppGoogleMap]).
  void attachGoogle(GoogleMapController c) => _google = c;

  void detach() {
    _inner = null;
    _google = null;
  }

  /// Move camera to [point] at [zoom].
  /// OSM: `MapController.move`. Google: `animateCamera(CameraUpdate.newLatLngZoom)`.
  void moveTo(AppMapPoint point, [double zoom = 16]) {
    _lastCenter = point;
    _lastZoom = zoom;
    if (_google != null) {
      _google!.animateCamera(
        CameraUpdate.newLatLngZoom(point.toGoogle(), zoom),
      );
      return;
    }
    _inner?.move(point.toOsm(), zoom);
  }

  /// Current camera (for SiteDrop-style +/- controls). Null before map ready.
  double? get currentZoom => _lastZoom;

  AppMapPoint? get currentCenter => _lastCenter;

  void zoomIn() {
    final c = _google;
    if (c != null) {
      final z = (_lastZoom ?? 16) + 1;
      try {
        c.animateCamera(
          CameraUpdate.newLatLngZoom(
            _lastCenter?.toGoogle() ?? const LatLng(5.6037, -0.1870),
            z.clamp(3.0, 19.0),
          ),
        );
      } catch (_) {}
      return;
    }
    final inner = _inner;
    if (inner == null) return;
    try {
      final cam = inner.camera;
      inner.move(cam.center, (cam.zoom + 1).clamp(3.0, 19.0));
    } catch (_) {}
  }

  void zoomOut() {
    final c = _google;
    if (c != null) {
      final z = (_lastZoom ?? 16) - 1;
      try {
        c.animateCamera(
          CameraUpdate.newLatLngZoom(
            _lastCenter?.toGoogle() ?? const LatLng(5.6037, -0.1870),
            z.clamp(3.0, 19.0),
          ),
        );
      } catch (_) {}
      return;
    }
    final inner = _inner;
    if (inner == null) return;
    try {
      final cam = inner.camera;
      inner.move(cam.center, (cam.zoom - 1).clamp(3.0, 19.0));
    } catch (_) {}
  }

  void dispose() => detach();
}

/// Drop-in OSM replacement for [AppGoogleMap]. No API key required.
class AppOsmMap extends StatefulWidget {
  const AppOsmMap({
    super.key,
    required this.initialCameraPosition,
    this.controller,
    this.onTap,
    this.markers = const {},
    this.interactive = true,
    this.onCameraChanged,
    this.hideAttribution = false,
    this.routePoints = const [],
  });

  final AppCameraPosition initialCameraPosition;

  /// Optional external controller. If null, an internal one is used.
  /// Mirrors Google's `onMapCreated(GoogleMapController)`.
  final AppMapController? controller;

  /// Mirrors Google's `onTap(LatLng)` — OSM tap gives [AppMapPoint].
  final ValueChanged<AppMapPoint>? onTap;

  /// Mirrors Google's `markers` — single delivery pin in address forms.
  final Set<AppMapMarker> markers;

  /// When false (e.g. while saving), taps are ignored.
  /// Mirrors passing `onTap: null` to GoogleMap.
  final bool interactive;

  /// SiteDrop/SiteDrop center-pin mode: fires on every camera move (pan/zoom).
  /// Use for "map moves under fixed pin → reverse geocode on idle".
  final void Function(AppMapPoint center, double zoom, bool hasGesture)?
      onCameraChanged;

  /// Hide attribution (only when parent renders its own attribution row).
  final bool hideAttribution;

  /// Route line (live tracker): breadcrumb trail driver → destination.
  /// Free OSM polyline, no API key.
  final List<AppMapPoint> routePoints;

  @override
  State<AppOsmMap> createState() => _AppOsmMapState();
}

class _AppOsmMapState extends State<AppOsmMap> {
  late final fm.MapController _mapController;
  late final AppMapController _effectiveController;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    _mapController = fm.MapController();
    _effectiveController = widget.controller ?? AppMapController();
    if (widget.controller == null) _ownsController = true;
    _effectiveController.attach(_mapController);
  }

  @override
  void didUpdateWidget(AppOsmMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.detach();
      final next = widget.controller ?? AppMapController();
      next.attach(_mapController);
    }
  }

  @override
  void dispose() {
    widget.controller?.detach();
    if (_ownsController) _effectiveController.detach();
    _mapController.dispose();
    super.dispose();
  }

  /// Tracker looks: destination = red pin, driver = SiteDrop vehicle badge.
  fm.Marker _marker(AppMapMarker m) {
    if (m.kind == AppMarkerKind.driver) {
      return fm.Marker(
        point: m.point.toOsm(),
        width: 46,
        height: 46,
        alignment: Alignment.center,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.30),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(
            Icons.local_shipping_outlined,
            size: 24,
            color: Colors.white,
            semanticLabel: 'Driver location',
          ),
        ),
      );
    }
    return fm.Marker(
      point: m.point.toOsm(),
      width: 44,
      height: 44,
      alignment: Alignment.topCenter,
      child: const Icon(
        Icons.location_pin,
        size: 40,
        color: Color(0xFFE11D48),
        semanticLabel: 'Delivery destination',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final center = widget.initialCameraPosition.target.toOsm();
    final zoom = widget.initialCameraPosition.zoom;

    return fm.FlutterMap(
      mapController: _mapController,
      options: fm.MapOptions(
        initialCenter: center,
        initialZoom: zoom,
        interactionOptions: widget.interactive
            ? const fm.InteractionOptions(
                flags: fm.InteractiveFlag.all,
              )
            : const fm.InteractionOptions(
                flags: fm.InteractiveFlag.none,
              ),
        onTap: widget.onTap == null
            ? null
            : (_, latLng) => widget.onTap!(AppMapPoint.fromOsm(latLng)),
        onPositionChanged: widget.onCameraChanged == null
            ? null
            : (camera, hasGesture) => widget.onCameraChanged!(
                  AppMapPoint.fromOsm(camera.center),
                  camera.zoom,
                  hasGesture,
                ),
      ),
      children: [
        fm.TileLayer(
          urlTemplate: OsmTiles.urlTemplate,
          userAgentPackageName: OsmTiles.userAgentPackageName,
        ),
        if (widget.routePoints.length >= 2)
          fm.PolylineLayer(
            polylines: [
              fm.Polyline(
                points: widget.routePoints.map((e) => e.toOsm()).toList(),
                color: AppColors.primary,
                strokeWidth: 4,
                borderColor: Colors.white,
                borderStrokeWidth: 1.5,
              ),
            ],
          ),
        if (widget.markers.isNotEmpty)
          fm.MarkerLayer(
            markers: widget.markers.map(_marker).toList(),
          ),
        if (!widget.hideAttribution)
          const fm.RichAttributionWidget(
            attributions: [
              fm.TextSourceAttribution(OsmTiles.attribution),
            ],
          ),
      ],
    );
  }
}
