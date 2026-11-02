<?php

namespace App\Traits;

use App\Enums\UserRole;

/**
 * Spatie role helpers + legacy users.role column support.
 * Expects the host model to use Spatie HasRoles (hasRole / getRoleNames).
 *
 * @property string|null $role
 */
trait HasAppRoles
{
    /**
     * First assigned Spatie role name (source of truth).
     * Falls back to denormalized users.role only when pivots are empty (legacy rows).
     */
    public function primaryRoleName(): ?string
    {
        $fromSpatie = $this->getRoleNames()->first();

        return $fromSpatie ?: ($this->role ?: null);
    }

    /**
     * Post-login / “home” path for this user.
     *
     * - super-admin & admin → /admin
     * - everyone else → /{role} (e.g. /seller, /buyer, /driver)
     */
    public function homePath(): string
    {
        if ($this->isAdmin()) {
            return UserRole::Admin->homePath();
        }

        $role = $this->primaryRoleName() ?: UserRole::Buyer->value;
        $enum = UserRole::tryFromMixed($role);
        if ($enum) {
            return $enum->homePath();
        }

        $slug = strtolower(str_replace([' ', '_'], '-', $role));

        return '/'.$slug;
    }

    /**
     * Mirror the first Spatie role onto users.role (legacy column).
     * Call after assignRole / syncRoles / removeRole when needed.
     */
    public function mirrorRoleColumn(): void
    {
        $name = $this->getRoleNames()->first();
        if ($name && $this->role !== $name) {
            $this->forceFill(['role' => $name])->saveQuietly();
        }
    }

    public function isBuyer(): bool
    {
        return $this->hasAppRole(UserRole::Buyer->value);
    }

    public function isSeller(): bool
    {
        return $this->hasAppRole(UserRole::Seller->value);
    }

    public function isDriver(): bool
    {
        return $this->hasAppRole(UserRole::Driver->value);
    }

    public function isAdmin(): bool
    {
        return $this->isSuperAdmin()
            || $this->hasAppRole(UserRole::Admin->value)
            || $this->hasAppRole(UserRole::OpsManager->value);
    }

    public function isSuperAdmin(): bool
    {
        return $this->hasAppRole(UserRole::SuperAdmin->value);
    }

    public function isOpsManager(): bool
    {
        return $this->hasAppRole(UserRole::OpsManager->value);
    }

    /**
     * Whether this user may access a role area (Spatie roles + legacy users.role).
     * "admin" matches super-admin, admin, and ops-manager.
     */
    public function hasAppRole(string $role): bool
    {
        $slug = strtolower(str_replace([' ', '_'], '-', trim($role)));

        if ($slug === 'super-admin') {
            return $this->hasRole(UserRole::SuperAdmin->value)
                || $this->role === UserRole::SuperAdmin->value;
        }

        if ($slug === 'ops-manager') {
            return $this->hasRole(UserRole::OpsManager->value)
                || $this->hasRole('ops_manager')
                || $this->hasRole('ops manager')
                || $this->role === UserRole::OpsManager->value
                || $this->role === 'ops_manager';
        }

        if ($slug === '' || $slug === 'admin') {
            return $this->hasRole(UserRole::Admin->value)
                || $this->hasRole(UserRole::SuperAdmin->value)
                || $this->hasRole(UserRole::OpsManager->value)
                || $this->hasRole('ops_manager')
                || $this->role === UserRole::Admin->value
                || $this->role === UserRole::SuperAdmin->value
                || $this->role === UserRole::OpsManager->value
                || $this->role === 'ops_manager';
        }

        $candidates = array_unique([
            $slug,
            str_replace('-', ' ', $slug),
            str_replace('-', '_', $slug),
        ]);

        foreach ($candidates as $name) {
            if ($this->hasRole($name)) {
                return true;
            }
        }

        if ($this->role) {
            $legacy = strtolower(str_replace([' ', '_'], '-', $this->role));

            return $legacy === $slug;
        }

        return false;
    }

    /**
     * URL path prefix for this user's primary area (/admin, /buyer, …).
     */
    public function rolePrefix(): string
    {
        return rtrim($this->homePath(), '/') ?: '/buyer';
    }

    /**
     * Account settings path under the user's role area.
     * e.g. /buyer/settings/profile, /admin/settings/password
     */
    public function settingsPath(string $page = 'profile'): string
    {
        $page = trim($page, '/') ?: 'profile';

        return $this->rolePrefix().'/settings/'.$page;
    }

    /**
     * Named settings route for this user (e.g. buyer.profile.edit).
     */
    public function settingsRoute(string $action = 'profile.edit'): string
    {
        $area = ltrim($this->rolePrefix(), '/');

        return $area.'.'.$action;
    }
}
