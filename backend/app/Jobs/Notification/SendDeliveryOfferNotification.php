<?php
// app/Jobs/Notification/SendDeliveryOfferNotification.php

namespace App\Jobs\Notification;

use App\Models\DeliveryOffer;
use App\Models\Notification;
use App\Models\User;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;

/**
 * Bolt-style trip request: notify ONE offered driver (in-app + push).
 * Unlike SendDriverAssignmentNotification (manual single assignment),
 * many drivers can hold live offers — first-accept wins.
 */
class SendDeliveryOfferNotification implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public DeliveryOffer $offer;

    public function __construct(DeliveryOffer $offer)
    {
        $this->offer = $offer;
    }

    public function handle(): void
    {
        $offer = DeliveryOffer::with(['delivery.order'])->find($this->offer->id);
        if (!$offer || !$offer->isLive()) {
            return;
        }

        $driver = User::find($offer->driver_id);
        $order = $offer->delivery->order ?? null;
        if (!$driver || !$order) {
            return;
        }

        $seconds = max(0, now()->diffInSeconds($offer->expires_at));

        Notification::createNotification(
            $driver->id,
            "New trip request #{$offer->delivery->tracking_number}",
            "Order #{$order->order_number} · {$order->delivery_address} · accept within {$seconds}s",
            'delivery',
            [
                'offer_id' => $offer->id,
                'delivery_id' => $offer->delivery->id,
                'tracking_number' => $offer->delivery->tracking_number,
                'order_id' => $order->id,
                'order_number' => $order->order_number,
                'delivery_address' => $order->delivery_address,
                'delivery_fee' => $offer->delivery->delivery_fee,
                'expires_at' => $offer->expires_at->toIso8601String(),
            ],
            'in_app',
            'high'
        );

        if ($driver->fcm_token) {
            dispatch(new SendPushNotification(
                $driver->fcm_token,
                'New trip request',
                "Order #{$order->order_number} — tap to accept",
                ['offer_id' => $offer->id, 'delivery_id' => $offer->delivery->id]
            ));
        }
    }
}
