<?php
// app/Jobs/Notification/SendOrderStatusNotification.php

namespace App\Jobs\Notification;

use App\Models\Order;
use App\Models\Notification;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;

class SendOrderStatusNotification implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public Order $order;
    public string $oldStatus;
    public string $newStatus;

    public function __construct(Order $order, string $oldStatus, string $newStatus)
    {
        $this->order = $order;
        $this->oldStatus = $oldStatus;
        $this->newStatus = $newStatus;
    }

    public function handle(): void
    {
        try {
            $statusMessages = [
                'confirmed' => 'Your order has been confirmed',
                'processing' => 'Your order is being processed',
                'ready_for_delivery' => 'Your order is ready for delivery',
                'in_transit' => 'Your order is on the way',
                'delivered' => 'Your order has been delivered',
                'completed' => 'Your order is complete',
                'cancelled' => 'Your order has been cancelled',
            ];

            $message = $statusMessages[$this->newStatus] ?? "Order status updated to {$this->newStatus}";
            $title = "Order #{$this->order->order_number} Update";

            // Send to buyer
            Notification::createNotification(
                $this->order->buyer_id,
                $title,
                $message,
                'order',
                [
                    'order_id' => $this->order->id,
                    'order_number' => $this->order->order_number,
                    'old_status' => $this->oldStatus,
                    'new_status' => $this->newStatus,
                    'status_label' => $this->order->status_label,
                ],
                'in_app',
                $this->newStatus === 'cancelled' ? 'high' : 'normal'
            );

            // Send push notification
            if ($this->order->buyer->fcm_token) {
                dispatch(new SendPushNotification(
                    $this->order->buyer->fcm_token,
                    $title,
                    $message,
                    ['order_id' => $this->order->id]
                ));
            }

            Log::info('Order status notification sent', [
                'order_id' => $this->order->id,
                'order_number' => $this->order->order_number,
                'new_status' => $this->newStatus,
            ]);
        } catch (\Exception $e) {
            Log::error('Order status notification failed', [
                'order_id' => $this->order->id,
                'error' => $e->getMessage(),
            ]);
        }
    }
}
