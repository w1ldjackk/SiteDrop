<?php
// app/Models/TruckLog.php

namespace App\Models;

use App\Models\Truck;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Auth;

class TruckLog extends Model
{
    use HasFactory;

    protected $fillable = [
        'truck_id',
        'user_id',
        'action',
        'description',
        'metadata',
        'ip_address',
        'user_agent',
    ];

    protected $casts = [
        'metadata' => 'array',
        'created_at' => 'datetime',
    ];

    // Constants
    const ACTION_CREATED = 'created';
    const ACTION_UPDATED = 'updated';
    const ACTION_STATUS_CHANGED = 'status_changed';
    const ACTION_MAINTENANCE = 'maintenance';
    const ACTION_INSURANCE = 'insurance';
    const ACTION_DOCUMENT = 'document';
    const ACTION_ACCEPTED = 'accepted';
    const ACTION_TRIP_STARTED = 'trip_started';
    const ACTION_TRIP_ENDED = 'trip_ended';
    const ACTION_LOCATION_UPDATED = 'location_updated';
    const ACTION_DELETED = 'deleted';

    // Relationships
    public function truck()
    {
        return $this->belongsTo(Truck::class);
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    // Scopes
    public function scopeByAction($query, $action)
    {
        return $query->where('action', $action);
    }

    public function scopeToday($query)
    {
        return $query->whereDate('created_at', today());
    }

    public function scopeByTruck($query, $truckId)
    {
        return $query->where('truck_id', $truckId);
    }

    // Accessors
    public function getActionLabelAttribute()
    {
        return ucwords(str_replace('_', ' ', $this->action));
    }

    public function getFormattedMetadataAttribute()
    {
        if (!$this->metadata) {
            return null;
        }
        return json_encode($this->metadata, JSON_PRETTY_PRINT);
    }

    // Methods
    public static function log($truckId, $action, $description = null, $metadata = [])
    {
        return static::create([
            'truck_id' => $truckId,
            'user_id' => Auth::id(),
            'action' => $action,
            'description' => $description,
            'metadata' => $metadata,
            'ip_address' => request()->ip(),
            'user_agent' => request()->userAgent(),
        ]);
    }

    public static function logStatusChange($truckId, $oldStatus, $newStatus, $reason = null)
    {
        return self::log(
            $truckId,
            self::ACTION_STATUS_CHANGED,
            "Status changed from {$oldStatus} to {$newStatus}",
            [
                'old_status' => $oldStatus,
                'new_status' => $newStatus,
                'reason' => $reason,
            ]
        );
    }

    public static function logMaintenance($truckId, $maintenanceType, $description, $metadata = [])
    {
        return self::log(
            $truckId,
            self::ACTION_MAINTENANCE,
            $description,
            array_merge($metadata, ['maintenance_type' => $maintenanceType])
        );
    }

    public static function logTrip($truckId, $tripId, $action, $description, $metadata = [])
    {
        return self::log(
            $truckId,
            $action,
            $description,
            array_merge($metadata, ['trip_id' => $tripId])
        );
    }
}
