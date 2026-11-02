import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:sitedrop_core/sitedrop_core.dart';

import 'app/app.dart';
import 'core/maps/google_maps_js_loader.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  AppConfig.applyRoleFromDefines();
  if (AppConfig.role != AppFlavor.seller) {
    AppConfig.setFlavor(AppFlavor.seller);
  }

  await AppLogger.init();
  ApiService.ensureInitialized();
  await PublicConfigService.fetchAndApply();

  // OSM default: no Maps JS / API key needed (flutter_map + tile.openstreetmap.org).
  // Google legacy: bootstrap Maps JS on web when API key is present.
  if (kIsWeb && AppConfig.hasGoogleMapsApiKey) {
    await ensureGoogleMapsJsLoaded(AppConfig.googleMapsApiKey);
  }

  if (AppConfig.enableFirebase) {
    final app = await FirebaseEnv.ensureInitialized();
    if (app != null) await NotificationService.initialize();
  }

  await Hive.initFlutter();
  Hive.registerAdapter(ProductModelAdapter());
  Hive.registerAdapter(UserAdapter());
  await Hive.openBox<ProductModel>('products');
  await Hive.openBox(AppConstants.userBox);
  await Hive.openBox(AppConstants.settingsBox);

  AppLogger.i('🚀 ${AppConfig.appDisplayName} role=${AppConfig.roleName}');
  runApp(const ProviderScope(child: SiteDropApp()));
}
