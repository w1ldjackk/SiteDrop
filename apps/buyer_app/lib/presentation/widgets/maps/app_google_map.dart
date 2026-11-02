// lib/presentation/widgets/maps/app_google_map.dart
// LEGACY (Google Maps backup — not used by default).
// OSM ([AppOsmMap] via [AppMap]) is the default: free, no API key.
// Keep this file as the Google fallback: re-enable by setting
// AppMap(provider: MapProvider.googleLegacy) + GOOGLE_MAPS_API_KEY.
// Safe GoogleMap wrapper — loads Maps JS on web before building the map.
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:sitedrop_core/app/theme/colors.dart';
import 'package:sitedrop_core/config/app_config.dart';
import '../../../core/maps/google_maps_js_loader.dart';
import 'package:sitedrop_core/core/utils/app_logger.dart';

/// Drop-in [GoogleMap] that does not crash on web when `google.maps` is missing.
class AppGoogleMap extends StatefulWidget {
  const AppGoogleMap({
    super.key,
    required this.initialCameraPosition,
    this.onMapCreated,
    this.onTap,
    this.markers = const <Marker>{},
    this.myLocationEnabled = false,
    this.myLocationButtonEnabled = false,
    this.zoomControlsEnabled = false,
    this.mapToolbarEnabled = false,
    this.compassEnabled = false,
    this.gestureRecognizers = const <Factory<OneSequenceGestureRecognizer>>{},
    this.mapType = MapType.normal,
  });

  final CameraPosition initialCameraPosition;
  final MapCreatedCallback? onMapCreated;
  final ArgumentCallback<LatLng>? onTap;
  final Set<Marker> markers;
  final bool myLocationEnabled;
  final bool myLocationButtonEnabled;
  final bool zoomControlsEnabled;
  final bool mapToolbarEnabled;
  final bool compassEnabled;
  final Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers;
  final MapType mapType;

  @override
  State<AppGoogleMap> createState() => _AppGoogleMapState();
}

class _AppGoogleMapState extends State<AppGoogleMap> {
  bool _loading = true;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _prepare();
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
      AppLogger.w('Google Maps web: no API key (publicConfig / GOOGLE_MAPS_API_KEY)');
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
      initialCameraPosition: widget.initialCameraPosition,
      onMapCreated: widget.onMapCreated,
      onTap: widget.onTap,
      markers: widget.markers,
      myLocationEnabled: widget.myLocationEnabled,
      myLocationButtonEnabled: widget.myLocationButtonEnabled,
      zoomControlsEnabled: widget.zoomControlsEnabled,
      mapToolbarEnabled: widget.mapToolbarEnabled,
      compassEnabled: widget.compassEnabled,
      gestureRecognizers: widget.gestureRecognizers,
      mapType: widget.mapType,
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
              Icon(Icons.map_outlined, size: 36, color: AppColors.primary.withValues(alpha: 0.7)),
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
                    ? 'Set GOOGLE_MAPS_API_KEY (Maps JavaScript API) in Laravel .env / public config, then hard-reload.'
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
