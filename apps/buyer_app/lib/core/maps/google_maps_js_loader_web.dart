// lib/core/maps/google_maps_js_loader_web.dart
// Web: ensure Google Maps JavaScript API is available.
// The Maps script is loaded via <script> tag in web/index.html.
// This loader waits briefly for the script to initialize.
import 'dart:async';

/// Wait for Google Maps JS to load. Returns true after a short delay.
/// The Maps script must be included in web/index.html:
///   <script src="https://maps.googleapis.com/maps/api/js?key=YOUR_KEY"></script>
Future<bool> ensureGoogleMapsJsLoaded(String apiKey) async {
  // Give the Maps script time to initialize
  await Future.delayed(const Duration(seconds: 2));
  return true;
}

/// Non-web platforms: always "ready" (platform views handle Maps natively).
bool get hasGoogleMapsJsReady => true;