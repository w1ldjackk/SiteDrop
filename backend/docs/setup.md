# SiteDrop setup guide

One place for **local development setup** of the Laravel backend, Inertia web app, Flutter mobile app, Firebase/FCM, Maps, wallet credentials, and common env flags.

For **API shapes**, see [api-overview.md](api-overview.md).  
For **architecture**, see [architecture.md](architecture.md).

---

## Prerequisites

| Tool | Notes |
|------|--------|
| PHP 8.2+ | With OpenSSL, curl, PDO MySQL/SQLite |
| Composer | |
| Node.js 20+ / npm | Vite + Inertia frontend |
| MySQL or SQLite | Local DB |
| Flutter stable | Dart `^3.12.2` (see `sitedrop/apps/*/pubspec.yaml`) |
| Android Studio / Xcode | As needed for device builds |
| Windows | Enable **Developer Mode** for Flutter plugin symlinks (`start ms-settings:developers`) |

---

## 1. Backend + web (`sitedrop/backend/`)

```bash
cd sitedrop/backend
composer install
cp .env.example .env   # if needed
php artisan key:generate
```

### Database

```bash
# Configure DB_* in .env, then:
php artisan migrate --seed
```

### Frontend assets

```bash
npm install
npm run dev
# or production: npm run build
```

### Run

```bash
php artisan serve
# optional queue worker (production-like):
php artisan queue:listen
```

App: `http://localhost:8000`

### Important `.env` keys

```env
APP_URL=http://localhost:8000
APP_ENV=local

# OTP codes appear in storage/logs/laravel.log while SMS is stubbed
LOG_OTP_IN_DEV=true

# Firebase client (mobile publicConfig + defaults)
FIREBASE_PROJECT_ID=sitedrop-eb666
FIREBASE_API_KEY=...
FIREBASE_APP_ID=1:865592120613:web:...
FIREBASE_MESSAGING_SENDER_ID=865592120613
FIREBASE_AUTH_DOMAIN=sitedrop-eb666.firebaseapp.com
FIREBASE_STORAGE_BUCKET=sitedrop-eb666.appspot.com
FIREBASE_MEASUREMENT_ID=G-...
FIREBASE_WEB_API_KEY=...
FIREBASE_WEB_APP_ID=...
FIREBASE_VAPID_PUBLIC_KEY=...
FIREBASE_VAPID_PRIVATE_KEY=...   # server only — never expose via API

# FCM server push (HTTP v1)
FIREBASE_CREDENTIALS=storage/app/firebase/service-account.json
# FCM_SERVER_KEY=   # legacy only

# Optional: force sync FCM jobs without queue:work in local
# FCM_DISPATCH_SYNC=true

# Maps (mobile address pin)
GOOGLE_MAPS_API_KEY=
```

PHP on Windows: if FCM OAuth fails with SSL `unable to get local issuer certificate`, set `curl.cainfo` / `openssl.cafile` in `php.ini` to a valid `cacert.pem`.

---

## 2. Flutter apps (`sitedrop/apps/`)

All mobile clients live next to this backend:

```
../apps/
  packages/sitedrop_core/
  buyer_app/ | seller_app/ | driver_app/   # store builds
  Makefile
```

```bash
# Buyer (Chrome)
cd ../apps/buyer_app
flutter pub get
flutter run -d chrome --dart-define=APP_ROLE=buyer --dart-define=API_BASE_URL=http://localhost:8000

# Or from ../apps:  make run-buyer-dev
```

See **[apps/README.md](../../apps/README.md)** for seller/driver, Makefile, and dart-defines.

### API host

| Platform | Default |
|----------|---------|
| Android emulator | `http://10.0.2.2:8000` → `/api/v1` |
| iOS sim / desktop / web | `http://localhost:8000` → `/api/v1` |

```bash
# Physical device / LAN
flutter run --dart-define=API_BASE_URL=http://192.168.x.x:8000

# Android use localhost + adb reverse
flutter run --dart-define=USE_ANDROID_EMULATOR_LOOPBACK=false
```

### Useful flags

```bash
flutter run --dart-define=APP_ROLE=buyer|seller|driver
flutter run --dart-define=GOOGLE_MAPS_API_KEY=...
flutter run --dart-define=ENABLE_FIREBASE=false
flutter run -d chrome --dart-define=FIREBASE_VAPID_KEY=BN...
flutter run --dart-define=BACKGROUND_LOCATION=true   # driver
```

### Android build notes

- Manifest must be valid **ASCII/UTF-8** (no fancy Unicode in comments).
- Maps native key: `android/local.properties` → `GOOGLE_MAPS_API_KEY=...`
- Prefer `dart run build_runner build` only if you regenerate Hive adapters.

---

## 3. Firebase / FCM push

SiteDrop uses **Firebase Cloud Messaging** for mobile and web push.

| Layer | Responsibility |
|-------|----------------|
| Flutter | Init Firebase, get token, `POST /api/v1/notifications/register-token` when signed in |
| Laravel | Stores `users.fcm_token`, sends via `PushNotificationService` |
| Firebase | Delivers to device / browser |

### 3.1 Backend server credentials (HTTP v1 — recommended)

1. [Firebase Console](https://console.firebase.google.com/) → project **sitedrop-eb666**  
2. Project settings → **Service accounts** → **Generate new private key**  
3. Save as:

```text
sitedrop/backend/storage/app/firebase/service-account.json
```

4. Ensure `.env`:

```env
FIREBASE_PROJECT_ID=sitedrop-eb666
FIREBASE_CREDENTIALS=storage/app/firebase/service-account.json
```

5. Verify:

```bash
cd sitedrop/backend
php artisan fcm:status
# expect: configured YES, http_v1 yes, credentials_readable yes
```

6. Test (user must have `fcm_token` — open app signed in first):

```bash
php artisan fcm:status --test-user=5
php artisan fcm:status --test-user=5 --via-app   # in-app + push path
```

**Legacy (deprecated):** `FCM_SERVER_KEY=AAAA...` only if service account is missing.

### 3.2 Flutter web token check

1. Hard-reload Chrome (`web/firebase-messaging-sw.js` + `index.html` loader)  
2. Allow notifications  
3. Expect logs:

```text
Firebase ready (… project=sitedrop-eb666)
FCM token acquired (…xxxxxxxx, web)
```

4. After sign-in:

```text
FCM token registered with backend
```

VAPID public key: `AppConfig` / `FIREBASE_VAPID_PUBLIC_KEY`.  
Private VAPID key: Laravel `.env` only.

### 3.3 Flutter Android / iOS

Web options are configured; native apps may still need:

```bash
cd ../apps/buyer_app
dart pub global activate flutterfire_cli
flutterfire configure --project=sitedrop-eb666
```

Produces/updates:

- `lib/config/firebase_options.dart`
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`

Keep `web/firebase-messaging-sw.js` in sync with web Console options.

**Android:** notification permission (13+).  
**iOS:** Push + Background Modes; APNs key in Firebase Console.

### 3.4 Device token API

```http
POST /api/v1/notifications/register-token
Authorization: Bearer {sanctum}
{ "token": "…", "device_type": "web" }

DELETE /api/v1/notifications/register-token
```

Inbox / badge (see [api-overview.md](api-overview.md#notifications-inbox--device-token)):

- `GET /notifications`, `GET /notifications/unread-count`, mark read, etc.

### 3.5 App notification channels

`NotificationService::send()` fans out:

| Channel | Default | Destination |
|---------|---------|-------------|
| `in_app` | on | Notifications list |
| `email` | on | User email |
| `push` | **on** | FCM (needs `fcm_token`) |
| `sms` | off | Stub until SMS provider |

Platform defaults: **Admin → System Settings → Notifications**.  
User `preferences.notification_channels` overrides.

Local: push often **sync** (no `queue:work`). Production: set `FCM_DISPATCH_SYNC=false` if you always run workers.

### 3.6 Admin Firebase health

**Admin → System Settings → Firebase** shows client keys, VAPID, server push status, device token count. Overall should be **Working** when client + server credentials are ready. Placeholder values like `YOUR_API_KEY` are ignored.

### 3.7 Security

- Never commit `service-account.json` or `FCM_SERVER_KEY`
- Never expose server credentials via `GET /api/v1/config`
- VAPID **private** key stays in Laravel `.env` only

---

## 4. Wallet (brief)

API and roles: see [api-overview.md — Wallet](api-overview.md#wallet-all-roles).

Quick check:

- Mobile: Profile → **Wallet** (`/wallet`)
- Web: `/{role}/wallet`
- Admin: `/admin/wallets` (approve deposits/withdrawals, credit, adjust, suspend)

No extra env beyond normal app DB is required for wallet itself.

---

## 5. Google Maps

| Client | How to set key |
|--------|----------------|
| Mobile runtime | Laravel `GOOGLE_MAPS_API_KEY` → `GET /api/v1/config` |
| Flutter compile | `--dart-define=GOOGLE_MAPS_API_KEY=…` |
| Android native Maps | `android/local.properties` → `GOOGLE_MAPS_API_KEY=…` |
| Web | Maps JS loaded via `web/index.html` helper + same key |

Enable **Maps JavaScript API** (web) and Maps SDK for Android/iOS as needed. Allow `localhost` referrers for local web.

---

## 6. OTP / SMS (dev)

SMS is stubbed. Login OTPs are logged when not in production:

```text
storage/logs/laravel.log
→ OTP issued { "otp": "123456", "hint": "SMS not configured…" }
```

Toggle: `LOG_OTP_IN_DEV=true|false` (see `config/logging.php` → `log_otp_in_dev`).

---

## 7. Smoke checklist

| Step | Command / action | Expect |
|------|------------------|--------|
| API up | `php artisan serve` + `GET /api/v1/health` | `status: ok` |
| FCM server | `php artisan fcm:status` | `configured YES` |
| FCM device | App signed in, allow notifications | `FCM token acquired` + register-token |
| Push test | `php artisan fcm:status --test-user=N --via-app` | HTTP 200 + in-app row |
| Wallet | Deposit request → admin approve | Balance increases + notification |
| Mobile | `flutter run` against API | Login, cart, wallet, notifications badge |

---

## Doc map

| Doc | Purpose |
|-----|---------|
| **[setup.md](setup.md)** (this file) | Install, env, FCM, Maps, OTP, checklist |
| [api-overview.md](api-overview.md) | REST endpoints (wallet, notifications, auth, …) |
| [architecture.md](architecture.md) | System design |
| [../README.md](../README.md) | Backend project overview |
| [../../apps/README.md](../../apps/README.md) | Flutter apps, dart-defines, run scripts |
| [../../README.md](../../README.md) | SiteDrop monorepo overview |
