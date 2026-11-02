<?php

namespace App\Policies;

use App\Models\Role;
use App\Models\User;

class RolePolicy
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

    public function view(User $user, Role $role): bool
    {
        return $this->canManage($user);
    }

    public function create(User $user): bool
    {
        return $this->canManage($user);
    }

    public function update(User $user, Role $role): bool
    {
        return $this->canManage($user);
    }

    public function delete(User $user, Role $role): bool
    {
        if ($role->isProtected()) {
            return false;
        }

        return $this->canManage($user);
    }

    public function deleteAny(User $user): bool
    {
        return $this->canManage($user);
    }
}
