<?php
// app/Models/Site.php

namespace App\Models;

use App\Enums\SitePriority;
use App\Enums\SiteType;
use App\Enums\SiteStatus;
use App\Models\Delivery;
use App\Models\Order;
use App\Models\SiteDocument;
use App\Models\SiteMaterial;
use App\Models\SiteStaff;
use App\Models\SiteStatusLog;
use App\Models\SiteVisit;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Support\Facades\Auth;

class Site extends Model
{
    use HasFactory, SoftDeletes;

    protected $fillable = [
        'user_id',
        'name',
        'address',
        'coordinates',
        'contact_person',
        'contact_phone',
        'site_photos',
        'description',
        'site_type',
        'status',
        'size_sq_meters',
        'budget',
        'materials_needed',
        'priority_level',
        'project_start_date',
        'estimated_completion_date',
        'site_manager_id',
        'supervisor_id',
        'access_notes',
        'security_requirements',
        'site_code',
        'status_update_reason',
        'status_updated_at',
    ];

    protected $casts = [
        'coordinates' => 'array',
        'site_photos' => 'array',
        'materials_needed' => 'array',
        'estimated_completion_date' => 'datetime',
        'project_start_date' => 'datetime',
        'size_sq_meters' => 'float',
        'budget' => 'float',
        'priority_level' => 'string',
        'status' => 'string',
    ];

    // Constants
    const STATUS_ACTIVE = SiteStatus::Active->value;
    const STATUS_INACTIVE = SiteStatus::Inactive->value;
    const STATUS_COMPLETED = SiteStatus::Completed->value;
    const STATUS_PLANNING = SiteStatus::Planning->value;
    const STATUS_ON_HOLD = SiteStatus::OnHold->value;
    const STATUS_CANCELLED = SiteStatus::Cancelled->value;

    const SITE_TYPE_CONSTRUCTION = SiteType::Construction->value;
    const SITE_TYPE_QUARRY = SiteType::Quarry->value;
    const SITE_TYPE_WAREHOUSE = SiteType::Warehouse->value;
    const SITE_TYPE_SUPPLIER = SiteType::Supplier->value;
    const SITE_TYPE_OTHER = SiteType::Other->value;

    const PRIORITY_HIGH = SitePriority::High->value;
    const PRIORITY_MEDIUM = SitePriority::Medium->value;
    const PRIORITY_LOW = SitePriority::Low->value;

    // ====================== Relationships ======================

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function siteManager()
    {
        return $this->belongsTo(User::class, 'site_manager_id');
    }

    public function supervisor()
    {
        return $this->belongsTo(User::class, 'supervisor_id');
    }

    // Orders for a site are orders of products stocked at this site.
    // There is no orders.site_id column — join via products.site_id.
    public function orders()
    {
        return $this->hasManyThrough(Order::class, Product::class, 'site_id', 'product_id', 'id', 'id');
    }

    /**
     * Products stocked at / picked up from this source site
     * (seller quarry / warehouse / supplier yard).
     */
    public function stockedProducts()
    {
        return $this->hasMany(Product::class, 'site_id');
    }

    public function deliveries()
    {
        return $this->hasMany(Delivery::class);
    }

    public function siteVisits()
    {
        return $this->hasMany(SiteVisit::class);
    }

    public function materials()
    {
        return $this->hasMany(SiteMaterial::class);
    }

    public function documents()
    {
        return $this->hasMany(SiteDocument::class);
    }

    public function siteStaff()
    {
        return $this->hasMany(SiteStaff::class);
    }

    // Aliases expected by controller / older code
    public function staff()
    {
        return $this->siteStaff();
    }

    public function visits()
    {
        return $this->siteVisits();
    }

    public function statusLogs()
    {
        return $this->hasMany(SiteStatusLog::class);
    }

    // ====================== Scopes ======================

    public function scopeActive($query)
    {
        return $query->where('status', self::STATUS_ACTIVE);
    }

    public function scopeCompleted($query)
    {
        return $query->where('status', self::STATUS_COMPLETED);
    }

    public function scopePlanning($query)
    {
        return $query->where('status', self::STATUS_PLANNING);
    }

    public function scopeByType($query, $type)
    {
        return $query->where('site_type', $type);
    }

    public function scopeNearby($query, $lat, $lng, $radius = 10)
    {
        // Using simple distance calculation
        return $query->whereRaw(
            "(6371 * acos(cos(radians(?)) * cos(radians(JSON_EXTRACT(coordinates, '$.lat'))) * cos(radians(JSON_EXTRACT(coordinates, '$.lng')) - radians(?)) + sin(radians(?)) * sin(radians(JSON_EXTRACT(coordinates, '$.lat')))) <= ?",
            [$lat, $lng, $lat, $radius]
        );
    }

    public function scopeHighPriority($query)
    {
        return $query->where('priority_level', self::PRIORITY_HIGH);
    }

    // ====================== Accessors ======================

    public function getFullAddressAttribute()
    {
        return $this->address;
    }

    public function getLocationAttribute()
    {
        if ($this->coordinates) {
            return [
                'lat' => $this->coordinates['lat'] ?? null,
                'lng' => $this->coordinates['lng'] ?? null,
            ];
        }
        return null;
    }

    public function getStatusLabelAttribute()
    {
        return ucwords(str_replace('_', ' ', $this->status));
    }

    public function getPriorityLabelAttribute()
    {
        return ucfirst($this->priority_level);
    }

    public function getProgressAttribute()
    {
        // Calculate progress based on materials delivered vs total needed
        $totalMaterials = $this->materials()->sum('quantity_needed');
        $deliveredMaterials = $this->materials()->sum('quantity_delivered');

        if ($totalMaterials > 0) {
            return min(100, round(($deliveredMaterials / $totalMaterials) * 100));
        }

        return 0;
    }

    public function getTotalSpentAttribute()
    {
        return $this->orders()->sum('total_amount');
    }

    // ====================== Methods ======================

    public function isActive(): bool
    {
        return $this->status === self::STATUS_ACTIVE;
    }

    public function isCompleted(): bool
    {
        return $this->status === self::STATUS_COMPLETED;
    }

    public function isHighPriority(): bool
    {
        return $this->priority_level === self::PRIORITY_HIGH;
    }

    public function addMaterial(array $materialData)
    {
        return $this->materials()->create($materialData);
    }

    public function updateStatus(string $status, string $reason = null)
    {
        $this->update([
            'status' => $status,
            'status_update_reason' => $reason,
            'status_updated_at' => now(),
        ]);

        // Log status change
        SiteStatusLog::create([
            'site_id' => $this->id,
            'old_status' => $this->getOriginal('status'),
            'new_status' => $status,
            'reason' => $reason,
            'user_id' => Auth::id(),
        ]);
    }

    public function getUpcomingDeliveries()
    {
        return $this->deliveries()
            ->where('delivery_date', '>=', now())
            ->where('status', '!=', 'completed')
            ->orderBy('delivery_date')
            ->get();
    }

    // ====================== Boot ======================

    protected static function boot()
    {
        parent::boot();

        static::creating(function ($site) {
            // Generate site code
            if (empty($site->site_code)) {
                $site->site_code = self::generateSiteCode();
            }
        });

        static::created(function ($site) {
            // Create default site materials if needed
            // Log site creation
            SiteStatusLog::create([
                'site_id' => $site->id,
                'old_status' => null,
                'new_status' => $site->status,
                'reason' => 'Site created',
                'user_id' => Auth::id() ?? 1,
            ]);
        });
    }

    private static function generateSiteCode(): string
    {
        $prefix = 'SITE';
        $year = date('Y');
        $random = strtoupper(substr(uniqid(), -6));
        return $prefix . $year . $random;
    }
}
