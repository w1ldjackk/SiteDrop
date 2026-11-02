// Web: load Maps JavaScript API so google_maps_flutter_web can read google.maps.
import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

@JS('google')
external JSAny? get _google;

@JS('_sitedropLoadGoogleMaps')
external JSPromise<JSAny?> _loadGoogleMapsJs(JSString apiKey);

bool get isGoogleMapsJsReady {
  try {
    final g = _google;
    if (g == null) return false;
    final maps = (g as JSObject).getProperty('maps'.toJS);
    return maps != null;
  } catch (_) {
    return false;
  }
}

Future<bool>? _inflight;

/// Inject / await Maps JS. Requires [apiKey] and `window._sitedropLoadGoogleMaps`
/// from `web/index.html` (falls back to script injection).
Future<bool> ensureGoogleMapsJsLoaded(String apiKey) async {
  final key = apiKey.trim();
  if (key.isEmpty) return false;
  if (isGoogleMapsJsReady) return true;

  if (_inflight != null) return _inflight!;

  _inflight = () async {
    try {
      await _loadGoogleMapsJs(key.toJS).toDart;
      for (var i = 0; i < 40; i++) {
        if (isGoogleMapsJsReady) return true;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      return isGoogleMapsJsReady;
    } catch (_) {
      return _injectScript(key);
    } finally {
      _inflight = null;
    }
  }();

  return _inflight!;
}

Future<bool> _injectScript(String apiKey) async {
  if (isGoogleMapsJsReady) return true;

  final existing = web.document.querySelector(
    'script[data-sitedrop-google-maps="1"]',
  );
  if (existing != null) {
    for (var i = 0; i < 40; i++) {
      if (isGoogleMapsJsReady) return true;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    return isGoogleMapsJsReady;
  }

  final completer = Completer<bool>();
  final script = web.HTMLScriptElement()
    ..src =
        'https://maps.googleapis.com/maps/api/js?key=${Uri.encodeQueryComponent(apiKey)}'
    ..async = true;
  script.setAttribute('data-sitedrop-google-maps', '1');

  script.onload = (web.Event _) {
    if (!completer.isCompleted) completer.complete(isGoogleMapsJsReady);
  }.toJS;

  script.onerror = (web.Event _) {
    if (!completer.isCompleted) completer.complete(false);
  }.toJS;

  web.document.head?.append(script);

  return completer.future.timeout(
    const Duration(seconds: 12),
    onTimeout: () => isGoogleMapsJsReady,
  );
}
