<?php
// app/Models/Setting.php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Setting extends Model
{
    protected $fillable = [
        'user_id',
        'name',
        'val',
        'type',
    ];

    // Common keys
    public const KEY_THEME_MODE = 'theme_mode'; // system | light | dark

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    // ============================================================
    // GLOBAL (app-wide) helpers — same API as webdataplug Setting
    // ============================================================

    public static function get($key, $default = null, ?string $type = null)
    {
        $row = static::whereNull('user_id')
            ->where('name', $key)
            ->first();

        if (!$row) {
            return $default;
        }

        return static::castValue($row->val, $type ?? $row->type ?? 'string');
    }

    public static function set($key, $value, $type = 'string')
    {
        return static::updateOrCreate(
            ['user_id' => null, 'name' => $key],
            ['val' => static::serializeValue($value, $type), 'type' => $type]
        );
    }

    // ============================================================
    // PER-USER helpers
    // ============================================================

    public static function getForUser(int $userId, string $key, $default = null)
    {
        $row = static::where('user_id', $userId)
            ->where('name', $key)
            ->first();

        if (!$row) {
            return $default;
        }

        return static::castValue($row->val, $row->type);
    }

    public static function setForUser(int $userId, string $key, $value, string $type = 'string')
    {
        return static::updateOrCreate(
            ['user_id' => $userId, 'name' => $key],
            ['val' => static::serializeValue($value, $type), 'type' => $type]
        );
    }

    /**
     * All settings for a user as [name => cast value].
     */
    public static function allForUser(int $userId): array
    {
        $rows = static::where('user_id', $userId)->get();
        $out = [];
        foreach ($rows as $row) {
            $out[$row->name] = static::castValue($row->val, $row->type);
        }

        return $out;
    }

    public static function castValue(?string $val, string $type)
    {
        if ($val === null) {
            return null;
        }

        return match ($type) {
            'boolean', 'bool' => filter_var($val, FILTER_VALIDATE_BOOLEAN),
            'integer', 'int' => (int) $val,
            'float', 'double' => (float) $val,
            'json', 'array' => json_decode($val, true),
            default => $val,
        };
    }

    public static function serializeValue($value, string $type): ?string
    {
        if ($value === null) {
            return null;
        }

        return match ($type) {
            'boolean', 'bool' => $value ? '1' : '0',
            'json', 'array' => is_string($value) ? $value : json_encode($value),
            default => (string) $value,
        };
    }
}
