<?php
// app/Models/SiteVisit.php

namespace App\Models;

use App\Enums\SiteVisitType;
use App\Enums\SiteVisitStatus;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class SiteVisit extends Model
{
    use HasFactory;

    protected $fillable = [
        'site_id',
        'user_id',
        'visitor_name',
        'visitor_phone',
        'visitor_email',
        'visit_date',
        'check_in_time',
        'check_out_time',
        'purpose',
        'notes',
        'status',
        'approved_by',
        'approved_at',
        'visitor_signature',
        'host_signature',
        'safety_briefing_completed',
        'ppe_provided',
        'temperature',
        'vehicle_registration',
        'visit_type', // scheduled, walk-in, emergency
    ];

    protected $casts = [
        'visit_date' => 'datetime',
        'check_in_time' => 'datetime',
        'check_out_time' => 'datetime',
        'approved_at' => 'datetime',
        'safety_briefing_completed' => 'boolean',
        'ppe_provided' => 'boolean',
        'temperature' => 'float',
    ];

    // Constants
    const STATUS_SCHEDULED = SiteVisitStatus::Scheduled->value;
    const STATUS_CHECKED_IN = SiteVisitStatus::CheckedIn->value;
    const STATUS_IN_PROGRESS = SiteVisitStatus::InProgress->value;
    const STATUS_COMPLETED = SiteVisitStatus::Completed->value;
    const STATUS_CANCELLED = SiteVisitStatus::Cancelled->value;
    const STATUS_REJECTED = SiteVisitStatus::Rejected->value;

    const VISIT_TYPE_SCHEDULED = SiteVisitType::Scheduled->value;
    const VISIT_TYPE_WALK_IN = SiteVisitType::WalkIn->value;
    const VISIT_TYPE_EMERGENCY = SiteVisitType::Emergency->value;

    // Relationships
    public function site()
    {
        return $this->belongsTo(Site::class);
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function approver()
    {
        return $this->belongsTo(User::class, 'approved_by');
    }

    // Scopes
    public function scopeScheduled($query)
    {
        return $query->where('status', self::STATUS_SCHEDULED);
    }

    public function scopeCheckedIn($query)
    {
        return $query->where('status', self::STATUS_CHECKED_IN);
    }

    public function scopeCompleted($query)
    {
        return $query->where('status', self::STATUS_COMPLETED);
    }

    public function scopeToday($query)
    {
        return $query->whereDate('visit_date', today());
    }

    // Accessors
    public function getStatusLabelAttribute()
    {
        return ucwords(str_replace('_', ' ', $this->status));
    }

    public function getVisitTypeLabelAttribute()
    {
        return ucwords(str_replace('-', ' ', $this->visit_type));
    }

    public function getDurationMinutesAttribute()
    {
        if ($this->check_in_time && $this->check_out_time) {
            return $this->check_in_time->diffInMinutes($this->check_out_time);
        }
        return null;
    }

    public function getIsActiveAttribute()
    {
        return in_array($this->status, [
            self::STATUS_CHECKED_IN,
            self::STATUS_IN_PROGRESS
        ]);
    }

    // Methods
    public function checkIn()
    {
        $this->update([
            'status' => self::STATUS_CHECKED_IN,
            'check_in_time' => now(),
        ]);
    }

    public function checkOut()
    {
        $this->update([
            'status' => self::STATUS_COMPLETED,
            'check_out_time' => now(),
        ]);
    }

    public function approve($userId)
    {
        $this->update([
            'status' => self::STATUS_SCHEDULED,
            'approved_by' => $userId,
            'approved_at' => now(),
        ]);
    }

    public function reject($reason = null)
    {
        $this->update([
            'status' => self::STATUS_REJECTED,
            'notes' => $reason,
        ]);
    }
}
