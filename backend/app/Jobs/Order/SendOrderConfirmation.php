<?php
// app/Jobs/Order/SendOrderConfirmation.php

namespace App\Jobs\Order;

use App\Models\Order;
use App\Models\Notification;
use App\Services\Notification\NotificationService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;

class SendOrderConfirmation implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public Order $order;

    public function __construct(Order $order)
    {
        $this->order = $order;
    }

    public function handle(NotificationService $notificationService): void
    {
        try {
            // Send to buyer
            $notificationService->send(
                $this->order->buyer,
                'order_confirmation',
                [
                    'order_number' => $this->order->order_number,
                    'total_amount' => $this->order->total_amount,
                    'delivery_address' => $this->order->delivery_address,
                    'items' => $this->order->product->name . ' x ' . $this->order->quantity,
                    'estimated_delivery' => $this->order->delivery_scheduled_at?->toDateString() ?? 'within 3-5 days',
                ]
            );

            // Send to seller
            $notificationService->send(
                $this->order->seller,
                'new_order_notification',
                [
                    'order_number' => $this->order->order_number,
                    'total_amount' => $this->order->total_amount,
                    'buyer_name' => $this->order->buyer->name,
                    'items' => $this->order->product->name . ' x ' . $this->order->quantity,
                    'delivery_address' => $this->order->delivery_address,
                ]
            );

            Log::info('Order confirmation sent', [
                'order_id' => $this->order->id,
                'order_number' => $this->order->order_number,
                'buyer_id' => $this->order->buyer_id,
                'seller_id' => $this->order->seller_id,
            ]);
        } catch (\Exception $e) {
            Log::error('Order confirmation send failed', [
                'order_id' => $this->order->id,
                'error' => $e->getMessage(),
            ]);

            if ($this->attempts() < 3) {
                $this->release(now()->addMinutes(5));
            }
        }
    }
}
