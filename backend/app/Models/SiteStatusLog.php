<?php
// app/Models/SiteStatusLog.php

namespace App\Models;

use App\Models\Site;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Auth;

class SiteStatusLog extends Model
{
    use HasFactory;

    protected $fillable = [
        'site_id',
        'user_id',
        'old_status',
        'new_status',
        'reason',
        'notes',
        'ip_address',
        'user_agent',
    ];

    protected $casts = [
        'created_at' => 'datetime',
    ];

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
    public function scopeByStatus($query, $status)
    {
        return $query->where('new_status', $status);
    }

    // Accessors
    public function getOldStatusLabelAttribute()
    {
        return ucwords(str_replace('_', ' ', $this->old_status ?? 'N/A'));
    }

    public function getNewStatusLabelAttribute()
    {
        return ucwords(str_replace('_', ' ', $this->new_status));
    }

    public function getStatusChangeAttribute()
    {
        if (!$this->old_status) {
            return "Set to {$this->new_status_label}";
        }
        return "Changed from {$this->old_status_label} to {$this->new_status_label}";
    }

    // Methods
    public static function logChange($site, $oldStatus, $newStatus, $reason = null)
    {
        return static::create([
            'site_id' => $site->id,
            'user_id' => Auth::id(),
            'old_status' => $oldStatus,
            'new_status' => $newStatus,
            'reason' => $reason,
            'ip_address' => request()->ip(),
            'user_agent' => request()->userAgent(),
        ]);
    }
}
