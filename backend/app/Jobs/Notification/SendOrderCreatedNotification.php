<?php
// app/Jobs/Notification/SendOrderCreatedNotification.php

namespace App\Jobs\Notification;

use App\Models\Order;
use App\Models\Notification;
use App\Services\Notification\NotificationService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;

class SendOrderCreatedNotification implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public Order $order;
    public int $tries = 3;
    public int $backoff = 60; // 1 minute

    public function __construct(Order $order)
    {
        $this->order = $order;
    }

    public function handle(NotificationService $notificationService): void
    {
        try {
            // 1. Send notification to Buyer
            $this->notifyBuyer($notificationService);

            // 2. Send notification to Seller
            $this->notifySeller($notificationService);

            // 3. Send notification to Admins (for monitoring)
            $this->notifyAdmins($notificationService);

            // 4. Create system notification
            $this->createSystemNotification();

            Log::info('Order created notifications sent', [
                'order_id' => $this->order->id,
                'order_number' => $this->order->order_number,
                'buyer_id' => $this->order->buyer_id,
                'seller_id' => $this->order->seller_id,
            ]);
        } catch (\Exception $e) {
            Log::error('Order created notifications failed', [
                'order_id' => $this->order->id,
                'order_number' => $this->order->order_number,
                'error' => $e->getMessage(),
            ]);

            if ($this->attempts() < 3) {
                $this->release(now()->addMinutes(5));
            } else {
                // Notify admin about notification failure
                dispatch(new SendAdminAlert([
                    'type' => 'order_notification_failed',
                    'order_id' => $this->order->id,
                    'message' => $e->getMessage(),
                ]))->onQueue('high');
            }
        }
    }

    /**
     * Notify the buyer
     */
    private function notifyBuyer(NotificationService $notificationService): void
    {
        $buyer = $this->order->buyer;
        $product = $this->order->product;

        $data = [
            'order_id' => $this->order->id,
            'order_number' => $this->order->order_number,
            'total_amount' => number_format($this->order->total_amount, 2),
            'currency' => 'GHS',
            'quantity' => $this->order->quantity,
            'product_name' => $product->name,
            'delivery_address' => $this->order->delivery_address,
            'estimated_delivery' => $this->order->delivery_scheduled_at?->toDateString() ?? 'within 3-5 business days',
            'status' => $this->order->status,
            'status_label' => $this->order->status_label,
            'created_at' => $this->order->created_at->toIso8601String(),
            'action_url' => route('orders.show', $this->order->id),
        ];

        // Send via notification service
        $notificationService->send(
            $buyer,
            'order_created_buyer',
            $data
        );

        // Also create direct in-app notification as backup
        Notification::createNotification(
            $buyer->id,
            "Order #{$this->order->order_number} Placed Successfully 🎉",
            "Your order for {$product->name} (x{$this->order->quantity}) has been placed successfully. Total: GHS " . number_format($this->order->total_amount, 2),
            'order',
            $data,
            'in_app',
            'high',
            $data['action_url']
        );

        Log::info('Buyer notified of order creation', [
            'order_id' => $this->order->id,
            'buyer_id' => $buyer->id,
        ]);
    }

    /**
     * Notify the seller
     */
    private function notifySeller(NotificationService $notificationService): void
    {
        $seller = $this->order->seller;
        $buyer = $this->order->buyer;
        $product = $this->order->product;

        $data = [
            'order_id' => $this->order->id,
            'order_number' => $this->order->order_number,
            'total_amount' => number_format($this->order->total_amount, 2),
            'currency' => 'GHS',
            'quantity' => $this->order->quantity,
            'product_name' => $product->name,
            'buyer_name' => $buyer->name,
            'buyer_phone' => $buyer->phone,
            'buyer_email' => $buyer->email,
            'delivery_address' => $this->order->delivery_address,
            'delivery_scheduled_at' => $this->order->delivery_scheduled_at?->toIso8601String(),
            'special_instructions' => $this->order->special_instructions,
            'created_at' => $this->order->created_at->toIso8601String(),
            'action_url' => route('seller.orders.show', $this->order->id),
        ];

        // Send via notification service
        $notificationService->send(
            $seller,
            'order_created_seller',
            $data
        );

        // Also create direct in-app notification as backup
        Notification::createNotification(
            $seller->id,
            "🛒 New Order #{$this->order->order_number}",
            "You have received a new order from {$buyer->name} for {$product->name} (x{$this->order->quantity}). Total: GHS " . number_format($this->order->total_amount, 2),
            'order',
            $data,
            'in_app',
            'high',
            $data['action_url']
        );

        Log::info('Seller notified of new order', [
            'order_id' => $this->order->id,
            'seller_id' => $seller->id,
        ]);
    }

    /**
     * Notify admins for monitoring
     */
    private function notifyAdmins(NotificationService $notificationService): void
    {
        // Get all admin users
        $admins = \App\Models\User::whereHas('roles', function ($query) {
            $query->whereIn('name', ['admin', 'super-admin']);
        })->get();

        if ($admins->isEmpty()) {
            return;
        }

        $data = [
            'order_id' => $this->order->id,
            'order_number' => $this->order->order_number,
            'total_amount' => number_format($this->order->total_amount, 2),
            'buyer_name' => $this->order->buyer->name,
            'seller_name' => $this->order->seller->name,
            'product_name' => $this->order->product->name,
            'quantity' => $this->order->quantity,
            'created_at' => $this->order->created_at->toIso8601String(),
            'action_url' => route('admin.orders.show', $this->order->id),
        ];

        foreach ($admins as $admin) {
            // Send as low priority for admins (they get a summary, not individual notifications)
            Notification::createNotification(
                $admin->id,
                "📦 New Order #{$this->order->order_number}",
                "New order created by {$data['buyer_name']} for {$data['product_name']}. Amount: GHS {$data['total_amount']}",
                'order',
                $data,
                'in_app',
                'normal',
                $data['action_url']
            );
        }

        Log::info('Admins notified of new order', [
            'order_id' => $this->order->id,
            'admins_notified' => $admins->count(),
        ]);
    }

    /**
     * Create system notification
     */
    private function createSystemNotification(): void
    {
        // Create a system-wide notification for dashboard
        Notification::create([
            'user_id' => 1, // System user
            'type' => 'order',
            'title' => "Order #{$this->order->order_number} Placed",
            'body' => "A new order has been placed by {$this->order->buyer->name}",
            'data' => [
                'order_id' => $this->order->id,
                'order_number' => $this->order->order_number,
                'amount' => $this->order->total_amount,
            ],
            'channel' => 'system',
            'priority' => 'normal',
            'sent_at' => now(),
        ]);

        Log::info('System notification created for order', [
            'order_id' => $this->order->id,
        ]);
    }

    /**
     * Handle job failure
     */
    public function failed(\Throwable $exception): void
    {
        Log::error('Order created notification job failed permanently', [
            'order_id' => $this->order->id,
            'order_number' => $this->order->order_number,
            'error' => $exception->getMessage(),
        ]);

        // Notify admin
        dispatch(new SendAdminAlert([
            'type' => 'order_notification_job_failed',
            'order_id' => $this->order->id,
            'message' => $exception->getMessage(),
            'priority' => 'critical',
        ]))->onQueue('high');
    }
}
