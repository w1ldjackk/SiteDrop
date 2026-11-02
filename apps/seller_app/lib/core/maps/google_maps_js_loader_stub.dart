// Non-web: Maps SDK is native; JS loader is a no-op.
Future<bool> ensureGoogleMapsJsLoaded(String apiKey) async => true;

bool get isGoogleMapsJsReady => true;
