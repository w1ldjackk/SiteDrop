# SiteDrop Backend (Api)

Laravel 12 + Inertia + React application that powers **SiteDrop** — a construction logistics and building-materials marketplace for Ghana and emerging African markets.

This repository contains:

- A full-featured REST API (`/api/v1`) consumed by the Flutter mobile apps
- A role-based web application (Inertia.js + React + TypeScript) for buyers, sellers, drivers, and administrators

**Folder:** `sitedrop/backend/`  
**Companion Flutter apps:** [`../apps`](../apps) (buyer / seller / driver + shared `sitedrop_core`)

---

## What is SiteDrop?

SiteDrop connects construction project owners, material suppliers, and delivery fleets on one platform:

- **Buyers** — Browse materials, manage construction sites (projects), place orders, track deliveries.
- **Sellers** — Onboard, list products (cement, aggregates, steel, etc.), fulfill orders.
- **Drivers** — Accept deliveries, update live locations, log trips using registered trucks.
- **Admins / Ops** — Manage users, roles, orders, analytics, trucks, and platform settings.

Key domain concepts:
- **Sites** — Construction project locations with materials needed, staff, visits, documents, and status tracking.
- **Products** — Building materials with pricing per unit, stock, seller ownership, reviews.
- **Trucks** — Fleet vehicles with insurance, maintenance logs, documents, driver assignment, and real-time location.
- **Orders / Deliveries / Trip Logs** — Full order-to-delivery lifecycle with payments.

---

## Tech Stack

| Area              | Technology                                      |
|-------------------|-------------------------------------------------|
| Backend           | Laravel 12 (PHP 8.2+)                           |
| Auth              | Laravel Fortify + Sanctum                       |
| Authorization     | Spatie Laravel Permission                       |
| Frontend (Web)    | Inertia.js 2 + React 19 + TypeScript            |
| Styling           | Tailwind CSS 4 + Radix UI + shadcn-like components |
| Build             | Vite + Laravel Vite Plugin                      |
| API               | REST + Sanctum bearer tokens (`/api/v1`)        |
| Database          | SQLite (default) / MySQL / PostgreSQL           |
| Queues & Jobs     | Database queue (configurable)                   |
| Testing           | Pest PHP                                        |
| Code style        | Laravel Pint                                    |

Additional packages:
- Wayfinder (type-safe routes)
- Exports, Notifications, Activity logging
- Payment integrations: Paystack + Hubtel (webhooks)

---

## Roles

- `buyer` — Browse, cart, orders, sites, addresses, wishlist
- `seller` — Product management, seller dashboard, order fulfillment, onboarding
- `driver` — Deliveries, trip logging, location updates
- `admin` / `ops-manager` / `super-admin` — Full platform management

Roles are enforced via Spatie permissions and middleware.

---

## Project Structure

```
sitedrop/backend/
├── app/
│   ├── Domain/               # Domain-driven folders (Auth, Buyer, Seller, Delivery, Order, Payment…)
│   ├── Http/Controllers/
│   │   ├── Api/              # Mobile-first REST controllers
│   │   └── Backend/          # Admin / web controllers
│   ├── Models/               # Eloquent models (Site, Product, Truck, Order, Delivery, …)
│   ├── Services/             # Business logic (Checkout, Delivery, Payment, OtpService…)
│   └── Jobs/                 # Async jobs (notifications, order processing)
├── database/
│   ├── migrations/
│   ├── seeders/              # PermissionSeeder, ProductSeeder, SiteSeeder, TruckSeeder…
│   └── factories/
├── resources/
│   ├── js/                   # React + Inertia frontend
│   │   ├── pages/            # Inertia pages (buyer, seller, driver dashboards + admin backend)
│   │   ├── components/
│   │   └── layouts/
│   └── views/
├── routes/
│   ├── api.php               # /api/v1 + legacy routes
│   ├── web.php
│   └── admin.php
├── config/
├── docs/                     # setup, architecture, api-overview
└── tools/                    # One-off scripts (seeders, fixes)
```

---

## Getting Started

### Prerequisites

- PHP 8.2+
- Composer
- Node.js 20+ & npm
- SQLite (default) or another supported database

### Setup

```bash
cd sitedrop/backend

# Install PHP dependencies
composer install

# Copy environment
cp .env.example .env
php artisan key:generate

# Install frontend
npm install

# Create database (SQLite by default)
touch database/database.sqlite

# Run migrations + seeders
php artisan migrate --seed
```

Seeders create:
- Roles & permissions
- Sample products, sites, trucks
- Demo users (see `PermissionSeederService` for emails like `admin@sitedrop.gh`, `seller@sitedrop.gh`, etc.)

### Development

```bash
# Full dev stack (server + queue + vite)
composer dev

# Or with SSR
composer dev:ssr
```

Other useful commands:

```bash
php artisan serve
npm run dev
php artisan queue:listen

# Code quality
composer test
composer lint          # pint --parallel
npm run types          # TypeScript check
npm run lint
```

### Production build

```bash
npm run build
npm run build:ssr
```

---

## API (Mobile)

All mobile endpoints are versioned under `/api/v1`.

### Public routes (no auth)

- `GET /api/v1/health`
- `GET /api/v1/config`
- Products: listings, detail, reviews
- Sites: directory, nearby, materials
- Trucks: public listing

### Authenticated routes

Auth via Laravel Sanctum (token in `Authorization: Bearer ...`).

Major groups:
- `/auth` — login, OTP, register, forgot/reset password
- `/user`, `/profile` (incl. `GET /profile/stats`), `/addresses`, `/settings`, `/wishlist`
- `/products` (seller CRUD + reviews)
- `/sites` (buyer/seller management + visits)
- `/trucks` (seller fleet + documents/insurance/maintenance)
- `/trips` (driver trip logs)
- `/cart`, `/checkout`, `/orders` — **no guest cart API**; mobile keeps cart local until Sanctum login
- `/payments` (initiate/verify + callbacks)
- `/deliveries` (driver + admin assignment)
- `/seller/onboarding`

See full definition in `routes/api.php`. Deeper notes: [`docs/api-overview.md`](docs/api-overview.md). Flutter clients: [`../apps/README.md`](../apps/README.md).

Legacy non-versioned routes exist for backward compatibility during mobile updates.

**OTP system**: Purpose-scoped (`login`, `verify`, `password_reset`). Codes are single-use.

**SMS stub (no provider yet):** Outside `production`, OTP codes are logged to `storage/logs/laravel.log` (`SMS dispatch stub (dev — OTP in log)` / `OTP issued` with an `otp` field). Toggle with `LOG_OTP_IN_DEV=true|false`. Production never logs the code.

**FCM push:** Prefer HTTP v1 — put a Firebase service account at `storage/app/firebase/service-account.json` and set `FIREBASE_CREDENTIALS=storage/app/firebase/service-account.json`. Check with `php artisan fcm:status`. Device tokens: `POST /api/v1/notifications/register-token`. Full setup (backend + mobile + FCM): [`docs/setup.md`](docs/setup.md).

**Auth tokens**: Login/register/OTP verify return a top-level Sanctum `token` for `Authorization: Bearer …`. Missing/invalid bearer → JSON `401` `{ "message": "Unauthenticated." }` (with `Accept: application/json`).

**Payments**: Webhooks for Hubtel and Paystack at `/payments/*-callback`.

---

## Web Frontend

Inertia pages provide:

- Public landing + auth flows (email + phone + OTP)
- Role-specific dashboards (`/buyer`, `/seller`, `/driver`)
- Comprehensive admin backend (Users, Roles, Permissions, Products, Sellers, Orders, Trucks, Deliveries, Analytics, Reports, System Settings)

Many admin features use the same API surface where possible.

---

## Database & Seed Data

Default connection: SQLite (`database/database.sqlite`).

Important seeders:
- `PermissionSeeder` → roles & permissions via `PermissionSeederService`
- `ProductSeeder`, `SiteSeeder`, `TruckSeeder`
- `OrderAndPaymentSeeder`

Run specific seeders with `php artisan db:seed --class=...`

---

## Configuration Notes

- `.env` keys of interest:
  - `APP_NAME`, `APP_URL`
  - `DB_*`
  - Payment provider keys (Paystack, Hubtel)
  - `GOOGLE_MAPS_API_KEY` (shared with mobile via public config)
  - `IP_GEOLOCATION_API_KEY`
  - Mail / queue / broadcasting

- Public config endpoint (`/api/v1/config`) exposes non-sensitive settings (maps key, maintenance mode, etc.) to the mobile app.

---

## Testing

```bash
composer test
# or
php artisan test
```

Tests live in `tests/Feature` and `tests/Unit`. Uses Pest.

---

## Tools & Scripts

Located in `tools/`:
- Various data fix and seeding helpers
- `fix-ios-back.mjs`, permission/role sync scripts, etc.

---

## Related Projects

| Project        | Path               | Description                                      |
|----------------|--------------------|--------------------------------------------------|
| Backend (this) | `sitedrop/backend/` | Laravel API + Web (Inertia)                     |
| Flutter apps   | `sitedrop/apps/`    | Buyer / seller / driver + shared `sitedrop_core` |
| Monorepo root  | `sitedrop/`         | [Overview](../README.md)                         |

## Documentation

Additional documentation lives in the `docs/` folder:

- [Setup guide](docs/setup.md) — install, env, FCM, Maps, OTP, checklist
- [Architecture Notes](docs/architecture.md)
- [API Overview](docs/api-overview.md)

These are specific to the SiteDrop platform.

---

## License

Private project — SiteDrop. Not open source.
