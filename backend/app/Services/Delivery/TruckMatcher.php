<?php
// app/Services/Delivery/TruckMatcher.php

namespace App\Services\Delivery;

use App\Models\Delivery;
use App\Models\Order;
use App\Models\Truck;
use Illuminate\Support\Collection;

class TruckMatcher
{
    /**
     * Estimated load in tons for an order.
     * - unit 'ton' → quantity is tons directly
     * - otherwise qty × product weight_kg / 1000 (missing weight = 0)
     * Uses order items when present, else legacy product_id + quantity.
     */
    public function requiredTons(Order $order): float
    {
        $order->loadMissing(['orderItems.product', 'product']);

        if ($order->orderItems && $order->orderItems->count() > 0) {
            $tons = 0.0;
            foreach ($order->orderItems as $item) {
                $unit = strtolower((string) ($item->unit ?? $item->product?->unit ?? ''));
                if ($unit === 'ton') {
                    $tons += (float) $item->quantity;
                    continue;
                }
                $weightKg = (float) ($item->product?->weight_kg ?? 0);
                $tons += ((float) $item->quantity * $weightKg) / 1000;
            }

            return round($tons, 3);
        }

        $unit = strtolower((string) ($order->product?->unit ?? ''));
        if ($unit === 'ton') {
            return round((float) $order->quantity, 3);
        }

        $weightKg = (float) ($order->product?->weight_kg ?? 0);

        return round(((float) $order->quantity * $weightKg) / 1000, 3);
    }

    /**
     * Trucks eligible for a delivery: available, verified, insurance active,
     * capacity fits (when weight known). Best-fit first (smallest sufficient).
     *
     * @return Collection<int, Truck>
     */
    public function eligibleTrucks(Order $order, int $limit = 10, ?string $vehicleType = null): Collection
    {
        $required = $this->requiredTons($order);

        $query = Truck::query()
            ->where('status', Truck::STATUS_AVAILABLE)
            ->where('is_verified', true)
            ->where(function ($q) {
                $q->whereNull('insurance_expiry')->orWhere('insurance_expiry', '>', now());
            });

        if ($required > 0) {
            $query->where('capacity_tons', '>=', $required);
        }

        if ($vehicleType) {
            $query->where('vehicle_type', $vehicleType);
        }

        return $query->orderBy('capacity_tons', 'asc')
            ->orderByDesc('updated_at')
            ->limit($limit)
            ->get();
    }

    /**
     * Validate a specific truck for a delivery. Returns null when OK,
     * otherwise a human-readable rejection reason.
     */
    public function rejectionReason(Truck $truck, Order $order): ?string
    {
        if ($truck->status !== Truck::STATUS_AVAILABLE && $truck->status !== Truck::STATUS_IN_TRANSIT) {
            return "Truck is {$truck->status}, not available";
        }
        if (! $truck->is_verified) {
            return 'Truck is not verified';
        }
        if ($truck->insurance_expiry && $truck->insurance_expiry->lte(now())) {
            return 'Truck insurance expired';
        }

        $required = $this->requiredTons($order);
        if ($required > 0 && (float) $truck->capacity_tons < $required) {
            return "Truck capacity ({$truck->capacity_tons}t) below required {$required}t";
        }

        return null;
    }

    /**
     * Suggested trucks payload for API responses.
     */
    public function suggestions(Delivery $delivery, int $limit = 10, ?string $vehicleType = null): array
    {
        $delivery->loadMissing(['order.orderItems.product', 'order.product']);
        $order = $delivery->order;
        $required = $this->requiredTons($order);
        $trucks = $this->eligibleTrucks($order, $limit, $vehicleType);

        return [
            'required_tons' => $required,
            'pickup' => $delivery->pickup_point,
            'trucks' => $trucks->map(fn (Truck $t) => [
                'id' => $t->id,
                'name' => $t->full_name,
                'vehicle_type' => $t->vehicle_type,
                'capacity_tons' => (float) $t->capacity_tons,
                'status' => $t->status,
                'is_verified' => (bool) $t->is_verified,
                'insurance_expiry' => $t->insurance_expiry?->toIso8601String(),
                'driver_id' => $t->driver_id,
                'current_location' => $t->current_location,
            ])->values()->all(),
        ];
    }
}
