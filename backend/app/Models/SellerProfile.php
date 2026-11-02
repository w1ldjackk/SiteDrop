<?php
// app/Models/SellerProfile.php

namespace App\Models;

use App\Enums\SellerBusinessType;
use App\Enums\SellerProfileStatus;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class SellerProfile extends Model
{
    use HasFactory, SoftDeletes;

    protected $fillable = [
        'user_id',
        'seller_code',
        'business_name',
        'business_type',
        'business_registration_number',
        'tax_id',
        'business_phone',
        'business_email',
        'website',
        'description',
        'logo_url',
        'cover_image_url',
        'status',
        'service_areas',
        'commission_rate',
        'minimum_order_amount',
        'delivery_radius_km',
        'bank_account_name',
        'bank_account_number',
        'bank_name',
        'bank_branch',
        'email_verified',
        'approved_at',
        'rejected_reason',
        'verification_documents',
        'social_links',
        'business_hours',
    ];

    /**
     * Always expose code to API / Inertia (admin needs it before approval too).
     */
    protected $appends = [
        'public_id',
    ];

    protected $casts = [
        'service_areas' => 'array',
        'verification_documents' => 'array',
        'social_links' => 'array',
        'business_hours' => 'array',
        'commission_rate' => 'float',
        'minimum_order_amount' => 'float',
        'delivery_radius_km' => 'float',
        'email_verified' => 'boolean',
        'approved_at' => 'datetime',
    ];

    // Constants
    const STATUS_PENDING = SellerProfileStatus::Pending->value;
    const STATUS_APPROVED = SellerProfileStatus::Approved->value;
    const STATUS_SUSPENDED = SellerProfileStatus::Suspended->value;
    const STATUS_REJECTED = SellerProfileStatus::Rejected->value;

    const BUSINESS_TYPE_QUARRY = SellerBusinessType::Quarry->value;
    const BUSINESS_TYPE_TRUCK_OWNER = SellerBusinessType::TruckOwner->value;
    const BUSINESS_TYPE_SUPPLIER = SellerBusinessType::Supplier->value;
    const BUSINESS_TYPE_DISTRIBUTOR = SellerBusinessType::Distributor->value;

    // Relationships
    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function products()
    {
        return $this->hasMany(Product::class, 'seller_id', 'user_id');
    }

    public function orders()
    {
        return $this->hasMany(Order::class, 'seller_id', 'user_id');
    }

    public function reviews()
    {
        return $this->hasMany(Review::class, 'reviewee_id', 'user_id');
    }

    // Scopes
    public function scopeApproved($query)
    {
        return $query->where('status', self::STATUS_APPROVED);
    }

    public function scopePending($query)
    {
        return $query->where('status', self::STATUS_PENDING);
    }

    public function scopeActive($query)
    {
        return $query->where('status', self::STATUS_APPROVED);
    }

    public function scopeByBusinessType($query, $type)
    {
        return $query->where('business_type', $type);
    }

    // Accessors
    /**
     * Human-facing unique seller id (e.g. SLR-000001).
     * Falls back to padded primary key if code not yet assigned.
     */
    public function getPublicIdAttribute(): string
    {
        if (! empty($this->seller_code)) {
            return $this->seller_code;
        }

        return $this->id
            ? 'SLR-'.str_pad((string) $this->id, 6, '0', STR_PAD_LEFT)
            : 'SLR-PENDING';
    }

    /**
     * Generate next unique seller_code.
     */
    public static function generateSellerCode(): string
    {
        $next = (int) static::withTrashed()->max('id') + 1;

        do {
            $code = 'SLR-'.str_pad((string) $next, 6, '0', STR_PAD_LEFT);
            $exists = static::withTrashed()->where('seller_code', $code)->exists();
            $next++;
        } while ($exists);

        return $code;
    }

    public function getStatusLabelAttribute()
    {
        return ucwords(str_replace('_', ' ', $this->status));
    }

    public function getBusinessTypeLabelAttribute()
    {
        return ucwords(str_replace('_', ' ', $this->business_type));
    }

    public function getRatingAttribute()
    {
        return $this->reviews()->avg('rating') ?? 0;
    }

    public function getTotalReviewsAttribute()
    {
        return $this->reviews()->count();
    }

    public function getTotalOrdersAttribute()
    {
        return $this->orders()->count();
    }

    public function getRevenueAttribute()
    {
        return $this->orders()->where('status', 'completed')->sum('total_amount');
    }

    public function getFormattedCommissionAttribute()
    {
        return number_format($this->commission_rate, 2) . '%';
    }

    public function getIsApprovedAttribute()
    {
        return $this->status === self::STATUS_APPROVED;
    }

    public function getIsPendingAttribute()
    {
        return $this->status === self::STATUS_PENDING;
    }

    // Methods
    public function approve()
    {
        $this->update([
            'status' => self::STATUS_APPROVED,
            'approved_at' => now(),
        ]);
    }

    public function suspend($reason = null)
    {
        $this->update([
            'status' => self::STATUS_SUSPENDED,
            'rejected_reason' => $reason,
        ]);
    }

    public function reject($reason = null)
    {
        $this->update([
            'status' => self::STATUS_REJECTED,
            'rejected_reason' => $reason,
        ]);
    }

    public function isApproved(): bool
    {
        return $this->status === self::STATUS_APPROVED;
    }

    public function isPending(): bool
    {
        return $this->status === self::STATUS_PENDING;
    }

    public function canSell(): bool
    {
        return $this->isApproved() && $this->user->hasVerifiedPhone();
    }

    // Boot
    protected static function boot()
    {
        parent::boot();

        static::creating(function (SellerProfile $sellerProfile) {
            if (empty($sellerProfile->seller_code)) {
                $sellerProfile->seller_code = static::generateSellerCode();
            }

            // Ensure user has seller role (Spatie App\Models\Role)
            $user = User::whereKey($sellerProfile->user_id)->first();
            if ($user && ! $user->hasRole('seller')) {
                $user->assignRole('seller');
                // Keep denormalized users.role in sync with first Spatie role
                $user->forceFill([
                    'role' => $user->primaryRoleName() ?? 'seller',
                ])->saveQuietly();
            }
        });

        static::created(function (SellerProfile $sellerProfile) {
            // Align code with real id when generated pre-insert (optional polish)
            $expected = 'SLR-'.str_pad((string) $sellerProfile->id, 6, '0', STR_PAD_LEFT);
            if ($sellerProfile->seller_code !== $expected
                && ! static::withTrashed()->where('seller_code', $expected)->where('id', '!=', $sellerProfile->id)->exists()
            ) {
                $sellerProfile->forceFill(['seller_code' => $expected])->saveQuietly();
            }
        });
    }
}
