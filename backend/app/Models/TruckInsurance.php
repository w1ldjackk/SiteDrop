<?php
// app/Models/TruckInsurance.php

namespace App\Models;

use App\Enums\TruckInsuranceStatus;
use App\Enums\TruckInsuranceType;
use App\Models\Truck;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Log;

class TruckInsurance extends Model
{
    use HasFactory;

    // Migration uses the singular table name (also referenced in
    // TruckController validation rules).
    protected $table = 'truck_insurance';

    protected $fillable = [
        'truck_id',
        'policy_number',
        'insurance_company',
        'type',
        'coverage_start_date',
        'coverage_end_date',
        'premium_amount',
        'premium_currency',
        'payment_frequency',
        'status',
        'coverage_details',
        'exclusions',
        'beneficiary_name',
        'beneficiary_relationship',
        'document_path',
        'agent_name',
        'agent_phone',
        'agent_email',
        'claim_contact',
        'last_claim_date',
        'claim_count',
        'notes',
    ];

    protected $casts = [
        'coverage_start_date' => 'datetime',
        'coverage_end_date' => 'datetime',
        'premium_amount' => 'float',
        'coverage_details' => 'array',
        'exclusions' => 'array',
        'last_claim_date' => 'datetime',
        'claim_count' => 'integer',
    ];

    // Constants
    const TYPE_COMPREHENSIVE = TruckInsuranceType::Comprehensive->value;
    const TYPE_THIRD_PARTY = TruckInsuranceType::ThirdParty->value;
    const TYPE_MOTOR_ACCIDENT = TruckInsuranceType::MotorAccident->value;
    const TYPE_FIRE_THEFT = TruckInsuranceType::FireTheft->value;
    const TYPE_PUBLIC_LIABILITY = TruckInsuranceType::PublicLiability->value;
    const TYPE_GOODS_TRANSIT = TruckInsuranceType::GoodsTransit->value;
    const TYPE_OTHER = TruckInsuranceType::Other->value;

    const PAYMENT_FREQUENCY_MONTHLY = 'monthly';
    const PAYMENT_FREQUENCY_QUARTERLY = 'quarterly';
    const PAYMENT_FREQUENCY_BIANNUALLY = 'biannually';
    const PAYMENT_FREQUENCY_ANNUALLY = 'annually';

    const STATUS_ACTIVE = TruckInsuranceStatus::Active->value;
    const STATUS_EXPIRED = TruckInsuranceStatus::Expired->value;
    const STATUS_CANCELLED = TruckInsuranceStatus::Cancelled->value;
    const STATUS_PENDING = TruckInsuranceStatus::Pending->value;
    const STATUS_SUSPENDED = TruckInsuranceStatus::Suspended->value;

    // Relationships
    public function truck()
    {
        return $this->belongsTo(Truck::class);
    }

    // Scopes
    public function scopeActive($query)
    {
        return $query->where('status', self::STATUS_ACTIVE);
    }

    public function scopeExpired($query)
    {
        return $query->where('status', self::STATUS_EXPIRED);
    }

    public function scopeByType($query, $type)
    {
        return $query->where('type', $type);
    }

    public function scopeExpiringSoon($query, $days = 30)
    {
        return $query->where('status', self::STATUS_ACTIVE)
            ->where('coverage_end_date', '<=', now()->addDays($days))
            ->where('coverage_end_date', '>=', now());
    }

    // Accessors
    public function getTypeLabelAttribute()
    {
        return ucwords(str_replace('_', ' ', $this->type));
    }

    public function getStatusLabelAttribute()
    {
        return ucwords(str_replace('_', ' ', $this->status));
    }

    public function getPaymentFrequencyLabelAttribute()
    {
        return ucwords(str_replace('_', ' ', $this->payment_frequency));
    }

    public function getFormattedPremiumAttribute()
    {
        return $this->premium_currency . ' ' . number_format($this->premium_amount, 2);
    }

    public function getDaysToExpiryAttribute()
    {
        if (!$this->coverage_end_date) {
            return null;
        }
        return now()->diffInDays($this->coverage_end_date, false);
    }

    public function getIsActiveAttribute()
    {
        return $this->status === self::STATUS_ACTIVE &&
            $this->coverage_end_date &&
            $this->coverage_end_date > now();
    }

    public function getIsExpiringSoonAttribute()
    {
        if (!$this->coverage_end_date || !$this->isActive) {
            return false;
        }
        return $this->coverage_end_date <= now()->addDays(30);
    }

    // Methods
    public function renew($newEndDate, $premiumAmount = null)
    {
        $this->update([
            'coverage_end_date' => $newEndDate,
            'premium_amount' => $premiumAmount ?? $this->premium_amount,
            'status' => self::STATUS_ACTIVE,
        ]);
    }

    public function cancel($reason = null)
    {
        $this->update([
            'status' => self::STATUS_CANCELLED,
            'notes' => $reason,
        ]);
    }

    public function recordClaim($date, $amount, $description = null)
    {
        $this->update([
            'claim_count' => $this->claim_count + 1,
            'last_claim_date' => $date,
        ]);

        // Log claim (you may want to create a separate Claim model)
        Log::info('Insurance claim recorded', [
            'truck_id' => $this->truck_id,
            'policy_number' => $this->policy_number,
            'amount' => $amount,
            'date' => $date,
            'description' => $description,
        ]);
    }

    public function isExpired(): bool
    {
        return $this->status === self::STATUS_EXPIRED ||
            ($this->coverage_end_date && $this->coverage_end_date < now());
    }
}
