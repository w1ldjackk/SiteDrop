# buyer_app (Buyer)

SiteDrop **buyer** Flutter app (marketplace, cart, orders, sites).

| | |
|---|---|
| **Folder** | `sitedrop/apps/buyer_app/` |
| **Package name** | `sitedrop_buyer` |
| **Monorepo** | `sitedrop/apps/` |
| **Shared code** | `../packages/sitedrop_core` |
| **Backend (Api)** | `../../backend` (Laravel `/api/v1`) |

## Run

```powershell
cd C:\xampp\htdocs\websites\project.local\sitedrop\apps\buyer_app
flutter pub get
flutter run -d chrome --dart-define=APP_ROLE=buyer --dart-define=API_BASE_URL=http://localhost:8000
```

Android emulator: `API_BASE_URL=http://10.0.2.2:8000`

See [../README.md](../README.md) for seller/driver, scripts, and Makefile targets.
