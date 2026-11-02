<?php
// app/Jobs/Order/UpdateOrderStatus.php

namespace App\Jobs\Order;

use App\Jobs\Notification\SendOrderStatusNotification;
use App\Models\Order;
use App\Models\OrderTimeline;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;

class UpdateOrderStatus implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public Order $order;
    public string $newStatus;
    public ?string $reason;

    public function __construct(Order $order, string $newStatus, ?string $reason = null)
    {
        $this->order = $order;
        $this->newStatus = $newStatus;
        $this->reason = $reason;
    }

    public function handle(): void
    {
        try {
            $oldStatus = $this->order->status;

            // Update order status
            $this->order->update(['status' => $this->newStatus]);

            // Log timeline
            OrderTimeline::logStatusChange(
                $this->order,
                $oldStatus,
                $this->newStatus,
                $this->reason
            );

            // Dispatch notification
            dispatch(new SendOrderStatusNotification($this->order, $oldStatus, $this->newStatus));

            Log::info('Order status updated', [
                'order_id' => $this->order->id,
                'order_number' => $this->order->order_number,
                'old_status' => $oldStatus,
                'new_status' => $this->newStatus,
            ]);
        } catch (\Exception $e) {
            Log::error('Order status update failed', [
                'order_id' => $this->order->id,
                'error' => $e->getMessage(),
            ]);

            throw $e;
        }
    }

    public function failed(\Throwable $exception): void
    {
        Log::error('Order status update job failed', [
            'order_id' => $this->order->id,
            'order_number' => $this->order->order_number,
            'new_status' => $this->newStatus,
            'error' => $exception->getMessage(),
        ]);
    }
}
