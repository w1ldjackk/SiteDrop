# seller_app (Seller)

SiteDrop **seller** Flutter app (products, orders, earnings, onboarding).

| | |
|---|---|
| **Folder** | `sitedrop/apps/seller_app/` |
| **Package name** | `sitedrop_seller` |
| **Monorepo** | `sitedrop/apps/` |
| **Shared code** | `../packages/sitedrop_core` |
| **Backend (Api)** | `../../backend` (Laravel `/api/v1`) |

## Run

```powershell
cd C:\xampp\htdocs\websites\project.local\sitedrop\apps\seller_app
flutter pub get
flutter run -d chrome --dart-define=APP_ROLE=seller --dart-define=API_BASE_URL=http://localhost:8000
```

Android emulator: `API_BASE_URL=http://10.0.2.2:8000`

See [../README.md](../README.md) for buyer/driver, scripts, and Makefile targets.
