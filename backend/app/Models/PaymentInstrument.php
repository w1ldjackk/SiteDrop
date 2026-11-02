<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class PaymentInstrument extends Model
{
    use HasFactory;

    public const TYPE_MOMO = 'mobile_money';
    public const TYPE_CARD = 'card';
    public const TYPE_BANK = 'bank';

    public const TYPES = [
        self::TYPE_MOMO,
        self::TYPE_CARD,
        self::TYPE_BANK,
    ];

    public const MOMO_NETWORKS = ['MTN', 'Vodafone', 'AirtelTigo'];

    protected $fillable = [
        'user_id',
        'type',
        'label',
        'network',
        'last4',
        'exp',
        'holder',
        'details',
        'is_default',
    ];

    protected $casts = [
        // Encrypted at rest (APP_KEY) — full numbers never sit in plaintext.
        'details' => 'encrypted:array',
        'is_default' => 'boolean',
    ];

    protected $hidden = [
        // Never serialized; use safeArray() for API responses instead.
        'details',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    /**
     * Owner-safe representation: masked number + display fields only.
     */
    public function safeArray(): array
    {
        $details = $this->details ?? [];
        return [
            'id' => $this->id,
            'type' => $this->type,
            'label' => $this->label,
            'network' => $this->network,
            'last4' => $this->last4,
            'exp' => $this->exp,
            'holder' => $this->holder,
            'masked' => $this->maskedNumber(),
            'phone' => $this->type === self::TYPE_MOMO
                ? ($details['phone'] ?? null)
                : null,
            'is_default' => (bool) $this->is_default,
            'created_at' => optional($this->created_at)?->toIso8601String(),
        ];
    }

    public function maskedNumber(): ?string
    {
        if (!$this->last4) {
            return null;
        }
        return match ($this->type) {
            self::TYPE_CARD => '•••• •••• •••• ' . $this->last4,
            self::TYPE_BANK => '••••••' . $this->last4,
            default => '••••••' . $this->last4,
        };
    }

    public function fullNumber(): ?string
    {
        $details = $this->details ?? [];
        return $details['number'] ?? $details['phone'] ?? $details['account'] ?? null;
    }
}
