// lib/presentation/widgets/maps/trip_route_map.dart
// Live trip routing (free OSM tiles + OSRM route, no API key):
// driver GPS dot follows in real time, route redraws on big moves.
// Navigate EXPANDS this same OSM map in-app (never leaves the app,
// never Google Maps) into a follow-me navigation mode with
// turn-by-turn directions from OSRM steps.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'package:sitedrop_core/app/theme/colors.dart';
import 'package:sitedrop_core/data/services/location_service.dart';
import 'package:sitedrop_core/maps/app_map_point.dart';
import '../../providers/service_providers.dart';

class TripRouteMap extends ConsumerStatefulWidget {
  final AppMapPoint destination;
  final String tripLabel;

  const TripRouteMap({
    super.key,
    required this.destination,
    required this.tripLabel,
  });

  @override
  ConsumerState<TripRouteMap> createState() => _TripRouteMapState();
}

class _TripRouteMapState extends ConsumerState<TripRouteMap> {
  final _mapController = fm.MapController();
  StreamSubscription<Position>? _gpsSub;
  AppMapPoint? _driver;
  List<AppMapPoint> _route = const [];
  List<RouteStep> _steps = const [];
  double? _distanceKm;
  double? _durationMin;
  AppMapPoint? _routedFrom;
  bool _fetchingRoute = false;
  bool _noGps = false;

  /// In-app navigation mode: same OSM map expands + follows GPS + directions.
  bool _navigating = false;
  bool _followMe = true;
  bool _showAllSteps = false;

  @override
  void initState() {
    super.initState();
    _startGps();
    _initFix();
  }

  /// One-shot fix so the route shows even before the driver moves.
  Future<void> _initFix() async {
    try {
      final pos =
          await ref.read(locationServiceProvider).getCurrentLocation();
      if (!mounted || _driver != null) return;
      final p = AppMapPoint(pos.latitude, pos.longitude);
      setState(() => _driver = p);
      await _maybeRoute(p, force: true);
    } catch (_) {
      if (mounted) setState(() => _noGps = true);
    }
  }

  @override
  void dispose() {
    _gpsSub?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  void _startGps() {
    try {
      final stream = ref
          .read(locationServiceProvider)
          .watchLocation(distanceFilterMeters: 15);
      _gpsSub = stream.listen(
        (pos) {
          if (!mounted) return;
          final p = AppMapPoint(pos.latitude, pos.longitude);
          setState(() => _driver = p);
          _maybeRoute(p);
          // Follow-me camera while navigating (same OSM map, stays in-app).
          if (_navigating && _followMe) {
            try {
              _mapController.move(p.toOsm(), 16);
            } catch (_) {}
          }
        },
        onError: (_) {
          if (mounted) setState(() => _noGps = true);
        },
        cancelOnError: false,
      );
    } catch (_) {
      if (mounted) setState(() => _noGps = true);
    }
  }

  Future<void> _maybeRoute(AppMapPoint from, {bool force = false}) async {
    if (_fetchingRoute) return;
    final last = _routedFrom;
    if (!force && last != null) {
      // Redraw only on significant moves (saves OSRM quota + battery).
      final moved = _haversineKm(last, from);
      if (moved < 0.25) return;
    }
    setState(() {
      _fetchingRoute = true;
      _routedFrom = from;
    });
    try {
      final result = await ref
          .read(locationServiceProvider)
          .fetchDetailedRoute(from, widget.destination);
      if (!mounted) return;
      setState(() {
        if (result != null) {
          _route = result.points;
          _distanceKm = result.distanceKm;
          _durationMin = result.durationMin;
          _steps = result.steps;
        }
        _fetchingRoute = false;
      });
    } catch (_) {
      if (mounted) setState(() => _fetchingRoute = false);
    }
  }

  double _haversineKm(AppMapPoint a, AppMapPoint b) {
    const r = 6371.0;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;
    final s1 = math.sin(dLat / 2);
    final s2 = math.sin(dLng / 2);
    final h = s1 * s1 +
        math.cos(a.latitude * math.pi / 180) *
            math.cos(b.latitude * math.pi / 180) *
            s2 *
            s2;
    return 2 * r * math.asin(math.sqrt(h.clamp(0.0, 1.0)));
  }

  /// Enter in-app navigation: expand the SAME OSM map, follow GPS,
  /// show turn-by-turn directions. No external app, no Google Maps.
  void _navigate() {
    setState(() {
      _navigating = true;
      _followMe = true;
      _showAllSteps = false;
    });
    final driver = _driver;
    if (driver != null) {
      try {
        _mapController.move(driver.toOsm(), 16);
      } catch (_) {}
      _maybeRoute(driver, force: true);
    }
  }

  void _exitNavigation() {
    setState(() {
      _navigating = false;
      _followMe = false;
    });
  }

  void _recenter() {
    final driver = _driver;
    if (driver == null) return;
    setState(() => _followMe = true);
    try {
      _mapController.move(driver.toOsm(), 16);
    } catch (_) {}
  }

  IconData _stepIcon(RouteStep s) {
    final t = s.maneuverType;
    final m = (s.modifier ?? '').toLowerCase();
    if (t == 'arrive') return Icons.flag_outlined;
    if (t == 'depart') return Icons.play_arrow_outlined;
    if (t.contains('roundabout') || t.contains('rotary')) {
      return Icons.rotate_right_outlined;
    }
    if (m.contains('uturn') || m.contains('u-turn')) {
      return Icons.u_turn_left;
    }
    if (m.contains('right')) return Icons.turn_right;
    if (m.contains('left')) return Icons.turn_left;
    if (t.contains('ramp') || t.contains('merge') || t.contains('fork')) {
      return Icons.merge;
    }
    return Icons.arrow_upward;
  }

  @override
  Widget build(BuildContext context) {
    final driver = _driver;
    final dest = widget.destination;
    final center = driver ?? dest;

    final meta = <String>[];
    if (_distanceKm != null) {
      meta.add('${_distanceKm!.toStringAsFixed(1)} km');
    }
    if (_durationMin != null) {
      final m = _durationMin!.round();
      meta.add(m >= 60 ? '${m ~/ 60}h ${m % 60}m' : '${m}min');
    }

    final nextInstruction = _steps.isNotEmpty ? _steps.first.instruction : null;
    final bannerText = _noGps
        ? 'Waiting for GPS…'
        : driver == null
            ? 'Locating you…'
            : _navigating && nextInstruction != null
                ? nextInstruction
                : meta.isEmpty
                    ? (_fetchingRoute ? 'Finding route…' : widget.tripLabel)
                    : meta.join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: _navigating ? 380 : 250,
            child: Stack(
              fit: StackFit.expand,
              children: [
                fm.FlutterMap(
                  mapController: _mapController,
                  options: fm.MapOptions(
                    initialCenter: center.toOsm(),
                    initialZoom: _navigating ? 16 : 14,
                  ),
                  children: [
                    fm.TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.sitedrop.app',
                    ),
                    if (_route.length >= 2)
                      fm.PolylineLayer(
                        polylines: [
                          fm.Polyline(
                            points:
                                _route.map((e) => e.toOsm()).toList(),
                            color: AppColors.primary,
                            strokeWidth: 4,
                            borderColor: Colors.white,
                            borderStrokeWidth: 1.5,
                          ),
                        ],
                      ),
                    fm.MarkerLayer(
                      markers: [
                        fm.Marker(
                          point: dest.toOsm(),
                          width: 44,
                          height: 44,
                          alignment: Alignment.topCenter,
                          child: const Icon(
                            Icons.location_pin,
                            size: 40,
                            color: Color(0xFFE11D48),
                            semanticLabel: 'Buyer dropoff',
                          ),
                        ),
                        if (driver != null)
                          fm.Marker(
                            point: driver.toOsm(),
                            width: 46,
                            height: 46,
                            alignment: Alignment.center,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primary,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black
                                        .withValues(alpha: 0.30),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.navigation_rounded,
                                size: 24,
                                color: Colors.white,
                                semanticLabel: 'Your live position',
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                // ---- Top banner: next instruction in nav mode ----
                Positioned(
                  top: 10,
                  left: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _navigating
                          ? AppColors.primary
                          : Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        if (_navigating)
                          const Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: Icon(
                              Icons.navigation_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            bannerText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _navigating
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // ---- Navigate / navigation controls (same OSM map) ----
                if (!_navigating)
                  Positioned(
                    right: 10,
                    bottom: 26,
                    child: FilledButton.icon(
                      onPressed: _navigate,
                      icon: const Icon(
                        Icons.navigation_outlined,
                        size: 18,
                      ),
                      label: const Text('Navigate'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(64, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  )
                else ...[
                  Positioned(
                    right: 10,
                    bottom: 26,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        FloatingActionButton.small(
                          heroTag: 'recenter_${widget.tripLabel}',
                          onPressed: _recenter,
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primary,
                          tooltip: _followMe
                              ? 'Following you'
                              : 'Re-center on me',
                          child: Icon(
                            _followMe
                                ? Icons.my_location
                                : Icons.location_searching_outlined,
                          ),
                        ),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: _exitNavigation,
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 18,
                          ),
                          label: const Text('Exit'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.black87,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(64, 44),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                Positioned(
                  left: 8,
                  bottom: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color:
                          Colors.white.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '© OpenStreetMap contributors',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // ---- In-app turn-by-turn directions (same OSM route) ----
        if (_navigating) ...[
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.25),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 8, 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.route_outlined,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _steps.isEmpty
                              ? 'Directions'
                              : 'Directions · ${_steps.length} steps'
                                  '${meta.isNotEmpty ? ' · ${meta.join(' · ')}' : ''}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (_steps.length > 4)
                        TextButton(
                          onPressed: () => setState(
                            () => _showAllSteps = !_showAllSteps,
                          ),
                          child: Text(
                            _showAllSteps ? 'Show less' : 'Show all',
                          ),
                        ),
                    ],
                  ),
                ),
                if (_fetchingRoute && _steps.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(14),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Loading turn-by-turn directions…',
                          style: TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  )
                else if (_steps.isEmpty)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Text(
                      'Follow the highlighted OSM route to the dropoff.',
                      style: TextStyle(fontSize: 13),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    itemCount: _showAllSteps
                        ? _steps.length
                        : math.min(4, _steps.length),
                    separatorBuilder: (_, sep) => const Divider(
                      height: 1,
                      indent: 48,
                    ),
                    itemBuilder: (context, i) {
                      final s = _steps[i];
                      final first = i == 0;
                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: first
                                ? AppColors.primary
                                : AppColors.primary
                                    .withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _stepIcon(s),
                            size: 20,
                            color: first
                                ? Colors.white
                                : AppColors.primary,
                          ),
                        ),
                        title: Text(
                          s.instruction,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                first ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                        trailing: Text(
                          s.distanceText,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            fontFeatures: [
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
