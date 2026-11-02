# SiteDrop API Overview

The SiteDrop backend exposes a REST API primarily consumed by the Flutter mobile application.

**Base URL**: `/api/v1`

All authenticated routes use **Laravel Sanctum** bearer tokens:

```
Authorization: Bearer {token}
```

## Public Endpoints (No Auth)

| Method | Endpoint                        | Description                     |
|--------|---------------------------------|---------------------------------|
| GET    | `/health`                       | Health check + version          |
| GET    | `/config`                       | Public bootstrap config (maps key, flags) |
| GET    | `/system-settings/public`       | Alias for config                |
| GET    | `/products/listings`            | Marketplace product listings    |
| GET    | `/products/{id}`                | Product detail                  |
| GET    | `/products/{id}/reviews`        | Product reviews                 |
| GET    | `/sites`                        | Public site directory           |
| GET    | `/sites/nearby`                 | Sites near a location           |
| GET    | `/sites/{id}`                   | Site details                    |
| GET    | `/sites/{id}/materials`         | Materials required for a site   |
| GET    | `/trucks`                       | Public truck listing            |

## Authentication

### OTP-based flows (recommended)

| Method | Endpoint                    | Purpose                          |
|--------|-----------------------------|----------------------------------|
| POST   | `/auth/otp/send`            | Send OTP (login / verify / reset) |
| POST   | `/auth/otp/verify`          | Verify OTP code                  |
| POST   | `/auth/login-otp`           | Passwordless login (send OTP)    |

### Traditional

| Method | Endpoint                    | Description                     |
|--------|-----------------------------|---------------------------------|
| POST   | `/auth/login`               | Email/phone + password          |
| POST   | `/auth/register`            | New user registration           |
| POST   | `/auth/forgot-password`     | Request password reset          |
| POST   | `/auth/reset-password`      | Complete password reset         |
| POST   | `/auth/logout`              | Logout (requires auth)          |

**Phone reset web fallback**: `/reset-password/phone/{token}` (used from email/SMS links)

## Authenticated Endpoints (`auth:sanctum`)

### Current User

| Method | Endpoint     | Description                     |
|--------|--------------|---------------------------------|
| GET    | `/user`      | Current user + profile + wallet |

### Profile & Settings

- `GET|PUT /profile`
- `GET /profile/stats` — lightweight account stats (orders, reviews, wishlist, deliveries, rating)
- `POST /profile/avatar`
- `GET|PUT /profile/preferences`
- `GET|PUT /settings`
- `GET|PUT /settings/appearance`

### Addresses (Delivery Book)

Full CRUD + `POST /{id}/default`

### Wishlist

- `GET|POST /wishlist`
- `POST /wishlist/toggle`
- `POST /wishlist/add|remove`

### Seller Onboarding

- `GET|POST /seller/onboarding`
- `POST /seller/documents`
- `GET /seller/status`
- `POST /seller/submit-for-review`

### Products (Seller + Buyer)

Public:
- `GET /products/listings`
- `GET /products/{id}`

Authenticated:
- `GET|POST /products`
- `PUT|DELETE /products/{id}`
- `POST /products/{id}/toggle-availability`
- `POST /products/{id}/reviews`

### Sites (Construction Projects)

- `GET|POST /sites`
- `PUT|DELETE /sites/{id}`
- `POST /sites/{id}/status`
- `POST /sites/{id}/materials`
- `POST /sites/{id}/staff`
- `POST /sites/{id}/documents`
- Site visits: `/sites/{siteId}/visits/...`

### Trucks (Fleet)

- `GET|POST /trucks`
- `GET /trucks/available|nearby`
- `PUT|DELETE /trucks/{id}`
- Location: `POST /trucks/{id}/location`
- Documents, insurance, maintenance sub-routes

### Trip Logs (Drivers)

- `GET|POST /trips`
- `POST /trips/{id}/start|end|location`
- `GET /trips/statistics`

### Cart

All cart routes require Sanctum. There is **no** guest cart API; the mobile app keeps an in-memory/local cart until login, then syncs.

- `GET /cart`
- `POST /cart/add`
- `PUT /cart/items/{itemId}`
- `DELETE /cart/items/{itemId}|/clear`

### Checkout & Orders

- `GET /checkout/summary`
- `POST /checkout/place-order`
- `GET /orders`
- `GET /orders/seller` (for sellers)
- `GET|PUT /orders/{id}/status`
- `POST /orders/{id}/cancel`
- Statistics & metrics endpoints

Admin-only:
- `GET /orders/analytics`
- `GET /orders/export`
- `POST /orders/bulk-status`

### Payments

- `GET /payments/methods` — includes **wallet** when the user has a balance
- `POST /payments/initiate`
- `GET /payments/verify`
- `GET /payments/history`
- Webhooks: `/payments/hubtel-callback`, `/payments/paystack-callback`

Checkout can charge **wallet** immediately via `PaymentService` → `WalletService::debit` (category `payment`). Refunds credit the wallet (category `refund`).

### Wallet (all roles)

Wallets are available to **buyer, seller, driver, and admin** (API + web). Mutations go through `App\Services\Wallet\WalletService` (row locks, `wallet_transactions`, then `NotificationService`).

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/wallet` | Current user’s wallet (balance, blocked, available, totals) |
| GET | `/wallet/transactions` | Paginated ledger + wallet summary |
| POST | `/wallet/deposit` | Deposit **request** (pending admin approval) |
| POST | `/wallet/withdraw` | Withdrawal **request** (holds amount in `blocked_balance` until approve/reject) |

**Deposit body:**

```json
{ "amount": 50, "note": "optional", "payment_reference": "optional" }
```

**Withdraw body:**

```json
{ "amount": 20, "note": "optional", "destination": "MoMo / bank details" }
```

**Transaction shape (summary):**

| Field | Values / notes |
|-------|----------------|
| `type` | `credit` \| `debit` \| `blocked` \| `unblocked` |
| `category` | `deposit` \| `withdrawal` \| `payment` \| `refund` \| `adjustment` \| `commission` \| `earning` \| `transfer` \| `hold` \| `release` |
| `status` | `pending` \| `completed` \| `failed` \| `rejected` \| `cancelled` |

**Balances:**

- `balance` — ledger total  
- `blocked_balance` — held (e.g. pending withdrawals)  
- `available_balance` — `balance - blocked_balance` (used for spend / withdraw checks)

**Admin (web only, not under `/api/v1`):**

| Area | Path |
|------|------|
| List / pending | `/admin/wallets` |
| Detail (credit, adjust, toggle) | `/admin/wallets/{id}` |
| Approve / reject | `POST /admin/wallets/transactions/{id}/approve\|reject` |
| Own wallet | `/admin/wallets/mine` |

**Role web UI:** `/buyer/wallet`, `/seller/wallet`, `/driver/wallet`  
**Mobile:** `GET/POST` above; app route `/wallet` (Profile → Wallet).

**Notifications** (in-app + push when enabled): `wallet_credited`, `wallet_debited`, `wallet_deposit_requested`, `wallet_withdrawal_requested`, `wallet_transaction_approved`, `wallet_transaction_rejected`, `wallet_activated`, `wallet_suspended`, `wallet_admin_pending`.

### Notifications (inbox + device token)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/notifications` | In-app inbox (paginated) + `unread_count` |
| GET | `/notifications/unread-count` | Badge count for mobile bell |
| POST | `/notifications/read-all` | Mark all read |
| POST | `/notifications/{id}/read` | Mark one read |
| DELETE | `/notifications/{id}` | Delete |
| POST | `/notifications/register-token` | Store FCM device token |
| DELETE | `/notifications/register-token` | Clear FCM token |

### Deliveries

- `GET /deliveries`
- `GET /deliveries/{id}`
- Driver actions: `POST /deliveries/{id}/accept`, `/location`, `PUT /status`
- Admin: `POST /deliveries/assign-driver`

### Activity Logs (Admin)

- `GET /activity-logs`

## Error Handling

Laravel validation errors (422) are returned in a consistent format:

```json
{
  "message": "The given data was invalid.",
  "errors": {
    "phone": ["The phone field is required."]
  }
}
```

The mobile `ApiService` maps these into user-friendly messages.

### Authentication errors (401)

Unauthenticated API clients receive JSON (when `Accept: application/json`):

```json
{ "message": "Unauthenticated." }
```

| Situation | Expected client behavior |
|-----------|--------------------------|
| No `Authorization` header on protected route | 401 — mobile should **not** call these when guest (cart, wishlist, profile stats, checkout, …) |
| Invalid/expired bearer token | 401 — mobile deletes stored token and sets session to unauthenticated |
| Browser / non-JSON client | May redirect to web `/login` instead of JSON |

Login / register / OTP verify responses include:

```json
{
  "status": "success",
  "user": { "id": 1, "name": "…", "phone": "…", "role": "buyer", "…" },
  "token": "{id}|{plainTextToken}",
  "token_type": "Bearer"
}
```

Mobile must persist the top-level `token` and send `Authorization: Bearer {token}` on subsequent requests.

## Versioning & Legacy

- Current: `/api/v1/...`
- Legacy routes without `/v1` still exist for backward compatibility during mobile rollouts.

## Configuration Endpoint

`GET /api/v1/config?platform=android|ios|web`

Returns non-sensitive runtime configuration (Google Maps key, maintenance mode, feature flags, Firebase **client** options, VAPID **public** key) that the mobile app fetches on startup.

Never includes FCM server keys or the VAPID **private** key.

## See Also

- Full route definition: `sitedrop/backend/routes/api.php` (wallet under `auth:sanctum` → `/wallet/*`)
- Admin wallets: `sitedrop/backend/routes/admin.php` → `/admin/wallets`
- Role wallets: `buyer.php` / `seller.php` / `driver.php` → `/{role}/wallet`
- Backend README: [../README.md](../README.md)
- Flutter apps: [../../apps/README.md](../../apps/README.md)
- Architecture: [architecture.md](architecture.md)
- Full setup (incl. FCM): [setup.md](setup.md)
- Monorepo overview: [../../README.md](../../README.md)