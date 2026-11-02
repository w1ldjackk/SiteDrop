<?php

namespace App\Models;

use Spatie\Permission\Models\Permission as SpatiePermission;

/**
 * SiteDrop permission model (Spatie) with optional section grouping.
 */
class Permission extends SpatiePermission
{
    protected $fillable = [
        'name',
        'section',
        'guard_name',
    ];

    protected $attributes = [
        'section' => 'General',
        'guard_name' => 'web',
    ];
}
