# driver_app (Driver)

SiteDrop **driver** Flutter app (deliveries, trips, earnings, location).

| | |
|---|---|
| **Folder** | `sitedrop/apps/driver_app/` |
| **Package name** | `sitedrop_driver` |
| **Monorepo** | `sitedrop/apps/` |
| **Shared code** | `../packages/sitedrop_core` |
| **Backend (Api)** | `../../backend` (Laravel `/api/v1`) |

## Run

```powershell
cd C:\xampp\htdocs\websites\project.local\sitedrop\apps\driver_app
flutter pub get
flutter run -d chrome --dart-define=APP_ROLE=driver --dart-define=BACKGROUND_LOCATION=true --dart-define=API_BASE_URL=http://localhost:8000
```

Android emulator: `API_BASE_URL=http://10.0.2.2:8000`

See [../README.md](../README.md) for buyer/seller, scripts, and Makefile targets.
