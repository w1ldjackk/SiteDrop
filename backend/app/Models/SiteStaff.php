<?php
// app/Models/SiteStaff.php

namespace App\Models;

use App\Enums\SiteStaffRole;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class SiteStaff extends Model
{
    use HasFactory;

    protected $fillable = [
        'site_id',
        'user_id',
        'role',
        'department',
        'position',
        'start_date',
        'end_date',
        'is_active',
        'shift_schedule',
        'contact_emergency',
        'notes',
        'certifications',
        'skills',
        'performance_rating',
        'last_performance_review',
    ];

    protected $casts = [
        'start_date' => 'datetime',
        'end_date' => 'datetime',
        'is_active' => 'boolean',
        'shift_schedule' => 'array',
        'certifications' => 'array',
        'skills' => 'array',
        'performance_rating' => 'float',
        'last_performance_review' => 'datetime',
    ];

    // Constants
    const ROLE_SITE_MANAGER = SiteStaffRole::SiteManager->value;
    const ROLE_SUPERVISOR = SiteStaffRole::Supervisor->value;
    const ROLE_FOREMAN = SiteStaffRole::Foreman->value;
    const ROLE_SAFETY_OFFICER = SiteStaffRole::SafetyOfficer->value;
    const ROLE_QUALITY_CONTROL = SiteStaffRole::QualityControl->value;
    const ROLE_OPERATOR = SiteStaffRole::Operator->value;
    const ROLE_LABORER = SiteStaffRole::Laborer->value;
    const ROLE_OTHER = SiteStaffRole::Other->value;

    // Relationships
    public function site()
    {
        return $this->belongsTo(Site::class);
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    // Scopes
    public function scopeActive($query)
    {
        return $query->where('is_active', true);
    }

    public function scopeByRole($query, $role)
    {
        return $query->where('role', $role);
    }

    // Accessors
    public function getRoleLabelAttribute()
    {
        return ucwords(str_replace('_', ' ', $this->role));
    }

    public function getIsCurrentlyActiveAttribute()
    {
        return $this->is_active && (!$this->end_date || $this->end_date > now());
    }

    public function getFullNameAttribute()
    {
        return $this->user ? $this->user->name : null;
    }

    // Methods
    public function assignRole($role)
    {
        $this->update(['role' => $role]);
    }

    public function updatePerformanceRating($rating)
    {
        $this->update([
            'performance_rating' => $rating,
            'last_performance_review' => now(),
        ]);
    }

    public function isSiteManager(): bool
    {
        return $this->role === self::ROLE_SITE_MANAGER;
    }
}
