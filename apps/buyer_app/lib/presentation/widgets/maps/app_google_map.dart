// lib/presentation/widgets/maps/app_google_map.dart
// Legacy Google Maps wrapper — mirrors [AppOsmMap] API exactly so [AppMap]
// can switch providers with zero call-site changes.
// Requires GOOGLE_MAPS_API_KEY + web Maps JS bootstrap in main.dart.

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:sitedrop_core/app/theme/colors.dart';
import 'package:sitedrop_core/config/app_config.dart';
import 'package:sitedrop_core/core/utils/app_logger.dart';
import 'package:sitedrop_core/maps/app_map_point.dart';

import '../../../core/maps/google_maps_js_loader.dart';
import 'app_osm_map.dart';

/// Legacy Google Maps replacement for [AppOsmMap]. Same props, same behavior.
/// No API key needed on mobile/desktop; web requires GOOGLE_MAPS_API_KEY.
class AppGoogleMap extends StatefulWidget {
  const AppGoogleMap({
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
  final AppMapController? controller;
  final ValueChanged<AppMapPoint>? onTap;
  final Set<AppMapMarker> markers;
  final bool interactive;
  final void Function(AppMapPoint center, double zoom, bool hasGesture)?
      onCameraChanged;
  final bool hideAttribution;
  final List<AppMapPoint> routePoints;

  @override
  State<AppGoogleMap> createState() => _AppGoogleMapState();
}

class _AppGoogleMapState extends State<AppGoogleMap> {
  GoogleMapController? _controller;
  bool _loading = true;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void didUpdateWidget(AppGoogleMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      widget.controller?.detach();
      if (_controller != null) {
        widget.controller?.attachGoogle(_controller!);
      }
    }
  }

  @override
  void dispose() {
    widget.controller?.detach();
    super.dispose();
  }

  Future<void> _prepare() async {
    // Mobile/desktop use platform views — no JS bootstrap.
    if (!kIsWeb) {
      if (mounted) {
        setState(() {
          _loading = false;
          _ready = true;
        });
      }
      return;
    }

    final key = AppConfig.googleMapsApiKey;
    if (key.isEmpty) {
      AppLogger.w('Google Maps web: no API key configured');
      if (mounted) {
        setState(() {
          _loading = false;
          _ready = false;
          _error = 'Maps API key not configured';
        });
      }
      return;
    }

    try {
      final ok = await ensureGoogleMapsJsLoaded(key);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _ready = ok;
        _error = ok ? null : 'Could not load Google Maps JavaScript API';
      });
      if (!ok) {
        AppLogger.w('Google Maps JS failed to load (check key + Maps JavaScript API)');
      }
    } catch (e) {
      AppLogger.e('Google Maps JS load error: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _ready = false;
        _error = e.toString();
      });
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _controller = controller;
    widget.controller?.attachGoogle(controller);

    if (mounted) {
      setState(() {
        _loading = false;
        _ready = true;
      });
    }
  }

  void _onCameraMove(CameraPosition position) {
    if (widget.onCameraChanged == null) return;
    widget.onCameraChanged!(
      AppMapPoint.fromGoogle(position.target),
      position.zoom,
      false,
    );
  }

  Marker _marker(AppMapMarker m) {
    final isDriver = m.kind == AppMarkerKind.driver;
    return Marker(
      markerId: MarkerId(m.id),
      position: m.point.toGoogle(),
      icon: isDriver
          ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure)
          : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      anchor: isDriver ? const Offset(0.5, 0.5) : const Offset(0.5, 1.0),
    );
  }

  Polyline _routePolyline() {
    if (widget.routePoints.length < 2) {
      return Polyline(
        polylineId: const PolylineId('empty'),
        points: const [],
      );
    }

    return Polyline(
      polylineId: const PolylineId('route'),
      points: widget.routePoints.map((p) => p.toGoogle()).toList(),
      color: AppColors.primary,
      width: 4,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ColoredBox(
        color: Color(0xFFE8EEF4),
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }

    if (!_ready) {
      return _MapsUnavailable(message: _error ?? 'Maps unavailable');
    }

    return GoogleMap(
      initialCameraPosition: widget.initialCameraPosition.toGoogle(),
      onMapCreated: _onMapCreated,
      onTap: widget.onTap == null || !widget.interactive
          ? null
          : (latLng) => widget.onTap!(AppMapPoint.fromGoogle(latLng)),
      onCameraMove: widget.onCameraChanged == null ? null : _onCameraMove,
      markers: widget.markers.map(_marker).toSet(),
      polylines: widget.routePoints.length >= 2 ? {_routePolyline()} : const {},
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
      gestureRecognizers: widget.interactive
          ? <Factory<OneSequenceGestureRecognizer>>{}
          : <Factory<OneSequenceGestureRecognizer>>{},
    );
  }
}

class _MapsUnavailable extends StatelessWidget {
  const _MapsUnavailable({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFE8EEF4),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.map_outlined, size: 36,
                  color: AppColors.primary.withValues(alpha: 0.7)),
              const SizedBox(height: 10),
              Text(
                'Map preview unavailable',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              Text(
                kIsWeb
                    ? 'Set GOOGLE_MAPS_API_KEY (Maps JavaScript API) then hard-reload.'
                    : 'Check Maps SDK configuration for this platform.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}