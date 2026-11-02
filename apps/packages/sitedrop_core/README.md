# sitedrop_core

Shared Flutter package for **SiteDrop** role apps under `sitedrop/apps/`.

## Contains

| Path | Purpose |
|------|---------|
| `lib/data/services/` | Dio `ApiService`, Auth, Cart, Order, FCM token registration, etc. |
| `lib/data/models/` | User, Product, Order, Address, Delivery, Trip, Notification, … |
| `lib/core/constants/` | `ApiConstants`, `AppConstants` |
| `lib/core/utils/` | logger, helpers, validators, toast, formatters |
| `lib/app/theme/` | palette, light/dark themes, input styles |
| `lib/app/routes/route_names.dart` | path **constants only** (no GoRouter) |
| `lib/config/` | `AppConfig`, `AppFlavor`, Firebase options helpers |

## Does **not** contain

- Role screens (`buyer/`, `seller/`, `driver/`)
- Riverpod providers (except what you add later carefully)
- `go_router` route trees / `MaterialApp`
- `AuthGate` (depends on app `authProvider`) — keep that in each app

## Use in an app

Each role app is a **sibling** of `packages/`:

```yaml
# apps/buyer_app/pubspec.yaml  (same for seller_app / driver_app)
dependencies:
  flutter:
    sdk: flutter
  sitedrop_core:
    path: ../packages/sitedrop_core
  flutter_riverpod: ^3.3.2
  go_router: ^17.3.0
```

```dart
import 'package:sitedrop_core/sitedrop_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.flavor = AppFlavor.buyer;
  ApiService.ensureInitialized();
  // …
}
```

## Package-ready rules

1. Prefer **relative imports inside** this package (`../models/user.dart`).
2. Apps must use **`package:sitedrop_core/...`** only.
3. No imports of `presentation/screens` or app `providers`.
4. Hive adapters (`user.g.dart`, `product.g.dart`) ship with the package; apps register them once at startup.
5. Assets stay in apps unless truly shared (`package: 'sitedrop_core'`).

## Analyze

```bash
cd sitedrop/apps/packages/sitedrop_core
flutter pub get
flutter analyze
```

More detail: [PACKAGE.md](./PACKAGE.md).
