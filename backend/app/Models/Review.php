<?php

namespace App\Models;

use App\Enums\ReviewStatus;
use App\Enums\ReviewType;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Review extends Model
{
    use HasFactory;

    protected $fillable = [
        'order_id',
        'reviewer_id',
        'reviewee_id',
        'product_id',
        'rating',
        'comment',
        'images',
        'type', // buyer_to_seller, buyer_to_product, seller_to_buyer
        'is_verified_purchase',
        'status', // pending, published, hidden, reported
        'helpful_count',
        'reported_count',
    ];

    protected $casts = [
        'images' => 'array',
        'rating' => 'integer',
        'is_verified_purchase' => 'boolean',
        'helpful_count' => 'integer',
        'reported_count' => 'integer',
    ];

    // Review types
    const TYPE_BUYER_TO_SELLER = ReviewType::BuyerToSeller->value;
    const TYPE_BUYER_TO_PRODUCT = ReviewType::BuyerToProduct->value;
    const TYPE_SELLER_TO_BUYER = ReviewType::SellerToBuyer->value;

    // Status constants
    const STATUS_PENDING = ReviewStatus::Pending->value;
    const STATUS_PUBLISHED = ReviewStatus::Published->value;
    const STATUS_HIDDEN = ReviewStatus::Hidden->value;
    const STATUS_REPORTED = ReviewStatus::Reported->value;

    // Relationships
    public function order()
    {
        return $this->belongsTo(Order::class);
    }

    public function reviewer()
    {
        return $this->belongsTo(User::class, 'reviewer_id');
    }

    public function reviewee()
    {
        return $this->belongsTo(User::class, 'reviewee_id');
    }

    public function product()
    {
        return $this->belongsTo(Product::class);
    }

    // Scopes
    public function scopePublished($query)
    {
        return $query->where('status', self::STATUS_PUBLISHED);
    }

    public function scopeVerified($query)
    {
        return $query->where('is_verified_purchase', true);
    }

    // Accessors
    public function getRatingStarsAttribute()
    {
        return str_repeat('⭐', $this->rating) . str_repeat('☆', 5 - $this->rating);
    }

    public function getFormattedRatingAttribute()
    {
        return number_format($this->rating, 1) . '/5.0';
    }

    // Methods
    public function isHelpful(): bool
    {
        return $this->helpful_count > 0;
    }

    public function incrementHelpful()
    {
        $this->increment('helpful_count');
    }

    public function report()
    {
        $this->increment('reported_count');

        if ($this->reported_count >= 5) {
            $this->update(['status' => self::STATUS_REPORTED]);
        }
    }
}
