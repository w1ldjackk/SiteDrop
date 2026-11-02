<?php
// app/Models/SiteDocument.php

namespace App\Models;

use App\Enums\SiteDocumentAccess;
use App\Enums\SiteDocumentStatus;
use App\Enums\SiteDocumentType;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class SiteDocument extends Model
{
    use HasFactory;

    protected $fillable = [
        'site_id',
        'user_id',
        'title',
        'description',
        'document_type',
        'file_path',
        'file_name',
        'file_size',
        'file_extension',
        'version',
        'status',
        'expiry_date',
        'uploaded_by',
        'approved_by',
        'approved_at',
        'tags',
        'is_confidential',
        'access_level', // public, private, restricted
    ];

    protected $casts = [
        'file_size' => 'integer',
        'expiry_date' => 'datetime',
        'approved_at' => 'datetime',
        'is_confidential' => 'boolean',
        'tags' => 'array',
    ];

    // Constants
    const DOCUMENT_TYPE_PERMIT = SiteDocumentType::Permit->value;
    const DOCUMENT_TYPE_CONTRACT = SiteDocumentType::Contract->value;
    const DOCUMENT_TYPE_BLUEPRINT = SiteDocumentType::Blueprint->value;
    const DOCUMENT_TYPE_REPORT = SiteDocumentType::Report->value;
    const DOCUMENT_TYPE_INVOICE = SiteDocumentType::Invoice->value;
    const DOCUMENT_TYPE_INSURANCE = SiteDocumentType::Insurance->value;
    const DOCUMENT_TYPE_CERTIFICATE = SiteDocumentType::Certificate->value;
    const DOCUMENT_TYPE_OTHER = SiteDocumentType::Other->value;

    const STATUS_DRAFT = SiteDocumentStatus::Draft->value;
    const STATUS_ACTIVE = SiteDocumentStatus::Active->value;
    const STATUS_ARCHIVED = SiteDocumentStatus::Archived->value;
    const STATUS_EXPIRED = SiteDocumentStatus::Expired->value;
    const STATUS_REJECTED = SiteDocumentStatus::Rejected->value;

    const ACCESS_PUBLIC = SiteDocumentAccess::Public->value;
    const ACCESS_PRIVATE = SiteDocumentAccess::Private->value;
    const ACCESS_RESTRICTED = SiteDocumentAccess::Restricted->value;

    // Relationships
    public function site()
    {
        return $this->belongsTo(Site::class);
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function uploader()
    {
        return $this->belongsTo(User::class, 'uploaded_by');
    }

    public function approver()
    {
        return $this->belongsTo(User::class, 'approved_by');
    }

    // Scopes
    public function scopeActive($query)
    {
        return $query->where('status', self::STATUS_ACTIVE);
    }

    public function scopeByType($query, $type)
    {
        return $query->where('document_type', $type);
    }

    public function scopePublic($query)
    {
        return $query->where('access_level', self::ACCESS_PUBLIC);
    }

    public function scopeConfidential($query)
    {
        return $query->where('is_confidential', true);
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
        return $this->expiry_date && $this->expiry_date < now();
    }

    // Methods
    public function approve($userId)
    {
        $this->update([
            'status' => self::STATUS_ACTIVE,
            'approved_by' => $userId,
            'approved_at' => now(),
        ]);
    }

    public function archive()
    {
        $this->update(['status' => self::STATUS_ARCHIVED]);
    }

    public function isAccessibleBy(User $user): bool
    {
        if ($this->access_level === self::ACCESS_PUBLIC) {
            return true;
        }

        if ($user->isAdmin()) {
            return true;
        }

        if ($this->site->user_id === $user->id) {
            return true;
        }

        return false;
    }
}
