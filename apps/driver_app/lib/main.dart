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
  if (AppConfig.role != AppFlavor.driver) {
    AppConfig.setFlavor(AppFlavor.driver);
  }

  await AppLogger.init();
  ApiService.ensureInitialized();
  await PublicConfigService.fetchAndApply();

  if (kIsWeb && AppConfig.hasGoogleMapsApiKey) {
    await ensureGoogleMapsJsLoaded(AppConfig.googleMapsApiKey);
  }

  if (AppConfig.enableFirebase) {
    final app = await FirebaseEnv.ensureInitialized();
    if (app != null) await NotificationService.initialize();
  }

  await Hive.initFlutter();
  Hive.registerAdapter(UserAdapter());
  await Hive.openBox(AppConstants.userBox);
  await Hive.openBox(AppConstants.settingsBox);

  if (AppConfig.backgroundLocation || AppConfig.enablesDriverTracking) {
    AppLogger.i('Driver tracking enabled (BACKGROUND_LOCATION)');
  }

  AppLogger.i('🚀 ${AppConfig.appDisplayName} role=${AppConfig.roleName}');
  runApp(const ProviderScope(child: SiteDropApp()));
}
