<?php

namespace App\Policies;

use App\Models\Permission;
use App\Models\User;

class PermissionPolicy
{
    private function canManage(User $user): bool
    {
        return $user->isSuperAdmin()
            || $user->isAdmin()
            || $user->hasAnyRole(['super-admin', 'admin']);
    }

    public function viewAny(User $user): bool
    {
        return $this->canManage($user);
    }

    public function view(User $user, Permission $permission): bool
    {
        return $this->canManage($user);
    }

    public function create(User $user): bool
    {
        return $this->canManage($user);
    }

    public function update(User $user, Permission $permission): bool
    {
        return $this->canManage($user);
    }

    public function delete(User $user, Permission $permission): bool
    {
        // Only super-admin may remove permission definitions
        return $user->isSuperAdmin() || $user->hasRole('super-admin');
    }

    public function deleteAny(User $user): bool
    {
        return $user->isSuperAdmin() || $user->hasRole('super-admin');
    }
}
