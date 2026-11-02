// lib/data/services/app_info_service.dart
import 'package:package_info_plus/package_info_plus.dart';

import '../../config/app_config.dart';

/// App version / package metadata via [package_info_plus].
class AppInfoService {
  AppInfoService._();

  static PackageInfo? _cached;

  static Future<PackageInfo> get info async {
    _cached ??= await PackageInfo.fromPlatform();
    return _cached!;
  }

  static Future<String> get versionLabel async {
    try {
      final p = await info;
      return '${p.version}+${p.buildNumber}';
    } catch (_) {
      return AppConfig.appVersion;
    }
  }

  static Future<String> get appName async {
    try {
      final p = await info;
      return p.appName.isNotEmpty ? p.appName : AppConfig.appName;
    } catch (_) {
      return AppConfig.appName;
    }
  }

  static Future<String> get packageName async {
    try {
      final p = await info;
      return p.packageName;
    } catch (_) {
      return AppConfig.appPackageName;
    }
  }
}
