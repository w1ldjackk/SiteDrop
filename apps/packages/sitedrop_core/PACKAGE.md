# sitedrop_core — structure & app integration

## 1. Folder structure

```
sitedrop/apps/packages/sitedrop_core/
├── pubspec.yaml
├── analysis_options.yaml
├── README.md
├── PACKAGE.md
└── lib/
    ├── sitedrop_core.dart              # public barrel
    ├── config/
    │   ├── app_config.dart
    │   ├── app_flavor.dart             # buyer | seller | driver
    │   ├── firebase_options.dart
    │   └── index.dart
    ├── app/
    │   ├── theme/
    │   │   ├── app_palette.dart
    │   │   ├── app_theme.dart
    │   │   ├── colors.dart
    │   │   └── input_styles.dart
    │   └── routes/
    │       └── route_names.dart        # constants only
    ├── core/
    │   ├── constants/
    │   │   ├── api_constants.dart
    │   │   └── app_constants.dart
    │   └── utils/
    │       ├── app_logger.dart
    │       ├── file_log_output.dart
    │       ├── formatters.dart
    │       ├── helpers.dart
    │       ├── image_picker_helper.dart
    │       ├── toast_service.dart
    │       ├── utils.dart
    │       └── validators.dart
    └── data/
        ├── models/
        │   ├── address.dart
        │   ├── cart_item.dart
        │   ├── delivery.dart
        │   ├── notification.dart
        │   ├── order.dart
        │   ├── payment.dart
        │   ├── product.dart (+ .g.dart)
        │   ├── review.dart
        │   ├── trip.dart
        │   ├── user.dart (+ .g.dart)
        │   └── models.dart
        └── services/
            ├── api_service.dart
            ├── auth_service.dart
            ├── cart_service.dart
            ├── … (all shared services)
            └── services.dart
```

## 2. Path dependency (each app)

```yaml
# apps/buyer_app/pubspec.yaml  (same for seller_app / driver_app)
name: sitedrop_buyer
publish_to: "none"
version: 1.0.0+1

environment:
  sdk: ^3.12.2

dependencies:
  flutter:
    sdk: flutter

  sitedrop_core:
    path: ../packages/sitedrop_core

  flutter_riverpod: ^3.3.2
  go_router: ^17.3.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0

flutter:
  uses-material-design: true
  assets:
    - assets/
```

| App folder | Path to core |
|------------|--------------|
| `apps/buyer_app` | `../packages/sitedrop_core` |
| `apps/seller_app` | `../packages/sitedrop_core` |
| `apps/driver_app` | `../packages/sitedrop_core` |

## 3. Package rules

| Rule | Why |
|------|-----|
| **No `auth_gate.dart`** | Depends on app `authProvider` + GoRouter |
| **No screens / providers / widgets** | Role-app owned |
| **No `go_router` in pubspec** | Core has route **names** only |
| **No `flutter_riverpod` in pubspec** | Providers stay in apps |
| **`AppFlavor`** | Role apps set `AppConfig.flavor` in `main` |
| Relative imports inside package | Standard for private packages |

### App wiring checklist

1. Keep `AuthGate` (or equivalent) **in each app** next to `auth_provider.dart`.
2. Session bootstrap / cart auto-load stays in app providers.
3. Register Hive adapters in app `main`.
4. Firebase: each store app may need its own `google-services.json`.

## 4. Example app usage

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sitedrop_core/sitedrop_core.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  AppConfig.flavor = AppFlavor.buyer;
  await AppLogger.init();
  ApiService.ensureInitialized();
  await PublicConfigService.fetchAndApply();

  runApp(const ProviderScope(child: BuyerApp()));
}
```

```dart
// navigation uses shared constants
context.go(RouteNames.home);
context.push(RouteNames.productDetailWithId(id));
```
