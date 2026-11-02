<?php
// app/Models/Delivery.php

namespace App\Models;

use App\Enums\DeliveryStatus;
use App\Events\OrderStatusChanged;
use App\Jobs\Notification\SendOrderStatusNotification;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Delivery extends Model
{
    use HasFactory;

    protected $fillable = [
        'order_id',
        'driver_id',
        'tracking_number',
        'status',
        'current_location',
        'picked_up_at',
        'estimated_arrival',
        'actual_arrival',
        'delivery_notes',
        'proof_images',
        'distance_km',
        'estimated_duration',
        'route_path',
        'delivery_fee',
        'assigned_at',
        'accepted_at',
        'started_at',
        'completed_at',
        'customer_signature',
        'delivery_rating',
        'delivery_comment',
        'vehicle_id',
        'dispatch_notes',
        'delivery_window_start',
        'delivery_window_end',
    ];

    protected $casts = [
        'current_location' => 'array',
        'proof_images' => 'array',
        'route_path' => 'array',        'picked_up_at' => 'datetime',
        'estimated_arrival' => 'datetime',
        'actual_arrival' => 'datetime',
        'assigned_at' => 'datetime',
        'accepted_at' => 'datetime',
        'started_at' => 'datetime',
        'completed_at' => 'datetime',
        'delivery_window_start' => 'datetime',
        'delivery_window_end' => 'datetime',
        'distance_km' => 'float',
        'delivery_fee' => 'float',
        'delivery_rating' => 'float',
    ];

        // Status constants
    const STATUS_PENDING = DeliveryStatus::Pending->value;    const STATUS_ASSIGNED = DeliveryStatus::Assigned->value;
    const STATUS_ACCEPTED = DeliveryStatus::Accepted->value;
    const STATUS_PICKED_UP = DeliveryStatus::PickedUp->value;
    const STATUS_IN_TRANSIT = DeliveryStatus::InTransit->value;
    const STATUS_ARRIVED = DeliveryStatus::Arrived->value;
    const STATUS_COMPLETED = DeliveryStatus::Completed->value;
    const STATUS_FAILED = DeliveryStatus::Failed->value;
    const STATUS_RETURNED = DeliveryStatus::Returned->value;

    // Relationships
    public function order()
    {
        return $this->belongsTo(Order::class);
    }

    public function driver()
    {
        return $this->belongsTo(User::class, 'driver_id');
    }

    public function vehicle()
    {
        return $this->belongsTo(Truck::class, 'vehicle_id');
    }

    public function offers()
    {
        return $this->hasMany(DeliveryOffer::class);
    }

    public function tripLogs()
    {
        return $this->hasMany(TripLog::class);
    }

    public function activeTripLog(): ?TripLog
    {
        return $this->tripLogs()
            ->whereIn('status', [TripLog::STATUS_SCHEDULED, TripLog::STATUS_IN_PROGRESS])
            ->latest()
            ->first();
    }

    // Driver payout: 70% of the delivery fee, floored on the standard
    // base fee so free-delivery promos (buyer fee = 0) never zero out
    // driver pay. The platform absorbs the promo cost.
    public const DRIVER_SHARE = 0.70;

    public const MIN_DRIVER_BASE_FEE = 20.0;

    protected $appends = ['driver_payout'];

    // Scopes
    public function scopePending($query)
    {
        return $query->where('status', self::STATUS_PENDING);
    }

    public function scopeActive($query)
    {
        return $query->whereNotIn('status', [
            self::STATUS_COMPLETED,
            self::STATUS_FAILED,
            self::STATUS_RETURNED
        ]);
    }

    public function scopeAssigned($query)
    {
        return $query->where('status', self::STATUS_ASSIGNED);
    }

    public function scopeAccepted($query)
    {
        return $query->where('status', self::STATUS_ACCEPTED);
    }

    public function scopeInTransit($query)
    {
        return $query->where('status', self::STATUS_IN_TRANSIT);
    }

    public function scopeByDriver($query, $driverId)
    {
        return $query->where('driver_id', $driverId);
    }

    public function scopeToday($query)
    {
        return $query->whereDate('created_at', today());
    }

    public function scopeOverdue($query)
    {
        return $query->where('estimated_arrival', '<', now())
            ->whereNotIn('status', [
                self::STATUS_COMPLETED,
                self::STATUS_FAILED,
                self::STATUS_RETURNED
            ]);
    }

    // Accessors
    public function getStatusLabelAttribute()
    {
        $labels = [
            self::STATUS_PENDING => 'Pending Assignment',
            self::STATUS_ASSIGNED => 'Assigned',
            self::STATUS_ACCEPTED => 'Accepted by Driver',
            self::STATUS_PICKED_UP => 'Picked Up',
            self::STATUS_IN_TRANSIT => 'In Transit',
            self::STATUS_ARRIVED => 'Arrived at Destination',
            self::STATUS_COMPLETED => 'Completed',
            self::STATUS_FAILED => 'Failed',
            self::STATUS_RETURNED => 'Returned',
        ];
        return $labels[$this->status] ?? ucwords(str_replace('_', ' ', $this->status));
    }

    public function getStatusColorAttribute()
    {
        $colors = [
            self::STATUS_PENDING => 'secondary',
            self::STATUS_ASSIGNED => 'warning',
            self::STATUS_ACCEPTED => 'info',
            self::STATUS_PICKED_UP => 'primary',
            self::STATUS_IN_TRANSIT => 'primary',
            self::STATUS_ARRIVED => 'success',
            self::STATUS_COMPLETED => 'success',
            self::STATUS_FAILED => 'danger',
            self::STATUS_RETURNED => 'secondary',
        ];
        return $colors[$this->status] ?? 'secondary';
    }

    public function getLocationAttribute()
    {
        if ($this->current_location) {
            return [
                'lat' => $this->current_location['lat'] ?? null,
                'lng' => $this->current_location['lng'] ?? null,
                'timestamp' => $this->current_location['timestamp'] ?? null,
            ];
        }
        return null;
    }

    public function getFormattedDistanceAttribute()
    {
        return number_format($this->distance_km, 2) . ' km';
    }

    /**
     * What the driver earns for this trip (GHS). Never zero for real
     * work: buyer promos may set delivery_fee to 0, but the driver
     * still earns 70% of at least the standard base fee.
     */
    public function getDriverPayoutAttribute(): float
    {
        $base = max((float) ($this->delivery_fee ?? 0), self::MIN_DRIVER_BASE_FEE);
        return round($base * self::DRIVER_SHARE, 2);
    }

    public function getIsLateAttribute()
    {
        if (!$this->estimated_arrival) {
            return false;
        }
        return now()->gt($this->estimated_arrival) && !$this->completed_at;
    }

    public function getTimeRemainingAttribute()
    {
        if (!$this->estimated_arrival || $this->completed_at) {
            return null;
        }

        $remaining = now()->diffInMinutes($this->estimated_arrival);
        if ($remaining < 0) {
            return 'Overdue';
        }

        if ($remaining < 60) {
            return $remaining . ' minutes';
        }

        $hours = floor($remaining / 60);
        $minutes = $remaining % 60;
        return $hours . 'h ' . $minutes . 'm';
    }

    // Methods
    public function assignDriver($driverId)
    {
        $this->update([
            'driver_id' => $driverId,
            'status' => self::STATUS_ASSIGNED,
            'assigned_at' => now(),
        ]);

        // Create notification for driver
        dispatch(new \App\Jobs\Notification\SendDriverAssignmentNotification($this));
    }

    public function acceptByDriver()
    {
        $this->update([
            'status' => self::STATUS_ACCEPTED,
            'accepted_at' => now(),
        ]);

        // Log in truck logs
        if ($this->vehicle_id) {
            \App\Models\TruckLog::logTrip(
                $this->vehicle_id,
                $this->id,
                \App\Models\TruckLog::ACTION_ACCEPTED,
                'Driver accepted delivery',
                ['delivery_id' => $this->id]
            );
        }

        // Fleet history: open a trip log (idempotent, best-effort).
        $this->ensureTripLog();
    }

    public function markAsPickedUp()
    {
        $this->update([
            'status' => self::STATUS_PICKED_UP,
            'picked_up_at' => now(),
        ]);

        // Fleet history: trip goes in-progress at pickup.
        $this->ensureTripLog();

        // Send notification to buyer
        dispatch(new \App\Jobs\Notification\SendDeliveryStatusNotification(
            $this->order->buyer,
            $this,
            'picked_up'
        ));

        // Update order status — broadcast correctly with captured old status
        $order = $this->order;
        $oldStatus = $order->status;
        $order->update([
            'status' => Order::STATUS_IN_TRANSIT,
        ]);
        if ($oldStatus !== Order::STATUS_IN_TRANSIT) {
            $fresh = $order->fresh() ?? $order;
            event(new OrderStatusChanged($fresh, $oldStatus, Order::STATUS_IN_TRANSIT));
            dispatch(new SendOrderStatusNotification($fresh, $oldStatus, Order::STATUS_IN_TRANSIT));
        }
    }

    public function markAsInTransit()
    {
        $this->update([
            'status' => self::STATUS_IN_TRANSIT,
            'started_at' => now(),
        ]);

        // Fleet history: trip goes in-progress at dispatch.
        $trip = $this->ensureTripLog();
        if ($trip && $trip->status === TripLog::STATUS_SCHEDULED) {
            $trip->startTrip();
        }

        if ($this->vehicle_id) {
            $vehicle = Truck::find($this->vehicle_id);
            $vehicle?->markAsInTransit();
        }

        // Log in truck logs
        if ($this->vehicle_id) {
            \App\Models\TruckLog::logTrip(
                $this->vehicle_id,
                $this->id,
                \App\Models\TruckLog::ACTION_TRIP_STARTED,
                'Delivery trip started',
                ['delivery_id' => $this->id]
            );
        }

        // Send notification to buyer
        dispatch(new \App\Jobs\Notification\SendDeliveryStatusNotification(
            $this->order->buyer,
            $this,
            'in_transit'
        ));
    }

    public function markAsArrived()
    {
        $this->update([
            'status' => self::STATUS_ARRIVED,
            'actual_arrival' => now(),
        ]);

        // Send notification to buyer
        dispatch(new \App\Jobs\Notification\SendDeliveryStatusNotification(
            $this->order->buyer,
            $this,
            'arrived'
        ));
    }

    public function markAsCompleted($signature = null, $rating = null, $comment = null)
    {
        $this->update([
            'status' => self::STATUS_COMPLETED,
            'completed_at' => now(),
            'customer_signature' => $signature,
            'delivery_rating' => $rating,
            'delivery_comment' => $comment,
        ]);

        // Update order status — broadcast correctly with captured old status
        $order = $this->order;
        $oldStatus = $order->status;
        $order->update([
            'status' => Order::STATUS_DELIVERED,
            'delivered_at' => now(),
        ]);
        if ($oldStatus !== Order::STATUS_DELIVERED) {
            $fresh = $order->fresh() ?? $order;
            event(new OrderStatusChanged($fresh, $oldStatus, Order::STATUS_DELIVERED));
            dispatch(new SendOrderStatusNotification($fresh, $oldStatus, Order::STATUS_DELIVERED));
        }

        // Update truck status
        if ($this->vehicle_id) {
            $vehicle = Truck::find($this->vehicle_id);
            if ($vehicle) {
                $vehicle->markAsAvailable();
            }
        }

        // Fleet history: close the trip with final mileage.
        $this->closeTripLog(TripLog::STATUS_COMPLETED);

        // Send notification to buyer
        dispatch(new \App\Jobs\Notification\SendDeliveryStatusNotification(
            $this->order->buyer,
            $this,
            'completed'
        ));

        // Send notification to seller
        dispatch(new \App\Jobs\Notification\SendDeliveryStatusNotification(
            $this->order->seller,
            $this,
            'completed'
        ));

        // Update wallet for driver (if applicable)
        $this->creditDriverWallet();
    }

    public function markAsFailed($reason)
    {
        $this->update([
            'status' => self::STATUS_FAILED,
            'delivery_notes' => $reason,
            'completed_at' => now(),
        ]);

        // Update order status — broadcast correctly with captured old status
        $order = $this->order;
        $oldStatus = $order->status;
        $order->update([
            'status' => Order::STATUS_CANCELLED,
        ]);
        if ($oldStatus !== Order::STATUS_CANCELLED) {
            $fresh = $order->fresh() ?? $order;
            event(new OrderStatusChanged($fresh, $oldStatus, Order::STATUS_CANCELLED));
            dispatch(new SendOrderStatusNotification($fresh, $oldStatus, Order::STATUS_CANCELLED));
        }

        // Fleet history: cancel the open trip.
        $this->closeTripLog(TripLog::STATUS_CANCELLED);

        if ($this->vehicle_id) {
            Truck::find($this->vehicle_id)?->markAsAvailable();
        }

        // Notify admin
        dispatch(new \App\Jobs\Notification\SendAdminAlert([
            'type' => 'delivery_failed',
            'delivery_id' => $this->id,
            'order_id' => $this->order_id,
            'reason' => $reason,
            'priority' => 'high',
        ]));
    }

    public function updateLocation($lat, $lng)
    {
        $location = [
            'lat' => $lat,
            'lng' => $lng,
            'timestamp' => now()->toIso8601String(),
        ];

        // Update current location
        $this->update([
            'current_location' => $location,
        ]);

        // Add to route path if in transit
        if ($this->status === self::STATUS_IN_TRANSIT) {
            $routePath = $this->route_path ?? [];
            $routePath[] = $location;
            $this->update(['route_path' => $routePath]);
        }

        // Broadcast real-time location
        broadcast(new \App\Events\DeliveryLocationUpdated($this, $location));

        // Update truck location if assigned
        if ($this->vehicle_id) {
            $truck = Truck::find($this->vehicle_id);
            if ($truck) {
                $truck->updateLocation($lat, $lng);
            }
        }

        // Fleet history: mirror live points into the open trip.
        $this->syncTripLocation($lat, $lng);
    }

    public function getDeliveryETA(): ?array
    {
        if (!$this->current_location || !$this->order->delivery_coordinates) {
            return null;
        }

        $origin = $this->current_location;
        $destination = $this->order->delivery_coordinates;

        // Calculate distance and ETA using Google Maps API
        $distance = $this->calculateDistance(
            $origin['lat'] ?? 0,
            $origin['lng'] ?? 0,
            $destination['lat'] ?? 0,
            $destination['lng'] ?? 0
        );

        // Estimate time based on average speed (30 km/h in city)
        $estimatedMinutes = ($distance / 30) * 60;

        return [
            'distance_km' => round($distance, 2),
            'estimated_duration' => round($estimatedMinutes),
            'estimated_arrival' => now()->addMinutes($estimatedMinutes)->toIso8601String(),
        ];
    }

    private function calculateDistance($lat1, $lon1, $lat2, $lon2): float
    {
        $theta = $lon1 - $lon2;
        $dist = sin(deg2rad($lat1)) * sin(deg2rad($lat2)) +
            cos(deg2rad($lat1)) * cos(deg2rad($lat2)) * cos(deg2rad($theta));
        $dist = acos($dist);
        $dist = rad2deg($dist);
        return $dist * 60 * 1.1515 * 1.609344; // Convert to km
    }

    /**
     * Pickup point for the driver: resolved from the order's primary
     * product source site (seller quarry / warehouse). Null when the
     * product has no linked source site.
     */
    public function getPickupPointAttribute(): ?array
    {
        $order = $this->relationLoaded('order') ? $this->order : $this->order()->first();
        if (! $order) {
            return null;
        }

        $product = $order->relationLoaded('product')
            ? $order->product
            : $order->product()->first();

        if (! $product) {
            return null;
        }

        return $product->pickup_point;
    }

    /**
     * Idempotent fleet trip for this delivery. Resolves truck from
     * delivery.vehicle_id else the driver's assigned truck. Returns null
     * when the driver has no registered truck (trip logging skipped).
     */
    public function ensureTripLog(): ?TripLog
    {
        try {
            $existing = $this->activeTripLog();
            if ($existing) {
                return $existing;
            }

            $truck = $this->vehicle_id
                ? Truck::find($this->vehicle_id)
                : ($this->driver_id
                    ? Truck::where('driver_id', $this->driver_id)->orderByDesc('updated_at')->first()
                    : null);

            if (! $truck || ! $this->driver_id) {
                return null;
            }

            // Backfill vehicle when resolved from driver.
            if (! $this->vehicle_id) {
                $this->updateQuietly(['vehicle_id' => $truck->id]);
            }

            $pickup = $this->pickup_point;
            $startLocation = ($pickup['coordinates'] ?? null)
                ?: ($truck->current_location ?? null)
                ?: ($this->driver?->last_location ?? null)
                ?: ['lat' => 0, 'lng' => 0];

            return TripLog::create([
                'truck_id' => $truck->id,
                'driver_id' => $this->driver_id,
                'order_id' => $this->order_id,
                'delivery_id' => $this->id,
                'start_location' => $startLocation,
                'distance_km' => 0,
                'status' => TripLog::STATUS_IN_PROGRESS,
                'started_at' => now(),
                'start_odometer' => $truck->current_mileage,
            ]);
        } catch (\Throwable) {
            return null;
        }
    }

    /**
     * Mirror a live GPS point into the open fleet trip (best-effort).
     */
    public function syncTripLocation(float $lat, float $lng): void
    {
        try {
            $trip = $this->activeTripLog();
            if (! $trip) {
                return;
            }
            $trip->updateLocation($lat, $lng);
        } catch (\Throwable) {
            // Never break live tracking on trip-sync failure.
        }
    }

    /**
     * Close the open fleet trip on delivery completion/failure and roll
     * distance into truck mileage. Best-effort, never throws.
     */
    public function closeTripLog(string $status): void
    {
        try {
            $trip = $this->activeTripLog();
            if (! $trip) {
                return;
            }

            $endLocation = $this->current_location
                ?: ($this->order?->delivery_coordinates ?? null);

            $distance = (float) ($this->distance_km ?? 0);
            $duration = $trip->started_at ? now()->diffInMinutes($trip->started_at) : null;

            $trip->update([
                'end_location' => $endLocation,
                'distance_km' => $distance > 0 ? $distance : $trip->distance_km,
                'duration_minutes' => $duration,
                'end_odometer' => $trip->start_odometer !== null && $distance > 0
                    ? ((float) $trip->start_odometer + $distance)
                    : $trip->end_odometer,
                'ended_at' => now(),
                'completed_at' => $status === TripLog::STATUS_COMPLETED ? now() : $trip->completed_at,
                'status' => $status,
            ]);

            if ($status === TripLog::STATUS_COMPLETED && $distance > 0 && $trip->truck_id) {
                $truck = Truck::find($trip->truck_id);
                if ($truck) {
                    $truck->update([
                        'current_mileage' => ((float) $truck->current_mileage) + $distance,
                    ]);
                }
            }
        } catch (\Throwable) {
            // Never break delivery completion on trip-close failure.
        }
    }

    private function creditDriverWallet()
    {
        if (!$this->driver_id) {
            return;
        }

        // Calculate driver earnings (70% of delivery fee, floored —
        // free-delivery promos must not zero out driver pay).
        $driverEarnings = $this->driver_payout;
        if ($driverEarnings <= 0) {
            return;
        }

        // Best-effort: wallet credit must never break trip completion.
        try {
            $driver = $this->driver ?? User::find($this->driver_id);
            if (!$driver) {
                return;
            }
            app(\App\Services\Wallet\WalletService::class)->credit(
                $driver,
                (float) $driverEarnings,
                "Delivery payout for order #{$this->order->order_number}",
                \App\Enums\WalletTransactionCategory::Earning,
                "DEL-{$this->tracking_number}",
                ['delivery_id' => $this->id, 'order_id' => $this->order_id],
            );
        } catch (\Throwable $e) {
            \Illuminate\Support\Facades\Log::warning('Driver wallet credit failed', [
                'delivery_id' => $this->id,
                'driver_id' => $this->driver_id,
                'amount' => $driverEarnings,
                'error' => $e->getMessage(),
            ]);
        }
    }
}
