# SiteDrop Architecture

This document describes the high-level architecture of the SiteDrop platform.

## System Overview

SiteDrop is a **multi-client platform**:

```
                  +-------------------+
                  |   Web Browsers    |
                  | (Inertia + React) |
                  +---------+---------+
                            |
                            v
+-------------+     +----------------------+     +------------------+
| Flutter     | --> |   Laravel 12 Backend | <-- |  Admin / Ops UI  |
| Mobile App  |     |   (API + Web)        |     |  (same backend)  |
+-------------+     +----------------------+     +------------------+
                            |
                    +-------+-------+
                    |               |
                    v               v
              PostgreSQL /      External Services
              MySQL / SQLite    (Payments, Maps, Firebase)
```

## Backend (`sitedrop/backend/`)

### Technology

- **Framework**: Laravel 12
- **Auth**: Laravel Fortify (web) + Laravel Sanctum (API)
- **Frontend**: Inertia.js 2 + React 19 + TypeScript
- **Authorization**: Spatie Laravel Permission
- **API Style**: REST under `/api/v1`

### Code Organization

```
app/
├── Actions/Domain/    # Focused action classes (e.g. OTP send/verify)
├── Traits/            # Shared traits (ApiResponse, roles, phone normalize)
├── Http/
│   ├── Controllers/   # Api + Backend (base Controller uses ApiResponse)
│   └── Requests/
├── Models/            # Eloquent models (User uses HasAppRoles)
├── Services/          # Business logic + notification classes
│   └── Notification/
├── Jobs/
└── Providers/
```

Key principle: complex flows live under `app/Actions/Domain` and `app/Services`. Shared behavior lives in `app/Traits`.

### Important Services

- `OtpService` — Purpose-scoped OTP generation/verification
- `CheckoutService`
- `DeliveryService`
- `PaymentService`
- `PermissionSeederService`

## Mobile Apps (`../apps/`)

All Flutter clients live under **`sitedrop/apps/`** (sibling of this backend):

```
sitedrop/
  backend/                # this repo — Laravel API + admin (Api)
  apps/                   # Flutter monorepo (Apps)
    packages/sitedrop_core/ # shared Dio, models, theme
    buyer_app/            # store
    seller_app/           # store
    driver_app/           # store
    Makefile
```

### Shared package: `apps/packages/sitedrop_core`

- **API / models / theme / constants / utils**
- **No** screens, Riverpod trees, or GoRouter graphs
- Apps depend with: `sitedrop_core: path: ../packages/sitedrop_core`
- See [apps/README.md](../../apps/README.md)

### Role apps

| App folder | Shell tabs | Guest? |
|------------|------------|--------|
| `buyer_app` | Home · Categories · Cart · Wishlist · Profile | Yes |
| `seller_app` | Dashboard · Products · Orders · Earnings · Profile | No |
| `driver_app` | Available · My Trips · Earnings · Profile | No |

### Technology

- **State Management**: Riverpod 3 (`AsyncNotifier`, `Notifier`, `FutureProvider`)
- **Routing**: go_router
- **Networking**: Dio via `sitedrop_core` `ApiService`
- **Local Storage**: Hive (products), flutter_secure_storage (tokens), SharedPreferences
- **Theming**: `AppPalette` from `sitedrop_core`

### Folder Structure (Current)

```
lib/
├── app/
│   ├── app.dart              # Root widget + router + listeners
│   ├── routes/
│   └── theme/
├── config/                   # AppConfig, Firebase options
├── core/
│   ├── constants/
│   ├── listeners/            # Auth + app-wide listeners
│   └── utils/                # Helpers, validators, toast, AuthGate
├── data/
│   ├── models/               # Hive + JSON serializable models
│   ├── repositories/         # Abstraction over services
│   └── services/             # ApiService, AuthService, CartService, OrderService...
└── presentation/
    ├── providers/            # Riverpod providers
    ├── screens/              # Feature screens (buyer/, seller/, driver/, auth/, profile/)
    └── widgets/
```

### Data Flow

1. UI (Screen/Widget) → Provider
2. Provider → Repository or Service
3. Service → `ApiService` (Dio) → Laravel `/api/v1`
4. Response → Model → State update

Auth state is the source of truth. Many features gate behind `AuthGate`.

### Guest vs authenticated mobile behavior

- Public catalog APIs need no token (`/products/listings`, product detail, public sites).
- Cart, wishlist, profile stats, checkout, orders, etc. require **Sanctum** (`Authorization: Bearer …`).
- The buyer home shell uses an **IndexedStack** (home / categories / cart / wishlist / profile stay mounted). Providers must **skip** protected API calls when there is no token so guests do not generate `401 Unauthenticated` noise.
- Guest cart is local-only until login; after login, `auth_provider` / cart sync load the server cart.
- `ApiService` injects the bearer token from secure storage. If a request that **sent** a bearer receives **401**, the token is cleared and `auth_provider` marks the session unauthenticated (`ApiService.onUnauthorized`).

See also: [apps README](../../apps/README.md).

## Authentication

- Primary: Phone + OTP (very important in target markets)
- Secondary: Email + password
- Reset: Both email and phone supported with 6-digit codes + magic links
- Mobile API: Sanctum personal access tokens (`token` on login/register/OTP verify)

OTP purposes are strictly separated on the backend (`login`, `verify`, `password_reset`).

## Payments

Flow:
1. Client calls `POST /payments/initiate`
2. Backend returns payment URL / reference
3. Client opens WebView (or external browser)
4. Payment provider hits webhook (`/payments/*-callback`)
5. Client polls or receives callback → `GET /payments/verify`

Supported providers: Paystack, Hubtel.

## Real-time / Location

- Drivers update location via `POST /trucks/{id}/location` and `POST /deliveries/{id}/location`
- Trip logs track start/end + intermediate points
- Google Maps used on mobile (key served via public config endpoint)
- FCM: client gets token → `POST /api/v1/notifications/register-token` → Laravel `users.fcm_token` → `PushNotificationService` (HTTP v1 preferred). Web needs `firebase-messaging-sw.js` + VAPID public key. Setup: [setup.md § FCM](./setup.md#3-firebase--fcm-push).
- **Wallet**: `WalletService` + `/api/v1/wallet/*` for all roles; admin under `/admin/wallets`. See [api-overview.md — Wallet](./api-overview.md#wallet-all-roles).

## Data Model Highlights

- **Site**: Construction project. Has materials needed, staff, visits, documents, status.
- **Product**: Sellable material. Owned by seller.
- **Truck**: Delivery vehicle. Has documents, insurance, maintenance, assigned driver.
- **Order**: Buyer → Seller transaction.
- **Delivery**: Links an order (or items) to a truck/driver.
- **TripLog**: Driver's journey record.

## Deployment Considerations

- API and web frontend are served from the same Laravel application.
- Mobile app is distributed separately (Android/iOS).
- Use environment variables + `--dart-define` for different environments.
- Public config endpoint (`/api/v1/config`) bootstraps mobile clients (maps key, flags, etc.).

## Future / Planned Directions

- Stronger offline support (queued actions, local-first orders)
- Live tracking improvements (WebSockets / Pusher / Firebase)
- Advanced seller analytics
- Multi-currency / multi-country expansion

---

See also:
- [Setup guide](./setup.md) (install, env, FCM, Maps)
- [API Overview](./api-overview.md) (wallet, payments, notifications, auth)
- [Backend README](../README.md)
- [apps README](../../apps/README.md)
- [Monorepo README](../../README.md)