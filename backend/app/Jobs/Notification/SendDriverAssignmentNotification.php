<?php
// app/Jobs/Notification/SendDriverAssignmentNotification.php

namespace App\Jobs\Notification;

use App\Models\Delivery;
use App\Models\Notification;
use App\Models\User;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;

class SendDriverAssignmentNotification implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public Delivery $delivery;

    public function __construct(Delivery $delivery)
    {
        $this->delivery = $delivery;
    }

    public function handle(): void
    {
        $driver = User::findOrFail($this->delivery->driver_id);
        $order = $this->delivery->order;

        if (!$driver) {
            return;
        }

        // Notify driver
        Notification::createNotification(
            $driver->id,
            "New Delivery Assignment #{$this->delivery->tracking_number}",
            "You have been assigned to deliver order #{$order->order_number}",
            'delivery',
            [
                'delivery_id' => $this->delivery->id,
                'tracking_number' => $this->delivery->tracking_number,
                'order_id' => $order->id,
                'order_number' => $order->order_number,
                'delivery_address' => $order->delivery_address,
                'delivery_fee' => $this->delivery->delivery_fee,
            ],
            'in_app',
            'high'
        );

        // Send push notification
        if ($driver->fcm_token) {
            dispatch(new SendPushNotification(
                $driver->fcm_token,
                "New Delivery Assignment",
                "You have a new delivery for order #{$order->order_number}",
                ['delivery_id' => $this->delivery->id]
            ));
        }

        // Notify buyer
        Notification::createNotification(
            $order->buyer_id,
            "Delivery Driver Assigned",
            "A driver has been assigned to deliver your order #{$order->order_number}",
            'delivery',
            [
                'delivery_id' => $this->delivery->id,
                'tracking_number' => $this->delivery->tracking_number,
            ],
            'in_app',
            'normal'
        );
    }
}
