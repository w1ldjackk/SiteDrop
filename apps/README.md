# SiteDrop Apps (`apps/`)

Flutter clients for SiteDrop. Backend (Api) is the sibling folder **`../backend`**.

## Layout

```text
sitedrop/
├── backend/                 # Laravel API + admin (Api)
└── apps/                    # this monorepo
    ├── packages/
    │   └── sitedrop_core/   # shared API client, models, theme, constants, widgets
    ├── buyer_app/           # buyer marketplace (store build)
    ├── seller_app/          # seller (store build)
    ├── driver_app/          # driver (store build)
    ├── Makefile
    └── README.md
```

| Folder | Role | Dart package (`pubspec.yaml`) |
| -------- | ------ | -------------------------------- |
| `buyer_app/` | Buyer marketplace (store) | `sitedrop_buyer` |
| `seller_app/` | Seller (store) | `sitedrop_seller` |
| `driver_app/` | Driver (store) | `sitedrop_driver` |
| `packages/sitedrop_core/` | Shared library | `sitedrop_core` |

**Store builds** are one app per role (`buyer_app` / `seller_app` / `driver_app`).

## Shared package

```yaml
# each app pubspec.yaml
dependencies:
  sitedrop_core:
    path: ../packages/sitedrop_core
```

Change API / models / theme / shared widgets **only** in `packages/sitedrop_core`, then `flutter pub get` in each app.

See [packages/sitedrop_core/README.md](./packages/sitedrop_core/README.md).

## Run (Chrome / desktop)

```powershell
# Api (separate terminal)
cd C:\xampp\htdocs\websites\project.local\sitedrop\backend
php artisan serve

# Buyer (store)
cd C:\xampp\htdocs\websites\project.local\sitedrop\apps\buyer_app
flutter pub get
flutter run -d chrome --dart-define=APP_ROLE=buyer --dart-define=API_BASE_URL=http://localhost:8000

# Seller
cd ..\seller_app
flutter run -d chrome --dart-define=APP_ROLE=seller --dart-define=API_BASE_URL=http://localhost:8000

# Driver
cd ..\driver_app
flutter run -d chrome --dart-define=APP_ROLE=driver --dart-define=BACKGROUND_LOCATION=true --dart-define=API_BASE_URL=http://localhost:8000
```

**Android emulator:** `API_BASE_URL=http://10.0.2.2:8000`  
(Web rewrites `10.0.2.2` → `localhost` automatically.)

### Make targets

```bash
cd sitedrop/apps
make run-buyer-dev
make run-seller-dev
make run-driver-dev
```

## App matrix

| App | Guest browse | Home after login |
| ----- | -------------- | ------------------ |
| **buyer** | Yes | `/home` shell |
| **seller** | No | `/seller/dashboard` shell |
| **driver** | No | `/driver/dashboard` shell |

## Docs

| File | Purpose |
| ------ | --------- |
| [packages/sitedrop_core/README.md](./packages/sitedrop_core/README.md) | Shared package |
| [../backend/docs/setup.md](../backend/docs/setup.md) | Backend + mobile setup |
| [../backend/docs/architecture.md](../backend/docs/architecture.md) | System architecture |
| [../backend/docs/api-overview.md](../backend/docs/api-overview.md) | REST API |
| [../README.md](../README.md) | SiteDrop monorepo overview |
