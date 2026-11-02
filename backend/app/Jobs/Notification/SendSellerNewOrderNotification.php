<?php
// app/Jobs/Notification/SendSellerNewOrderNotification.php

namespace App\Jobs\Notification;

use App\Models\Order;
use App\Models\Notification;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;

class SendSellerNewOrderNotification implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public Order $order;

    public function __construct(Order $order)
    {
        $this->order = $order;
    }

    public function handle(): void
    {
        try {
            $seller = $this->order->seller;

            // Create notification for seller
            Notification::createNotification(
                $seller->id,
                "New Order #{$this->order->order_number}",
                "You have received a new order from {$this->order->buyer->name}",
                'order',
                [
                    'order_id' => $this->order->id,
                    'order_number' => $this->order->order_number,
                    'buyer_name' => $this->order->buyer->name,
                    'total_amount' => $this->order->total_amount,
                    'quantity' => $this->order->quantity,
                    'product_name' => $this->order->product->name,
                ],
                'in_app',
                'high'
            );

            // Send push notification
            if ($seller->fcm_token) {
                dispatch(new SendPushNotification(
                    $seller->fcm_token,
                    "New Order #{$this->order->order_number}",
                    "You have a new order from {$this->order->buyer->name} for {$this->order->product->name}",
                    ['order_id' => $this->order->id]
                ));
            }

            // Send email notification to seller
            if ($seller->email) {
                // Mail::to($seller->email)->send(new NewOrderNotification($this->order));
            }

            Log::info('Seller new order notification sent', [
                'order_id' => $this->order->id,
                'seller_id' => $seller->id,
            ]);
        } catch (\Exception $e) {
            Log::error('Seller new order notification failed', [
                'order_id' => $this->order->id,
                'error' => $e->getMessage(),
            ]);
        }
    }
}
