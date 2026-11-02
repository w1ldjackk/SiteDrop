<?php

namespace App\Models;

use Spatie\Permission\Models\Role as SpatieRole;
use Spatie\Permission\PermissionRegistrar;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;

/**
 * SiteDrop role model (Spatie).
 * Pivot tables come from config/permission.php (model_roles, role_permissions).
 */
class Role extends SpatieRole
{
    protected $fillable = [
        'name',
        'guard_name',
    ];

    /** Roles that cannot be deleted from the admin UI. */
    public const PROTECTED = [
        'super-admin',
        'admin',
    ];

    public function isProtected(): bool
    {
        return in_array($this->name, self::PROTECTED, true);
    }

    /**
     * Users assigned this role.
     *
     * Spatie's default users() uses getModelForGuard(), which can resolve to null
     * when the relation is built on an empty model instance (e.g. withCount).
     * Pin to App\Models\User for the web guard.
     */
    public function users(): BelongsToMany
    {
        $registrar = app(PermissionRegistrar::class);

        return $this->morphedByMany(
            User::class,
            'model',
            config('permission.table_names.model_has_roles'),
            $registrar->pivotRole,
            config('permission.column_names.model_morph_key')
        );
    }
}
