<?php
// app/Models/Truck.php

namespace App\Models;

use App\Enums\VehicleType;
use App\Enums\TruckStatus;
use App\Models\Delivery;
use App\Models\TripLog;
use App\Models\TruckDocument;
use App\Models\TruckInsurance;
use App\Models\TruckLog;
use App\Models\TruckMaintenance;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Support\Facades\Auth;

class Truck extends Model
{
    use HasFactory, SoftDeletes;

    protected $fillable = [
        'user_id',
        'driver_id',
        'registration_number',
        'make',
        'model',
        'year',
        'color',
        'license_plate_front',
        'license_plate_back',
        'capacity_tons',
        'capacity_cubic_meters',
        'vehicle_type',
        'features',
        'documents',
        'fuel_type',
        'fuel_efficiency_km_per_liter',
        'current_mileage',
        'last_service_mileage',
        'next_service_mileage',
        'last_maintenance_date',
        'next_maintenance_date',
        'insurance_expiry',
        'registration_expiry',
        'owner_type',
        'company_name',
        'status',
        'is_verified',
        'rejected_reason',
        'verified_at',
        'current_location',
        'driver_assigned_at',
        'notes',
    ];

    protected $casts = [
        'features' => 'array',
        'documents' => 'array',
        'current_location' => 'array',
        'insurance_expiry' => 'datetime',
        'registration_expiry' => 'datetime',
        'last_maintenance_date' => 'datetime',
        'next_maintenance_date' => 'datetime',
        'driver_assigned_at' => 'datetime',
        'verified_at' => 'datetime',
        'capacity_tons' => 'float',
        'capacity_cubic_meters' => 'float',
        'fuel_efficiency_km_per_liter' => 'float',
        'current_mileage' => 'float',
        'last_service_mileage' => 'float',
        'next_service_mileage' => 'float',
        'is_verified' => 'boolean',
        'year' => 'integer',
    ];

    // Constants
    const STATUS_AVAILABLE = TruckStatus::Available->value;
    const STATUS_IN_TRANSIT = TruckStatus::InTransit->value;
    const STATUS_MAINTENANCE = TruckStatus::Maintenance->value;
    const STATUS_INACTIVE = TruckStatus::Inactive->value;
    const STATUS_OUT_OF_SERVICE = TruckStatus::OutOfService->value;

    const VEHICLE_TYPE_TIPPER = VehicleType::Tipper->value;
    const VEHICLE_TYPE_FLATBED = VehicleType::Flatbed->value;
    const VEHICLE_TYPE_TANKER = VehicleType::Tanker->value;
    const VEHICLE_TYPE_DUMP_TRUCK = VehicleType::DumpTruck->value;
    const VEHICLE_TYPE_CONCRETE_MIXER = VehicleType::ConcreteMixer->value;
    const VEHICLE_TYPE_CARRIER = VehicleType::Carrier->value;
    const VEHICLE_TYPE_OTHER = 'other';

    const FUEL_TYPE_DIESEL = 'diesel';
    const FUEL_TYPE_PETROL = 'petrol';
    const FUEL_TYPE_ELECTRIC = 'electric';
    const FUEL_TYPE_HYBRID = 'hybrid';

    const OWNER_TYPE_PERSONAL = 'personal';
    const OWNER_TYPE_COMPANY = 'company';

    // ====================== Relationships ======================

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function driver()
    {
        return $this->belongsTo(User::class, 'driver_id');
    }

    public function deliveries()
    {
        return $this->hasMany(Delivery::class, 'vehicle_id');
    }

    public function maintenanceRecords()
    {
        return $this->hasMany(TruckMaintenance::class);
    }

    public function tripLogs()
    {
        return $this->hasMany(TripLog::class);
    }

    public function documents()
    {
        return $this->hasMany(TruckDocument::class);
    }

    public function insurance()
    {
        return $this->hasOne(TruckInsurance::class);
    }

    public function logs()
    {
        return $this->hasMany(TruckLog::class);
    }

    // ====================== Scopes ======================

    public function scopeAvailable($query)
    {
        return $query->where('status', self::STATUS_AVAILABLE);
    }

    public function scopeInTransit($query)
    {
        return $query->where('status', self::STATUS_IN_TRANSIT);
    }

    public function scopeMaintenance($query)
    {
        return $query->where('status', self::STATUS_MAINTENANCE);
    }

    public function scopeVerified($query)
    {
        return $query->where('is_verified', true);
    }

    public function scopeByType($query, $type)
    {
        return $query->where('vehicle_type', $type);
    }

    public function scopeNearby($query, $lat, $lng, $radius = 10)
    {
        return $query->whereRaw(
            "(6371 * acos(cos(radians(?)) * cos(radians(JSON_EXTRACT(current_location, '$.lat'))) * cos(radians(JSON_EXTRACT(current_location, '$.lng')) - radians(?)) + sin(radians(?)) * sin(radians(JSON_EXTRACT(current_location, '$.lat')))) <= ?",
            [$lat, $lng, $lat, $radius]
        );
    }

    public function scopeDueForMaintenance($query)
    {
        return $query->where('next_maintenance_date', '<=', now()->addDays(7))
            ->where('next_maintenance_date', '>=', now());
    }

    public function scopeOverdueMaintenance($query)
    {
        return $query->where('next_maintenance_date', '<', now());
    }

    public function scopeExpiringInsurance($query)
    {
        return $query->where('insurance_expiry', '<=', now()->addDays(30))
            ->where('insurance_expiry', '>=', now());
    }

    // ====================== Accessors ======================

    public function getStatusLabelAttribute()
    {
        return ucwords(str_replace('_', ' ', $this->status));
    }

    public function getVehicleTypeLabelAttribute()
    {
        return ucwords(str_replace('_', ' ', $this->vehicle_type));
    }

    public function getFullNameAttribute()
    {
        return "{$this->make} {$this->model} ({$this->registration_number})";
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

    public function getIsDueForMaintenanceAttribute()
    {
        return $this->next_maintenance_date && $this->next_maintenance_date <= now()->addDays(7);
    }

    public function getIsOverdueForMaintenanceAttribute()
    {
        return $this->next_maintenance_date && $this->next_maintenance_date < now();
    }

    public function getInsuranceStatusAttribute()
    {
        if (!$this->insurance_expiry) {
            return 'not_available';
        }

        if ($this->insurance_expiry < now()) {
            return 'expired';
        }

        if ($this->insurance_expiry <= now()->addDays(30)) {
            return 'expiring_soon';
        }

        return 'active';
    }

    public function getTotalDeliveriesAttribute()
    {
        return $this->deliveries()->count();
    }

    public function getTotalDistanceAttribute()
    {
        return $this->tripLogs()->sum('distance_km');
    }

    public function getAverageFuelEfficiencyAttribute()
    {
        if ($this->fuel_efficiency_km_per_liter) {
            return $this->fuel_efficiency_km_per_liter;
        }

        // Calculate from trip logs
        $avgEfficiency = $this->tripLogs()->avg('fuel_efficiency_km_per_liter');
        return $avgEfficiency ?? 0;
    }

    // ====================== Methods ======================

    public function isAvailable(): bool
    {
        return $this->status === self::STATUS_AVAILABLE;
    }

    public function isInTransit(): bool
    {
        return $this->status === self::STATUS_IN_TRANSIT;
    }

    public function isVerified(): bool
    {
        return $this->is_verified;
    }

    public function markAsAvailable()
    {
        $this->update(['status' => self::STATUS_AVAILABLE]);
    }

    public function markAsInTransit()
    {
        $this->update(['status' => self::STATUS_IN_TRANSIT]);
    }

    public function markForMaintenance($notes = null)
    {
        $this->update([
            'status' => self::STATUS_MAINTENANCE,
            'notes' => $notes,
        ]);
    }

    public function updateLocation($lat, $lng)
    {
        $this->update([
            'current_location' => [
                'lat' => $lat,
                'lng' => $lng,
                'timestamp' => now()->toIso8601String(),
            ]
        ]);
    }

    public function recordTrip($startLocation, $endLocation, $distance, $duration = null)
    {
        return $this->tripLogs()->create([
            'driver_id' => $this->driver_id,
            'start_location' => $startLocation,
            'end_location' => $endLocation,
            'distance_km' => $distance,
            'duration_minutes' => $duration,
            'started_at' => now(),
        ]);
    }

    public function isInsuranceActive(): bool
    {
        return $this->insurance_expiry && $this->insurance_expiry > now();
    }

    public function scheduleMaintenance($date, $notes = null)
    {
        $this->update([
            'next_maintenance_date' => $date,
            'notes' => $notes,
        ]);
    }

    public function performMaintenance($notes = null)
    {
        $this->maintenanceRecords()->create([
            'performed_at' => now(),
            'notes' => $notes,
            'mileage_at_service' => $this->current_mileage,
        ]);

        $this->update([
            'last_maintenance_date' => now(),
            'status' => self::STATUS_AVAILABLE,
        ]);
    }

    public function canAcceptDelivery(): bool
    {
        return $this->isAvailable() && $this->isVerified() && $this->isInsuranceActive();
    }

    // ====================== Boot ======================

    protected static function boot()
    {
        parent::boot();

        static::creating(function ($truck) {
            // Auto-verify if all documents are present
            if ($truck->is_verified === null) {
                $truck->is_verified = false;
            }
        });

        static::created(function ($truck) {
            // Log truck creation
            TruckLog::create([
                'truck_id' => $truck->id,
                'action' => 'created',
                'user_id' => Auth::id() ?? 1,
                'metadata' => ['truck' => $truck->toArray()],
            ]);
        });
    }
}
