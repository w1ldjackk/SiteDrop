<?php

namespace App\Models;

use App\Enums\ActivityLogLevel;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\MorphTo;

class ActivityLog extends Model
{
    use HasFactory;

    public const LEVEL_INFO = ActivityLogLevel::Info->value;
    public const LEVEL_WARNING = ActivityLogLevel::Warning->value;
    public const LEVEL_CRITICAL = ActivityLogLevel::Critical->value;

    protected $fillable = [
        'user_id',
        'action',
        'description',
        'subject_type',
        'subject_id',
        'module',
        'level',
        'properties',
        'ip_address',
        'user_agent',
        'request_method',
        'request_url',
    ];

    protected $casts = [
        'properties' => 'array',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];

    // ====================== Relationships ======================

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function subject(): MorphTo
    {
        return $this->morphTo();
    }

    // ====================== Scopes ======================

    public function scopeForModule($query, ?string $module)
    {
        if ($module) {
            $query->where('module', $module);
        }

        return $query;
    }

    public function scopeForAction($query, ?string $action)
    {
        if ($action) {
            $query->where('action', $action);
        }

        return $query;
    }

    public function scopeForUser($query, $userId)
    {
        if ($userId) {
            $query->where('user_id', $userId);
        }

        return $query;
    }

    public function scopeSearch($query, ?string $term)
    {
        if (!$term) {
            return $query;
        }

        return $query->where(function ($q) use ($term) {
            $q->where('description', 'like', "%{$term}%")
                ->orWhere('action', 'like', "%{$term}%")
                ->orWhere('module', 'like', "%{$term}%")
                ->orWhereHas('user', function ($uq) use ($term) {
                    $uq->where('name', 'like', "%{$term}%")
                        ->orWhere('email', 'like', "%{$term}%")
                        ->orWhere('phone', 'like', "%{$term}%");
                });
        });
    }

    // ====================== Accessors ======================

    public function getActionLabelAttribute(): string
    {
        return ucwords(str_replace(['.', '_', '-'], ' ', $this->action));
    }

    public function getLevelColorAttribute(): string
    {
        return match ($this->level) {
            self::LEVEL_CRITICAL => 'red',
            self::LEVEL_WARNING => 'amber',
            default => 'slate',
        };
    }
}
