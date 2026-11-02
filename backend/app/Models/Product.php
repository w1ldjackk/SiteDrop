<?php

namespace App\Models;

use App\Models\Order;
use App\Models\Review;
use App\Models\SellerProfile;
use App\Models\User;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class Product extends Model
{
    use HasFactory, SoftDeletes;

    protected $fillable = [
        'seller_id',
        'site_id',
        'name',
        'category',
        'sub_category',
        'description',
        'price_per_unit',
        'unit', // ton, bag, cubic_meter, truck, piece
        'minimum_order_quantity',
        'maximum_order_quantity',
        'is_available',
        'is_featured',
        'images',
        'specifications',
        'delivery_fee_per_km',
        'preparation_time_minutes',
        'weight_kg',
        'stock_quantity',
        'sku',
        'views_count',
        'orders_count',
        'avg_rating',
        'is_cod_available',
        'is_delivery_available',
    ];

    protected $casts = [
        'images' => 'array',
        'specifications' => 'array',
        'price_per_unit' => 'float',
        'delivery_fee_per_km' => 'float',
        'minimum_order_quantity' => 'integer',
        'maximum_order_quantity' => 'integer',
        'is_available' => 'boolean',
        'is_featured' => 'boolean',
        'is_cod_available' => 'boolean',
        'is_delivery_available' => 'boolean',
        'views_count' => 'integer',
        'orders_count' => 'integer',
        'avg_rating' => 'float',
        'preparation_time_minutes' => 'integer',
        'weight_kg' => 'float',
        'stock_quantity' => 'integer',
    ];

    // Relationships
    public function seller()
    {
        return $this->belongsTo(User::class, 'seller_id');
    }

    public function sellerProfile()
    {
        return $this->belongsTo(SellerProfile::class, 'seller_id', 'user_id');
    }

    /**
     * Source site (quarry / warehouse / supplier yard) this product
     * is stocked at / picked up from. Null = seller default location.
     */
    public function sourceSite()
    {
        return $this->belongsTo(Site::class, 'site_id');
    }

    public function orders()
    {
        return $this->hasMany(Order::class);
    }

    public function reviews()
    {
        return $this->hasMany(Review::class);
    }

    // Scopes
    public function scopeAvailable($query)
    {
        return $query->where('is_available', true);
    }

    public function scopeFeatured($query)
    {
        return $query->where('is_featured', true);
    }

    public function scopeCategory($query, $category)
    {
        return $query->where('category', $category);
    }

    public function scopeNearby($query, $lat, $lng, $radius = 50)
    {
        // Implement geospatial query
        return $query;
    }

    // Accessors
    public function getFormattedPriceAttribute()
    {
        return 'GH₵ ' . number_format($this->price_per_unit, 2);
    }

    public function getRatingAttribute()
    {
        return $this->reviews()->avg('rating') ?? 0;
    }

    public function getTotalOrdersAttribute()
    {
        return $this->orders()->count();
    }

    // Methods
    public function isInStock(): bool
    {
        return $this->stock_quantity > 0;
    }

    /**
     * Resolved pickup point for drivers: source site coordinates/address
     * when linked, otherwise null (fall back to seller profile).
     *
     * @return array{site_id: int|null, name: string|null, address: string|null, coordinates: array|null, contact_phone: string|null, access_notes: string|null}|null
     */
    public function getPickupPointAttribute(): ?array
    {
        $site = $this->relationLoaded('sourceSite') ? $this->sourceSite : $this->sourceSite()->first();
        if (! $site) {
            return null;
        }

        return [
            'site_id' => $site->id,
            'name' => $site->name,
            'address' => $site->address,
            'coordinates' => $site->coordinates,
            'contact_phone' => $site->contact_phone,
            'access_notes' => $site->access_notes,
        ];
    }
}
