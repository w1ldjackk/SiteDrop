// lib/core/maps/google_maps_js_loader.dart
// Platform-aware Google Maps JavaScript loader.
// On mobile/desktop this is a no-op (platform views don't need JS bootstrap).
// On web it loads the Maps JavaScript API so google_maps_flutter_web works.

export 'google_maps_js_loader_web.dart'
    if (dart.library.io) 'google_maps_js_loader_stub.dart';
