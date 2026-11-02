import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:sitedrop_core/sitedrop_core.dart';

import 'app/app.dart';
// LEGACY (Google Maps backup — commented out for now).
// OSM (flutter_map) needs no JS bootstrap / API key, so this stays disabled.
// To re-enable Google, uncomment the import + block below and set
// GOOGLE_MAPS_API_KEY (dart-define) or Laravel public config.
// import 'core/maps/google_maps_js_loader.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  AppConfig.applyRoleFromDefines();
  if (AppConfig.role != AppFlavor.buyer) {
    AppConfig.setFlavor(AppFlavor.buyer);
  }

  await AppLogger.init();
  ApiService.ensureInitialized();
  AppLogger.i('🔗 API base: ${ApiConstants.baseUrl}');
  await PublicConfigService.fetchAndApply();

  // OSM default: no Maps JS / API key needed (flutter_map + tile.openstreetmap.org).
  // LEGACY (Google backup — commented out for now):
  // if (kIsWeb && AppConfig.hasGoogleMapsApiKey) {
  //   await ensureGoogleMapsJsLoaded(AppConfig.googleMapsApiKey);
  // }

  if (AppConfig.enableFirebase) {
    final app = await FirebaseEnv.ensureInitialized();
    if (app != null) await NotificationService.initialize();
  }

  await Hive.initFlutter();
  Hive.registerAdapter(ProductModelAdapter());
  Hive.registerAdapter(UserAdapter());
  await Hive.openBox<ProductModel>('products');
  await Hive.openBox(AppConstants.cartBox);
  await Hive.openBox(AppConstants.userBox);
  await Hive.openBox(AppConstants.settingsBox);

  AppLogger.i('🚀 ${AppConfig.appDisplayName} role=${AppConfig.roleName}');
  runApp(const ProviderScope(child: SiteDropApp()));
}
