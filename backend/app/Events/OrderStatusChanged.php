<?php
// app/Events/OrderStatusChanged.php

namespace App\Events;

use App\Models\Order;
use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class OrderStatusChanged implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public Order $order;
    public string $oldStatus;
    public string $newStatus;

    public function __construct(Order $order, ?string $oldStatus = null, ?string $newStatus = null)
    {
        $this->order = $order;
        // Caller should always pass explicit $oldStatus (captured before
        // $order->update()). After Eloquent saves, getOriginal() is synced
        // to the new value, so relying on getOriginal() after update would
        // make old_status === new_status. We keep a BC fallback but prefer
        // the explicit argument.
        if ($oldStatus !== null) {
            $this->oldStatus = $oldStatus;
        } elseif ($order->wasChanged('status')) {
            // wasChanged is true but getOriginal is already wrong; best we
            // can do without explicit arg is try getRawOriginal / fallback
            $this->oldStatus = $order->getOriginal('status') ?? $order->status;
        } else {
            $this->oldStatus = $order->getOriginal('status') ?? $order->status;
        }
        $this->newStatus = $newStatus ?? $order->status;
    }

    public function broadcastOn(): array
    {
        return [
            new PrivateChannel('order.' . $this->order->buyer_id),
            new PrivateChannel('order.' . $this->order->seller_id),
        ];
    }

    public function broadcastWith(): array
    {
        return [
            'order_id' => $this->order->id,
            'order_number' => $this->order->order_number,
            'old_status' => $this->oldStatus,
            'new_status' => $this->newStatus,
            'status_label' => $this->order->status_label,
            'updated_at' => $this->order->updated_at->toIso8601String(),
        ];
    }
}
