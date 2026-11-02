<?php
// app/Jobs/Notification/SendDeliveryStatusNotification.php

namespace App\Jobs\Notification;

use App\Models\Delivery;
use App\Models\Notification;
use App\Models\User;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;

class SendDeliveryStatusNotification implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public User $user;
    public Delivery $delivery;
    public string $status;

    public function __construct(User $user, Delivery $delivery, string $status)
    {
        $this->user = $user;
        $this->delivery = $delivery;
        $this->status = $status;
    }

    public function handle(): void
    {
        $statusMessages = [
            'assigned' => 'A driver has been assigned to your delivery',
            'accepted' => 'Driver has accepted your delivery',
            'picked_up' => 'Your order has been picked up',
            'in_transit' => 'Your order is on the way',
            'arrived' => 'Driver has arrived at your location',
            'completed' => 'Your order has been delivered',
            'failed' => 'Delivery failed',
        ];

        $title = "Delivery #{$this->delivery->tracking_number} Update";
        $message = $statusMessages[$this->status] ?? "Delivery status updated to {$this->status}";

        Notification::createNotification(
            $this->user->id,
            $title,
            $message,
            'delivery',
            [
                'delivery_id' => $this->delivery->id,
                'tracking_number' => $this->delivery->tracking_number,
                'order_id' => $this->delivery->order_id,
                'status' => $this->status,
                'status_label' => $this->delivery->status_label,
            ],
            'in_app',
            'high'
        );

        // Send push notification
        if ($this->user->fcm_token) {
            dispatch(new SendPushNotification(
                $this->user->fcm_token,
                $title,
                $message,
                ['delivery_id' => $this->delivery->id]
            ));
        }
    }
}
