# SiteDrop

SiteDrop is a construction logistics and building-materials marketplace platform connecting buyers, sellers, drivers, and site teams. It consists of a **Laravel backend API + web dashboard** and **Flutter mobile apps** for each role, sharing a common core package.

```
SiteDrop/                          # monorepo root
├── README.md                      # this file
├── .gitignore
├── .github/                       # CI/CD workflows
├── backend/                       # Laravel 12 API + Inertia/React admin dashboard
│   ├── README.md                  # backend setup & API docs
│   └── docs/                      # setup, architecture, api-overview
└── apps/                          # Flutter monorepo
    ├── README.md                  # apps overview & run instructions
    ├── Makefile                   # run/build targets
    ├── buyer_app/                 # buyer marketplace (store build)
    ├── seller_app/                # seller store app
    ├── driver_app/                # driver delivery app
    └── packages/
        └── sitedrop_core/         # shared API client, models, theme, widgets
```

## What is SiteDrop?

SiteDrop connects construction project owners, material suppliers, and delivery fleets on one platform:

| Role | What they do |
|------|--------------|
| **Buyer** | Browse materials, manage construction sites, place orders, track deliveries |
| **Seller** | Onboard, list products (cement, aggregates, steel…), fulfill orders |
| **Driver** | Accept deliveries, update live location, log trips with registered trucks |
| **Admin / Ops** | Manage users, roles, orders, analytics, trucks, platform settings |

Key domain concepts: **Sites** (construction projects), **Products** (building materials), **Trucks** (fleet vehicles), **Orders / Deliveries / Trip Logs** (order-to-delivery lifecycle with payments).

## Tech Stack

| Layer | Technology |
|-------|------------|
| Backend API | Laravel 12 (PHP 8.2+) |
| Auth | Laravel Fortify + Sanctum |
| Authorization | Spatie Laravel Permission |
| Web Frontend | Inertia.js 2 + React 19 + TypeScript |
| Styling | Tailwind CSS 4 + shadcn-like components |
| Mobile Apps | Flutter (buyer / seller / driver) |
| Shared Mobile Core | `sitedrop_core` Dart package |
| Database | SQLite (default) / MySQL / PostgreSQL |
| Payments | Paystack + Hubtel |
| Push | Firebase Cloud Messaging (FCM) |

## Getting Started

### Backend (`sitedrop/backend/`)

```bash
cd backend
composer install
cp .env.example .env
php artisan key:generate
npm install
touch database/database.sqlite
php artisan migrate --seed
php artisan serve
npm run dev
```

Full details: [`backend/README.md`](backend/README.md), [`backend/docs/setup.md`](backend/docs/setup.md).

### Flutter Apps (`sitedrop/apps/`)

Three store builds — one app per role — powered by the shared `sitedrop_core` package:

```bash
cd apps

# Install deps for all apps
make get

# Run buyer (Chrome)
make run-buyer-dev

# Run seller (Chrome)
make run-seller-dev

# Run driver (Chrome)
make run-driver-dev
```

Each app needs `APP_ROLE` and `API_BASE_URL` dart-defines (see [`apps/Makefile`](apps/Makefile) and [`apps/README.md`](apps/README.md)).

Example for seller:
```bash
cd apps/seller_app
flutter pub get
flutter run -d chrome \
  --dart-define=APP_ROLE=seller \
  --dart-define=API_BASE_URL=http://localhost:8000
```

## Documentation

| Doc | Path |
|-----|------|
| Monorepo overview | [`README.md`](README.md) |
| Apps (buyer/seller/driver) | [`apps/README.md`](apps/README.md) |
| Shared core package | [`apps/packages/sitedrop_core/README.md`](apps/packages/sitedrop_core/README.md) |
| Backend setup | [`backend/README.md`](backend/README.md) |
| Backend setup guide | [`backend/docs/setup.md`](backend/docs/setup.md) |
| Architecture | [`backend/docs/architecture.md`](backend/docs/architecture.md) |
| API overview | [`backend/docs/api-overview.md`](backend/docs/api-overview.md) |

## License

Private project — SiteDrop. Not open source.