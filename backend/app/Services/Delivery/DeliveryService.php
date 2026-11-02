<?php
// app/Services/Delivery/DeliveryService.php

namespace App\Services\Delivery;

use App\Jobs\Notification\SendDeliveryOfferNotification;
use App\Models\Delivery;
use App\Models\DeliveryOffer;
use App\Models\Order;
use App\Models\OrderTimeline;
use App\Models\User;
use Illuminate\Database\QueryException;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

class DeliveryService
{
    /**
     * Create delivery for an order (idempotent — one delivery per order).
     */
    public function createDelivery(Order $order): Delivery
    {
        $existing = Delivery::where('order_id', $order->id)->first();
        if ($existing) {
            return $existing;
        }

        $delivery = Delivery::create([
            'order_id' => $order->id,
            'tracking_number' => $this->generateTrackingNumber(),
            'status' => Delivery::STATUS_PENDING,
            'delivery_fee' => $order->delivery_fee,
            'estimated_arrival' => $this->calculateEstimatedArrival($order),
        ]);

        // Log delivery creation
        OrderTimeline::log(
            $order,
            $order->status,
            'Delivery created',
            ['delivery_id' => $delivery->id]
        );

        return $delivery;
    }

    /**
     * Ensure a delivery exists for the order (used before dispatch).
     */
    public function ensureDelivery(Order $order): Delivery
    {
        return $this->createDelivery($order);
    }

    /**
     * SiteDrop-style broadcast dispatch: offer the delivery to available
     * drivers (online first), first-accept wins. Safe to retry — never
     * duplicates live offers, never touches an already-accepted delivery.
     *
     * When $onlineOnly is true (order confirmed flow), only drivers with
     * is_online = true are offered the trip.
     *
     * @return array{dispatched: bool, offers: int, reason?: string}
     */
    public function dispatch(Delivery $delivery, int $maxDrivers = 5, bool $onlineOnly = false): array
    {
        $delivery->refresh();

        if ($delivery->driver_id || in_array($delivery->status, [
            Delivery::STATUS_ACCEPTED,
            Delivery::STATUS_PICKED_UP,
            Delivery::STATUS_IN_TRANSIT,
            Delivery::STATUS_ARRIVED,
            Delivery::STATUS_COMPLETED,
        ], true)) {
            return ['dispatched' => false, 'offers' => 0, 'reason' => 'already_taken'];
        }

        $this->expireStaleOffers($delivery);

        $liveDriverIds = DeliveryOffer::where('delivery_id', $delivery->id)
            ->live()
            ->pluck('driver_id')
            ->all();

        $drivers = $this->availableDrivers($maxDrivers * 2, $onlineOnly)
            ->reject(fn (User $u) => in_array($u->id, $liveDriverIds, true))
            ->take($maxDrivers);

        if ($drivers->isEmpty()) {
            return [
                'dispatched' => count($liveDriverIds) > 0,
                'offers' => count($liveDriverIds),
                'reason' => count($liveDriverIds) > 0 ? 'offers_pending' : 'no_drivers',
            ];
        }

        $created = 0;
        foreach ($drivers as $driver) {
            try {
                $offer = DeliveryOffer::create([
                    'delivery_id' => $delivery->id,
                    'driver_id' => $driver->id,
                    'status' => DeliveryOffer::STATUS_OFFERED,
                    'expires_at' => now()->addSeconds(DeliveryOffer::OFFER_TTL_SECONDS),
                ]);
                $created++;
                dispatch(new SendDeliveryOfferNotification($offer));
            } catch (\Throwable) {
                // Duplicate (unique key) — another dispatch already offered.
                continue;
            }
        }

        OrderTimeline::log(
            $delivery->order ?? Order::find($delivery->order_id),
            $delivery->status,
            "Dispatch broadcast to {$created} driver(s)",
            ['delivery_id' => $delivery->id, 'offers' => $created]
        );

        return ['dispatched' => $created > 0, 'offers' => $created + count($liveDriverIds)];
    }

    /**
     * Dispatch by order id (used when seller marks ready_for_delivery).
     */
    public function dispatchForOrder(Order $order, bool $onlineOnly = false): array
    {
        return $this->dispatch($this->ensureDelivery($order), 5, $onlineOnly);
    }

    /**
     * Order-confirmed flow: push the trip request to ONLINE drivers only.
     * Called automatically when an order transitions to confirmed
     * (see Order::boot updated hook) and safe to retry.
     *
     * @return array{dispatched: bool, offers: int, reason?: string}
     */
    public function dispatchOnConfirmed(Order $order, int $maxDrivers = 5): array
    {
        return $this->dispatch($this->ensureDelivery($order), $maxDrivers, true);
    }

    /**
     * Available drivers: role=driver, no active delivery, has verified truck.
     * Online first. When $onlineOnly is true, only is_online = true drivers qualify.
     */
    public function availableDrivers(int $limit = 10, bool $onlineOnly = false)
    {
        // Drivers are identified by Spatie role OR legacy users.role column.
        $query = User::where(function ($q) {
            $q->where('role', 'driver')
                ->orWhereHas('roles', function ($r) {
                    $r->where('name', 'driver');
                });
        })->whereDoesntHave('deliveries', function ($q) {
            $q->whereIn('status', [
                Delivery::STATUS_ASSIGNED,
                Delivery::STATUS_ACCEPTED,
                Delivery::STATUS_PICKED_UP,
                Delivery::STATUS_IN_TRANSIT,
            ]);
        })->whereHas('trucks', function ($q) {
            // Only drivers with at least one verified, available truck with active insurance
            $q->where('is_verified', true)
                ->where('status', \App\Models\Truck::STATUS_AVAILABLE)
                ->where(function ($insurance) {
                    $insurance->whereNull('insurance_expiry')
                        ->orWhere('insurance_expiry', '>', now());
                });
        });

        if ($onlineOnly) {
            $query->where('is_online', true);
        }

        return $query->orderByDesc('is_online')
            ->orderByDesc('last_active_at')
            ->limit($limit)
            ->get();
    }

    /**
     * Find nearest available driver (legacy helper — kept for compat).
     */
    public function findNearestDriver($lat, $lng, $radius = 20): ?User
    {
        return $this->availableDrivers(1)->first();
    }

    /**
     * First-accept-wins. Atomic: row-lock the offer + delivery.
     *
     * @return array{accepted: bool, message: string, delivery?: Delivery}
     */
    public function acceptOffer(DeliveryOffer $offer, User $driver): array
    {
        return DB::transaction(function () use ($offer, $driver) {
            $offer = DeliveryOffer::whereKey($offer->id)->lockForUpdate()->first();
            if (!$offer) {
                return ['accepted' => false, 'message' => 'Offer not found'];
            }
            if ((int) $offer->driver_id !== (int) $driver->id) {
                return ['accepted' => false, 'message' => 'Offer belongs to another driver'];
            }
            if (!$offer->isLive()) {
                $this->expireStaleOffers($offer->delivery);
                return ['accepted' => false, 'message' => 'Offer expired'];
            }

            /** @var Delivery $delivery */
            $delivery = Delivery::whereKey($offer->delivery_id)->lockForUpdate()->first();
            if (!$delivery || $delivery->driver_id) {
                return ['accepted' => false, 'message' => 'Already accepted by another driver'];
            }

            $delivery->update([
                'driver_id' => $driver->id,
                'status' => Delivery::STATUS_ACCEPTED,
                'accepted_at' => now(),
            ]);

            $offer->update([
                'status' => DeliveryOffer::STATUS_ACCEPTED,
                'responded_at' => now(),
            ]);

            // Buyer tracker: the trip now has a driver — move the order
            // out of ready_for_delivery so the buyer sees "On the way"
            // instead of a stuck "finding driver" state.
            if ($delivery->order && $delivery->order->status === Order::STATUS_READY_FOR_DELIVERY) {
                $delivery->order->update(['status' => Order::STATUS_DISPATCHED]);
            }

            // Everyone else loses (SiteDrop-style).
            $this->expireOtherOffers($delivery->id, $offer->id);

            // Fleet history: open the trip log (best-effort, outside lock).
            try {
                $delivery->fresh()->ensureTripLog();
            } catch (\Throwable) {
            }

            OrderTimeline::log(
                $delivery->order,
                $delivery->status,
                "Driver {$driver->name} accepted delivery",
                ['delivery_id' => $delivery->id, 'driver_id' => $driver->id]
            );

            if ($delivery->order) {
                OrderTimeline::log(
                    $delivery->order->fresh(),
                    $delivery->order->status,
                    'Driver assigned — your order is on the way',
                    ['delivery_id' => $delivery->id, 'driver_id' => $driver->id]
                );
            }

            return [
                'accepted' => true,
                'message' => 'Delivery accepted',
                'delivery' => $delivery->fresh(['order', 'driver']),
            ];
        });
    }

    /**
     * Decline → instantly cascade the offer to the next available driver.
     */
    public function declineOffer(DeliveryOffer $offer, User $driver): array
    {
        return DB::transaction(function () use ($offer, $driver) {
            $offer = DeliveryOffer::whereKey($offer->id)->lockForUpdate()->first();
            if (!$offer || (int) $offer->driver_id !== (int) $driver->id) {
                return ['declined' => false, 'message' => 'Offer not found'];
            }
            if ($offer->status !== DeliveryOffer::STATUS_OFFERED) {
                return ['declined' => false, 'message' => 'Offer already answered'];
            }
            $ok = $this->updateOfferStatus($offer, DeliveryOffer::STATUS_OFFERED, DeliveryOffer::STATUS_DECLINED, [
                'responded_at' => now(),
            ]);
            if (! $ok) {
                return ['declined' => false, 'message' => 'Offer already answered'];
            }

            // Cascade: keep the broadcast topped up (SiteDrop-style re-offer).
            $delivery = Delivery::find($offer->delivery_id);
            $toppedUp = 0;
            if ($delivery && !$delivery->driver_id) {
                $result = $this->dispatch($delivery, 1);
                $toppedUp = $result['offers'] ?? 0;
            }
            return ['declined' => true, 'message' => 'Offer declined', 'topped_up' => $toppedUp];
        });
    }

    /**
     * Lazy expiry (no scheduler needed): mark stale offers expired.
     * If nobody is left holding a live offer, top up with fresh drivers.
     */
    public function expireStaleOffers(Delivery $delivery): int
    {
        $ids = DeliveryOffer::where('delivery_id', $delivery->id)
            ->where('status', DeliveryOffer::STATUS_OFFERED)
            ->where('expires_at', '<=', now())
            ->pluck('id')
            ->all();

        $expired = 0;
        foreach ($ids as $id) {
            $offer = DeliveryOffer::find($id);
            if ($offer && $this->updateOfferStatus($offer, DeliveryOffer::STATUS_OFFERED, DeliveryOffer::STATUS_EXPIRED)) {
                $expired++;
            }
        }

        return $expired;
    }

    /**
     * Expire ALL live offers for a delivery (manual admin assignment wins
     * over the broadcast). Safe per-row — see updateOfferStatus().
     */
    public function expireLiveOffers(Delivery $delivery): int
    {
        $ids = DeliveryOffer::where('delivery_id', $delivery->id)
            ->where('status', DeliveryOffer::STATUS_OFFERED)
            ->pluck('id')
            ->all();

        $expired = 0;
        foreach ($ids as $id) {
            $offer = DeliveryOffer::find($id);
            if ($offer && $this->updateOfferStatus($offer, DeliveryOffer::STATUS_OFFERED, DeliveryOffer::STATUS_EXPIRED)) {
                $expired++;
            }
        }

        return $expired;
    }

    /**
     * Expire every live offer except the winner (first-accept-wins).
     */
    protected function expireOtherOffers(int $deliveryId, int $exceptOfferId): int
    {
        $ids = DeliveryOffer::where('delivery_id', $deliveryId)
            ->where('id', '!=', $exceptOfferId)
            ->where('status', DeliveryOffer::STATUS_OFFERED)
            ->pluck('id')
            ->all();

        $expired = 0;
        foreach ($ids as $id) {
            $offer = DeliveryOffer::find($id);
            if ($offer && $this->updateOfferStatus($offer, DeliveryOffer::STATUS_OFFERED, DeliveryOffer::STATUS_EXPIRED)) {
                $expired++;
            }
        }

        return $expired;
    }

    /**
     * Transition one offer offered → terminal status.
     *
     * Defensive against installs still carrying the legacy
     * unique(delivery_id, driver_id, status) key: when a driver is
     * re-offered in a later round, resolving it to the same terminal
     * status as an earlier round (e.g. expired → expired) would violate
     * that key on a bulk update. On a duplicate-key error the oldest
     * conflicting history row is dropped and the update retried once —
     * offers are append-only history, first-accept-wins is enforced by
     * the live-offer check + row locks, not by the key.
     */
    protected function updateOfferStatus(
        DeliveryOffer $offer,
        string $from,
        string $to,
        array $extra = []
    ): bool {
        try {
            return (bool) DeliveryOffer::whereKey($offer->id)
                ->where('status', $from)
                ->update(array_merge(['status' => $to], $extra));
        } catch (QueryException $e) {
            if (! $this->isDuplicateKeyError($e)) {
                throw $e;
            }
        }

        $fresh = DeliveryOffer::find($offer->id);
        if (! $fresh || $fresh->status !== $from) {
            return false;
        }

        DeliveryOffer::where('delivery_id', $fresh->delivery_id)
            ->where('driver_id', $fresh->driver_id)
            ->where('status', $to)
            ->orderBy('id')
            ->first()
            ?->delete();

        try {
            return (bool) DeliveryOffer::whereKey($offer->id)
                ->where('status', $from)
                ->update(array_merge(['status' => $to], $extra));
        } catch (QueryException $e) {
            Log::warning('Delivery offer transition failed', [
                'offer_id' => $offer->id,
                'from' => $from,
                'to' => $to,
                'error' => $e->getMessage(),
            ]);

            return false;
        }
    }

    protected function isDuplicateKeyError(QueryException $e): bool
    {
        $sqlState = $e->errorInfo[0] ?? null; // '23000'
        $code = $e->errorInfo[1] ?? null;     // 1062 mysql · 19 sqlite

        return $sqlState === '23000' || (int) $code === 1062 || (int) $code === 19;
    }

    /**
     * Live offers for a driver (expiry applied on read).
     */
    public function driverOffers(User $driver)
    {
        $ids = DeliveryOffer::where('driver_id', $driver->id)
            ->where('status', DeliveryOffer::STATUS_OFFERED)
            ->where('expires_at', '<=', now())
            ->pluck('id')
            ->all();

        foreach ($ids as $id) {
            $offer = DeliveryOffer::find($id);
            if ($offer) {
                $this->updateOfferStatus($offer, DeliveryOffer::STATUS_OFFERED, DeliveryOffer::STATUS_EXPIRED);
            }
        }

        return DeliveryOffer::with(['delivery.order', 'delivery'])
            ->where('driver_id', $driver->id)
            ->live()
            ->orderBy('expires_at', 'asc')
            ->get();
    }

    /**
     * Calculate estimated arrival time
     */
    protected function calculateEstimatedArrival(Order $order): ?\Carbon\CarbonInterface
    {
        if (!$order->delivery_coordinates) {
            return null;
        }

        // Calculate ETA using distance and average speed
        // This would use Google Maps API
        return now()->addHours(2);
    }

    /**
     * Generate tracking number
     */
    protected function generateTrackingNumber(): string
    {
        return 'TRK-' . date('Y') . '-' . strtoupper(Str::random(8));
    }
}
