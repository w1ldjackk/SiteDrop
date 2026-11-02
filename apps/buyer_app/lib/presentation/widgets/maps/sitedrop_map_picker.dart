// lib/presentation/widgets/maps/sitedrop_map_picker.dart
// SiteDrop/SiteDrop-style location picker on free OpenStreetMap (no API key).
//
// UX (matches SiteDrop/SiteDrop):
//   - Map moves UNDER a fixed center pin (pan/zoom to position)
//   - Tap also places the pin (jumps camera there)
//   - Floating search bar with Nominatim autocomplete
//   - GPS recenter FAB + +/- zoom column (right side)
//   - Bottom address card: reverse-geocoded label + coords
//   - Respects OSM tile policy: 1 req/s debounce + attribution shown
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sitedrop_core/sitedrop_core.dart';

import 'app_map.dart';
import 'app_osm_map.dart';

/// SiteDrop/SiteDrop-style picker. Parent owns the picked point + GPS flow.
class SiteDropMapPicker extends StatefulWidget {
  const SiteDropMapPicker({
    super.key,
    required this.initialPoint,
    required this.controller,
    required this.locationService,
    this.enabled = true,
    this.locating = false,
    this.height = 380,
    this.onPick,
    this.onLocate,
    this.onExpand,
  });

  /// Starting camera target (Accra default when nothing picked yet).
  final AppMapPoint initialPoint;

  /// Shared controller (parent also uses it for GPS moves).
  final AppMapController controller;

  /// For reverse-geocode + autocomplete (free Nominatim, no key).
  final LocationService locationService;

  final bool enabled;
  final bool locating;

  /// Fixed height for inline form use. Null = expand to parent (fullscreen).
  final double? height;

  /// Fires (debounced on map idle) with the center-pin point.
  final ValueChanged<AppMapPoint>? onPick;

  /// GPS FAB pressed (parent runs permission + GPS, then moves controller).
  final VoidCallback? onLocate;

  /// Expand icon pressed → parent opens full-screen picker sheet.
  final VoidCallback? onExpand;

  @override
  State<SiteDropMapPicker> createState() => _SiteDropMapPickerState();
}
class _SiteDropMapPickerState extends State<SiteDropMapPicker> {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  List<PlaceSuggestion> _suggestions = [];
  bool _searching = false;
  bool _moving = false;
  String? _addressLabel;
  bool _resolving = false;
  AppMapPoint? _center;

  Timer? _searchDebounce;
  Timer? _idleDebounce;
  Timer? _moveReset;
  int _searchSeq = 0;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _idleDebounce?.cancel();
    _moveReset?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onCamera(AppMapPoint center, double zoom, bool hasGesture) {
    _center = center;
    if (hasGesture && widget.enabled) {
      setState(() => _moving = true);
      _moveReset?.cancel();
      _moveReset = Timer(const Duration(milliseconds: 400), () {
        if (mounted) setState(() => _moving = false);
      });
    }
    // Idle → pin settles → pick + reverse geocode (debounced 600ms,
    // respects Nominatim 1 req/s policy).
    _idleDebounce?.cancel();
    _idleDebounce = Timer(const Duration(milliseconds: 600), () {
      if (!mounted || !widget.enabled) return;
      widget.onPick?.call(center);
      _reverse(center);
    });
  }

  Future<void> _reverse(AppMapPoint p) async {
    if (_resolving) return;
    setState(() => _resolving = true);
    try {
      final label = await widget.locationService.getAddressFromMapPoint(p);
      if (mounted) setState(() => _addressLabel = label);
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  void _onSearchChanged(String v) {
    _searchDebounce?.cancel();
    if (v.trim().length < 3) {
      setState(() {
        _suggestions = [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _searchDebounce = Timer(const Duration(milliseconds: 450), () async {
      final seq = ++_searchSeq;
      final results =
          await widget.locationService.searchPlaces(v.trim(), limit: 5);
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _suggestions = results;
        _searching = false;
      });
    });
  }

  void _selectSuggestion(PlaceSuggestion s) {
    _searchFocus.unfocus();
    setState(() {
      _suggestions = [];
      _searchCtrl.text = s.title;
    });
    widget.controller.moveTo(s.point, 16);
    widget.onPick?.call(s.point);
    setState(() => _addressLabel = s.displayName);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barBg = isDark ? p.surface : Colors.white;
    final pinColor =
        _moving ? AppColors.primary : const Color(0xFFE11D48);

    return _PickerBox(
      height: widget.height,
      child: Stack(
          fit: StackFit.expand,
          children: [
            // ---- Map (moves under fixed pin) ----
            AppMap(
              initialCameraPosition: AppCameraPosition(
                target: widget.initialPoint,
                zoom: 14,
              ),
              controller: widget.controller,
              interactive: widget.enabled,
              hideAttribution: true,
              onTap: widget.enabled
                  ? (pos) {
                      widget.controller.moveTo(pos, 16);
                      widget.onPick?.call(pos);
                      _reverse(pos);
                    }
                  : null,
              onCameraChanged: _onCamera,
              markers: const {},
            ),

            // ---- Fixed center pin (SiteDrop style) ----
            IgnorePointer(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      transform: Matrix4.translationValues(
                        0,
                        _moving ? -10 : 0,
                        0,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.30),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.location_pin,
                          size: 46,
                          color: pinColor,
                          semanticLabel: 'Delivery location pin',
                        ),
                      ),
                    ),
                    Container(
                      width: 10,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ---- Top search bar ----
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Material(
                    elevation: 4,
                    shadowColor: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                    color: barBg,
                    child: TextField(
                      controller: _searchCtrl,
                      focusNode: _searchFocus,
                      enabled: widget.enabled,
                      textInputAction: TextInputAction.search,
                      onChanged: _onSearchChanged,
                      onSubmitted: (v) async {
                        final first = _suggestions.isNotEmpty
                            ? _suggestions.first
                            : null;
                        if (first != null) {
                          _selectSuggestion(first);
                        } else if (v.trim().isNotEmpty) {
                          final pt = await widget.locationService
                              .getMapPointFromAddress(v.trim());
                          if (pt != null && mounted) {
                            widget.controller.moveTo(pt, 16);
                            widget.onPick?.call(pt);
                          }
                        }
                      },
                      decoration: InputDecoration(
                        hintText: 'Search area, street, landmark…',
                        prefixIcon: const Icon(Icons.search, size: 22),
                        suffixIcon: _searching
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : _searchCtrl.text.isNotEmpty
                                ? IconButton(
                                    tooltip: 'Clear search',
                                    icon: const Icon(Icons.clear, size: 20),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      setState(() => _suggestions = []);
                                    },
                                  )
                                : widget.onExpand == null
                                    ? null
                                    : IconButton(
                                        tooltip: 'Full-screen map',
                                        icon: const Icon(
                                          Icons.fullscreen,
                                          size: 20,
                                        ),
                                        onPressed: widget.onExpand,
                                      ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 13,
                        ),
                      ),
                    ),
                  ),
                  // Autocomplete dropdown
                  if (_suggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      decoration: BoxDecoration(
                        color: barBg,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      constraints: const BoxConstraints(maxHeight: 190),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: _suggestions.length,
                          separatorBuilder: (_, _) =>
                              Divider(height: 1, color: p.divider),
                          itemBuilder: (context, i) {
                            final s = _suggestions[i];
                            return ListTile(
                              dense: true,
                              leading: Icon(
                                Icons.place_outlined,
                                color: AppColors.primary,
                                size: 20,
                              ),
                              title: Text(
                                s.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              subtitle: s.subtitle.isEmpty
                                  ? null
                                  : Text(
                                      s.subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                              onTap: () => _selectSuggestion(s),
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ---- Right controls: GPS + zoom (SiteDrop style) ----
            Positioned(
              right: 12,
              bottom: 108,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _RoundBtn(
                    tooltip: 'My location',
                    onPressed:
                        widget.enabled ? widget.onLocate : null,
                    child: widget.locating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location, size: 22),
                  ),
                  const SizedBox(height: 8),
                  _RoundBtn(
                    tooltip: 'Zoom in',
                    onPressed: widget.enabled
                        ? () => widget.controller.zoomIn()
                        : null,
                    child: const Icon(Icons.add, size: 22),
                  ),
                  const SizedBox(height: 8),
                  _RoundBtn(
                    tooltip: 'Zoom out',
                    onPressed: widget.enabled
                        ? () => widget.controller.zoomOut()
                        : null,
                    child: const Icon(Icons.remove, size: 22),
                  ),
                ],
              ),
            ),

            // ---- Bottom address card ----
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Material(
                elevation: 4,
                shadowColor: Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
                color: barBg,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _resolving
                            ? const Padding(
                                padding: EdgeInsets.all(10),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                _moving
                                    ? Icons.explore_outlined
                                    : Icons.place,
                                color: AppColors.primary,
                                size: 20,
                              ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _moving
                                  ? 'Moving pin…'
                                  : (_addressLabel ?? 'Drag map to set pin'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: p.textPrimary,
                              ),
                            ),
                            if (_center != null)
                              Text(
                                _center!.label,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: p.textMuted,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ---- OSM attribution (required, compact since built-in hidden) --
            Positioned(
              left: 8,
              bottom: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  OsmTiles.attribution,
                  style: TextStyle(fontSize: 9, color: Colors.black87),
                ),
              ),
            ),
          ],
        ),
    );
  }
}

/// Rounded box that is either fixed-height (inline form) or expanding
/// (fullscreen sheet) depending on [height].
class _PickerBox extends StatelessWidget {
  const _PickerBox({required this.child, this.height});

  final Widget child;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final box = ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: child,
    );
    if (height == null) return Expanded(child: box);
    return SizedBox(height: height, child: box);
  }
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({
    required this.tooltip,
    required this.child,
    this.onPressed,
  });

  final String tooltip;
  final Widget child;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      shape: const CircleBorder(),
      color: isDark ? p.surface : Colors.white,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: child,
        color: p.textPrimary,
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      ),
    );
  }
}
