<?php

namespace App\Policies;

use App\Models\Report;
use App\Models\User;

/**
 * SiteDrop reports (sales, orders, deliveries, etc.).
 */
class ReportPolicy
{
    private function isAdmin(User $user): bool
    {
        return $user->isSuperAdmin()
            || $user->isAdmin()
            || $user->hasAnyRole(['super-admin', 'admin']);
    }

    public function viewAny(User $user): bool
    {
        return $this->isAdmin($user) || $user->can('view reports');
    }

    public function view(User $user, Report $report): bool
    {
        if ($this->isAdmin($user) || $user->can('view reports')) {
            return true;
        }

        // Owner can view their own generated report
        return (int) $report->user_id === (int) $user->id;
    }

    public function create(User $user): bool
    {
        return $this->isAdmin($user) || $user->can('view reports');
    }

    public function update(User $user, Report $report): bool
    {
        return $this->isAdmin($user);
    }

    public function delete(User $user, Report $report): bool
    {
        return $this->isAdmin($user);
    }

    public function deleteAny(User $user): bool
    {
        return $this->isAdmin($user);
    }

    public function export(User $user, Report $report): bool
    {
        return $this->isAdmin($user) || $user->can('export reports');
    }
}
