<?php

namespace App\Policies;

use App\Models\User;

/**
 * SiteDrop user policy (admin panel).
 */
class UserPolicy
{
    private function isPlatformAdmin(User $user): bool
    {
        return $user->isSuperAdmin()
            || $user->isAdmin()
            || $user->hasAnyRole(['super-admin', 'admin']);
    }

    public function viewAny(User $user): bool
    {
        return $this->isPlatformAdmin($user);
    }

    public function view(User $user, User $model): bool
    {
        if ($user->id === $model->id) {
            return true;
        }

        return $this->isPlatformAdmin($user);
    }

    public function create(User $user): bool
    {
        return $this->isPlatformAdmin($user);
    }

    public function update(User $user, User $model): bool
    {
        if ($user->id === $model->id) {
            return true;
        }

        return $this->isPlatformAdmin($user);
    }

    public function delete(User $user, User $model): bool
    {
        if ($user->id === $model->id || $model->isSuperAdmin()) {
            return false;
        }

        return $this->isPlatformAdmin($user);
    }

    public function deleteAny(User $user): bool
    {
        return $this->isPlatformAdmin($user);
    }

    public function manageRoles(User $user): bool
    {
        return $this->isPlatformAdmin($user);
    }

    /**
     * Whether the admin may impersonate users.
     *
     * - Class-level: can('impersonate', User::class) → only $authUser is passed
     * - Instance:    can('impersonate', $targetUser) → both args
     */
    public function impersonate(User $authUser, ?User $targetUser = null): bool
    {
        if (! $this->isPlatformAdmin($authUser)) {
            return false;
        }

        // General ability (no specific target)
        if ($targetUser === null) {
            return true;
        }

        if ($targetUser->id === $authUser->id || $targetUser->isSuperAdmin()) {
            return false;
        }

        return true;
    }
}
