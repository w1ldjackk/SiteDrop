# SiteDrop Documentation

This folder documents the **SiteDrop backend** (`sitedrop/backend/`) and how it connects to Flutter clients in **`sitedrop/apps/`**.

## Documents

| Doc | Purpose |
|-----|---------|
| **[setup.md](setup.md)** | **Start here** — install, `.env`, FCM, Maps, OTP, wallet notes, smoke checklist |
| [api-overview.md](api-overview.md) | REST API (wallet, notifications, auth, cart, …) |
| [architecture.md](architecture.md) | System design, guest/auth, integrations |

## Related

- [Main Backend README](../README.md)
- [Flutter apps README](../../apps/README.md) — buyer/seller/driver, dart-defines, run scripts
- Monorepo root: [../../README.md](../../README.md)
- Workspace root: [../../../README.md](../../../README.md)

## Workspace (SiteDrop)

```
project.local/
└── sitedrop/
    ├── backend/   # this Api
    └── apps/      # all Flutter Apps
```

## Recent doc updates

| Date | Topic |
|------|--------|
| 2026-07 | Monorepo layout: **`sitedrop/apps`** (Apps) + **`sitedrop/backend`** (Api) |
| 2026-07 | Flutter folders: `buyer_app` / `seller_app` / `driver_app` (test sandbox removed) |
| 2026-07 | Removed `fcm-setup.md`; all setup (incl. FCM) lives in **setup.md** only |
| 2026-07 | Unified **setup.md**; wallet/notifications in api-overview |
| 2026-07 | Guest 401s: cart & profile stats; mobile IndexedStack guards; Sanctum session notes |
