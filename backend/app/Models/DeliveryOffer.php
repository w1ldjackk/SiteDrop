<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class DeliveryOffer extends Model
{
    use HasFactory;

    public const STATUS_OFFERED = 'offered';
    public const STATUS_ACCEPTED = 'accepted';
    public const STATUS_DECLINED = 'declined';
    public const STATUS_EXPIRED = 'expired';

    /** Bolt-style offer window (seconds) before lazy expiry + re-offer. */
    public const OFFER_TTL_SECONDS = 90;

    protected $fillable = [
        'delivery_id',
        'driver_id',
        'status',
        'expires_at',
        'responded_at',
    ];

    protected $casts = [
        'expires_at' => 'datetime',
        'responded_at' => 'datetime',
    ];

    public function delivery()
    {
        return $this->belongsTo(Delivery::class);
    }

    public function driver()
    {
        return $this->belongsTo(User::class, 'driver_id');
    }

    public function isLive(): bool
    {
        return $this->status === self::STATUS_OFFERED
            && $this->expires_at !== null
            && $this->expires_at->isFuture();
    }

    public function scopeLive($query)
    {
        return $query->where('status', self::STATUS_OFFERED)
            ->where('expires_at', '>', now());
    }
}
