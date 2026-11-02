<?php

namespace App\Policies;

use App\Models\ActivityLog;
use App\Models\User;
use Throwable;

/**
 * Activity logs are visible to admins/super-admins or users with
 * the explicit "view activity logs" permission.
 *
 * Deletion requires "delete activity logs" (or super-admin).
 * Uses hasPermissionTo() inside the policy — not $user->can() —
 * so we never recurse through Gate while resolving this policy.
 */
class ActivityLogPolicy
{
    public const PERM_VIEW = 'view activity logs';

    public const PERM_DELETE = 'delete activity logs';

    public function viewAny(User $user): bool
    {
        return $this->canView($user);
    }

    public function view(User $user, ActivityLog $activityLog): bool
    {
        return $this->canView($user);
    }

    public function delete(User $user, ActivityLog $activityLog): bool
    {
        return $this->canDelete($user);
    }

    public function deleteAny(User $user): bool
    {
        return $this->canDelete($user);
    }

    private function canView(User $user): bool
    {
        if ($user->isSuperAdmin() || $user->isAdmin()) {
            return true;
        }

        return $this->hasPerm($user, self::PERM_VIEW);
    }

    private function canDelete(User $user): bool
    {
        // Super-admin always may purge logs
        if ($user->isSuperAdmin()) {
            return true;
        }

        // Anyone (admin or otherwise) with the explicit permission
        return $this->hasPerm($user, self::PERM_DELETE);
    }

    private function hasPerm(User $user, string $permission): bool
    {
        try {
            return $user->hasPermissionTo($permission, 'web')
                || $user->hasPermissionTo($permission);
        } catch (Throwable) {
            // Permission not registered yet
            return false;
        }
    }
}
