<?php
// app/Models/TruckDocument.php

namespace App\Models;

use App\Enums\TruckDocumentStatus;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class TruckDocument extends Model
{
    use HasFactory;

    protected $fillable = [
        'truck_id',
        'user_id',
        'document_type',
        'title',
        'description',
        'file_path',
        'file_name',
        'file_size',
        'file_extension',
        'document_number',
        'issue_date',
        'expiry_date',
        'status',
        'verified_by',
        'verified_at',
        'is_required',
        'notes',
    ];

    protected $casts = [
        'file_size' => 'integer',
        'issue_date' => 'datetime',
        'expiry_date' => 'datetime',
        'verified_at' => 'datetime',
        'is_required' => 'boolean',
    ];

    // Constants
    const DOCUMENT_TYPE_INSURANCE = 'insurance';
    const DOCUMENT_TYPE_REGISTRATION = 'registration';
    const DOCUMENT_TYPE_ROAD_WORTHY = 'road_worthy';
    const DOCUMENT_TYPE_PERMIT = 'permit';
    const DOCUMENT_TYPE_INSPECTION = 'inspection';
    const DOCUMENT_TYPE_LICENSE = 'license';
    const DOCUMENT_TYPE_OTHER = 'other';

    const STATUS_PENDING = TruckDocumentStatus::Pending->value;
    const STATUS_ACTIVE = TruckDocumentStatus::Active->value;
    const STATUS_EXPIRED = TruckDocumentStatus::Expired->value;
    const STATUS_REJECTED = TruckDocumentStatus::Rejected->value;

    // Relationships
    public function truck()
    {
        return $this->belongsTo(Truck::class);
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function verifier()
    {
        return $this->belongsTo(User::class, 'verified_by');
    }

    // Scopes
    public function scopeActive($query)
    {
        return $query->where('status', self::STATUS_ACTIVE);
    }

    public function scopePending($query)
    {
        return $query->where('status', self::STATUS_PENDING);
    }

    public function scopeExpired($query)
    {
        return $query->where('status', self::STATUS_EXPIRED)
            ->orWhere('expiry_date', '<', now());
    }

    public function scopeByType($query, $type)
    {
        return $query->where('document_type', $type);
    }

    // Accessors
    public function getDocumentTypeLabelAttribute()
    {
        return ucwords(str_replace('_', ' ', $this->document_type));
    }

    public function getStatusLabelAttribute()
    {
        return ucwords(str_replace('_', ' ', $this->status));
    }

    public function getFormattedFileSizeAttribute()
    {
        $bytes = $this->file_size;
        if ($bytes >= 1048576) {
            return number_format($bytes / 1048576, 2) . ' MB';
        } elseif ($bytes >= 1024) {
            return number_format($bytes / 1024, 2) . ' KB';
        }
        return $bytes . ' bytes';
    }

    public function getIsExpiredAttribute()
    {
        if (!$this->expiry_date) {
            return false;
        }
        return $this->expiry_date < now();
    }

    public function getDaysToExpiryAttribute()
    {
        if (!$this->expiry_date) {
            return null;
        }
        return now()->diffInDays($this->expiry_date, false);
    }

    // Methods
    public function verify($userId)
    {
        $this->update([
            'status' => self::STATUS_ACTIVE,
            'verified_by' => $userId,
            'verified_at' => now(),
        ]);
    }

    public function reject($reason = null)
    {
        $this->update([
            'status' => self::STATUS_REJECTED,
            'notes' => $reason,
        ]);
    }

    public function isExpired(): bool
    {
        return $this->status === self::STATUS_EXPIRED || $this->getIsExpiredAttribute();
    }

    public function isVerified(): bool
    {
        return $this->status === self::STATUS_ACTIVE && !$this->isExpired();
    }
}
