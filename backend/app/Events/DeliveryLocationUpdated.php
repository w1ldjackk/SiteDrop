<?php
// app/Events/DeliveryLocationUpdated.php

namespace App\Events;

use App\Models\Delivery;
use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class DeliveryLocationUpdated implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public Delivery $delivery;
    public array $location;

    public function __construct(Delivery $delivery, array $location)
    {
        $this->delivery = $delivery;
        $this->location = $location;
    }

    public function broadcastOn(): array
    {
        return [
            new PrivateChannel('delivery.' . $this->delivery->id),
            new PrivateChannel('order.' . $this->delivery->order_id),
            new PrivateChannel('driver.' . $this->delivery->driver_id),
        ];
    }

    public function broadcastWith(): array
    {
        return [
            'delivery_id' => $this->delivery->id,
            'order_id' => $this->delivery->order_id,
            'location' => $this->location,
            'eta' => $this->delivery->getDeliveryETA(),
        ];
    }
}
