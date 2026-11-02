<?php
// app/Models/PaymentMethod.php

namespace App\Models;

use App\Models\User;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class PaymentMethod extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'type', // mobile_money, bank, card, wallet
        'provider', // hubtel, paystack, etc.
        'account_name',
        'account_number',
        'phone_number',
        'bank_name',
        'card_last_four',
        'card_expiry',
        'is_default',
        'is_verified',
        'verification_data',
        'metadata',
    ];

    protected $casts = [
        'is_default' => 'boolean',
        'is_verified' => 'boolean',
        'verification_data' => 'array',
        'metadata' => 'array',
        'card_expiry' => 'date',
    ];

    // Relationships
    public function user()
    {
        return $this->belongsTo(User::class);
    }

    // Scopes
    public function scopeDefault($query)
    {
        return $query->where('is_default', true);
    }

    public function scopeVerified($query)
    {
        return $query->where('is_verified', true);
    }

    // Accessors
    public function getMaskedNumberAttribute()
    {
        if ($this->type === 'mobile_money') {
            return substr($this->phone_number, 0, 3) . '****' . substr($this->phone_number, -3);
        }
        if ($this->type === 'card') {
            return '**** **** **** ' . $this->card_last_four;
        }
        return '****' . substr($this->account_number, -4);
    }

    public function getLabelAttribute()
    {
        if ($this->type === 'mobile_money') {
            return $this->provider . ' (' . $this->phone_number . ')';
        }
        if ($this->type === 'card') {
            return $this->provider . ' (****' . $this->card_last_four . ')';
        }
        return $this->bank_name . ' (' . $this->masked_number . ')';
    }

    // Methods
    public function setDefault()
    {
        // Remove default from other payment methods
        $this->user->paymentMethods()->where('is_default', true)->update(['is_default' => false]);
        $this->update(['is_default' => true]);
    }
}
