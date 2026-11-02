// lib/gen/assets.gen.dart
// Typed asset paths for SiteDrop. Keep in sync with pubspec.yaml `flutter.assets`.
//
// Usage:
//   import 'package:sitedrop_core/gen/assets.gen.dart';
//   SvgPicture.asset(Assets.icons.logo, width: 80, height: 80);
//
// Prefer these constants over hard-coded 'assets/…' strings.

/// Root entry for all bundled assets.
class Assets {
  Assets._();

  static const $AssetsIconsGen icons = $AssetsIconsGen();
  static const $AssetsImagesGen images = $AssetsImagesGen();
  static const $AssetsTranslationsGen translations = $AssetsTranslationsGen();
}

/// `assets/icons/`
class $AssetsIconsGen {
  const $AssetsIconsGen();

  /// App logo (SVG).
  String get logo => 'assets/icons/logo.svg';

  /// All known icon paths (useful for tests / pre-cache).
  List<String> get values => [logo];
}

/// `assets/images/`
class $AssetsImagesGen {
  const $AssetsImagesGen();

  /// Known image paths. Add entries as files are added under assets/images/.
  List<String> get values => const [];
}

/// `assets/translations/`
class $AssetsTranslationsGen {
  const $AssetsTranslationsGen();

  /// Known translation file paths. Add entries as locale files are added.
  List<String> get values => const [];
}
