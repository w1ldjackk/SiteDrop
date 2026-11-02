<?php
// app/Models/TripLog.php

namespace App\Models;

use App\Enums\TripLogStatus;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class TripLog extends Model
{
    use HasFactory;

    protected $fillable = [
        'truck_id',
        'driver_id',
        'order_id',
        'delivery_id',
        'start_location',
        'end_location',
        'distance_km',
        'duration_minutes',
        'fuel_consumed_liters',
        'fuel_efficiency_km_per_liter',
        'started_at',
        'ended_at',
        'status',
        'start_odometer',
        'end_odometer',
        'route_path',
        'waypoints',
        'average_speed',
        'max_speed',
        'weather_conditions',
        'road_conditions',
        'notes',
        'completed_at',
    ];

    protected $casts = [
        'start_location' => 'array',
        'end_location' => 'array',
        'route_path' => 'array',
        'waypoints' => 'array',
        'distance_km' => 'float',
        'duration_minutes' => 'integer',
        'fuel_consumed_liters' => 'float',
        'fuel_efficiency_km_per_liter' => 'float',
        'start_odometer' => 'float',
        'end_odometer' => 'float',
        'average_speed' => 'float',
        'max_speed' => 'float',
        'started_at' => 'datetime',
        'ended_at' => 'datetime',
        'completed_at' => 'datetime',
        'weather_conditions' => 'array',
    ];

    // Constants
    const STATUS_SCHEDULED = TripLogStatus::Scheduled->value;
    const STATUS_IN_PROGRESS = TripLogStatus::InProgress->value;
    const STATUS_COMPLETED = TripLogStatus::Completed->value;
    const STATUS_CANCELLED = TripLogStatus::Cancelled->value;
    const STATUS_DELAYED = TripLogStatus::Delayed->value;

    // Relationships
    public function truck()
    {
        return $this->belongsTo(Truck::class);
    }

    public function driver()
    {
        return $this->belongsTo(User::class, 'driver_id');
    }

    public function order()
    {
        return $this->belongsTo(Order::class);
    }

    public function delivery()
    {
        return $this->belongsTo(Delivery::class);
    }

    // Scopes
    public function scopeInProgress($query)
    {
        return $query->where('status', self::STATUS_IN_PROGRESS);
    }

    public function scopeCompleted($query)
    {
        return $query->where('status', self::STATUS_COMPLETED);
    }

    public function scopeToday($query)
    {
        return $query->whereDate('started_at', today());
    }

    public function scopeThisMonth($query)
    {
        return $query->whereMonth('started_at', now()->month)
            ->whereYear('started_at', now()->year);
    }

    // Accessors
    public function getStatusLabelAttribute()
    {
        return ucwords(str_replace('_', ' ', $this->status));
    }

    public function getTotalDistanceAttribute()
    {
        return number_format($this->distance_km, 2) . ' km';
    }

    public function getDurationAttribute()
    {
        if ($this->duration_minutes) {
            $hours = floor($this->duration_minutes / 60);
            $minutes = $this->duration_minutes % 60;
            if ($hours > 0) {
                return "{$hours}h {$minutes}m";
            }
            return "{$minutes}m";
        }
        return 'N/A';
    }

    public function getAverageSpeedDisplayAttribute()
    {
        if ($this->average_speed) {
            return number_format($this->average_speed, 1) . ' km/h';
        }
        return 'N/A';
    }

    // Methods
    public function startTrip()
    {
        $this->update([
            'status' => self::STATUS_IN_PROGRESS,
            'started_at' => now(),
        ]);
    }

    public function endTrip()
    {
        $this->update([
            'status' => self::STATUS_COMPLETED,
            'ended_at' => now(),
            'completed_at' => now(),
        ]);
    }

    public function updateLocation($lat, $lng)
    {
        if (!$this->route_path) {
            $this->route_path = [];
        }

        $routePath = $this->route_path;
        $routePath[] = [
            'lat' => $lat,
            'lng' => $lng,
            'timestamp' => now()->toIso8601String(),
        ];

        $this->update(['route_path' => $routePath]);
    }

    public function calculateEfficiency()
    {
        if ($this->fuel_consumed_liters && $this->distance_km > 0) {
            return $this->distance_km / $this->fuel_consumed_liters;
        }
        return null;
    }
}
