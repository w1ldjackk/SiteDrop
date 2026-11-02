// lib/core/maps/google_maps_js_loader.dart
// LEGACY (Google Maps backup — not used by default; OSM needs no JS key).
export 'google_maps_js_loader_stub.dart'
    if (dart.library.js_interop) 'google_maps_js_loader_web.dart';
