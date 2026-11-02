<?php

namespace App\Http\Controllers\Concerns;

use App\Models\User;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\Request;

/**
 * Shared helpers for admin/buyer/seller/driver web areas.
 */
trait ScopesByRoleArea
{
    protected function roleAreaPrefix(Request $request): string
    {
        $segment = explode('/', trim($request->path(), '/'))[0] ?? 'admin';

        return in_array($segment, ['admin', 'buyer', 'seller', 'driver'], true)
            ? $segment
            : 'admin';
    }

    protected function roleAreaUrl(Request $request, string $path = ''): string
    {
        $base = '/'.$this->roleAreaPrefix($request);
        $path = ltrim($path, '/');

        return $path === '' ? $base : $base.'/'.$path;
    }

    protected function isAdminPanelUser(?User $user): bool
    {
        return (bool) ($user && $user->isAdmin());
    }

    /**
     * Scope orders to the current role area.
     */
    protected function scopeOrdersQuery(Builder $query, ?User $user): Builder
    {
        if (! $user || $this->isAdminPanelUser($user)) {
            return $query;
        }

        if ($user->isBuyer()) {
            return $query->where('buyer_id', $user->id);
        }

        if ($user->isSeller()) {
            return $query->where('seller_id', $user->id);
        }

        if ($user->isDriver()) {
            return $query->whereHas(
                'delivery',
                fn (Builder $d) => $d->where('driver_id', $user->id)
            );
        }

        return $query->whereRaw('1 = 0');
    }

    /**
     * Scope products: sellers → own; buyers → available catalog; drivers → none.
     */
    protected function scopeProductsQuery(Builder $query, ?User $user): Builder
    {
        if (! $user || $this->isAdminPanelUser($user)) {
            return $query;
        }

        if ($user->isSeller()) {
            return $query->where('seller_id', $user->id);
        }

        if ($user->isBuyer()) {
            return $query->where('is_available', true);
        }

        return $query->whereRaw('1 = 0');
    }

    /**
     * Scope deliveries by role.
     */
    protected function scopeDeliveriesQuery(Builder $query, ?User $user): Builder
    {
        if (! $user || $this->isAdminPanelUser($user)) {
            return $query;
        }

        if ($user->isDriver()) {
            return $query->where('driver_id', $user->id);
        }

        if ($user->isBuyer()) {
            return $query->whereHas(
                'order',
                fn (Builder $o) => $o->where('buyer_id', $user->id)
            );
        }

        if ($user->isSeller()) {
            return $query->whereHas(
                'order',
                fn (Builder $o) => $o->where('seller_id', $user->id)
            );
        }

        return $query->whereRaw('1 = 0');
    }

    /**
     * Scope payments by role.
     */
    protected function scopePaymentsQuery(Builder $query, ?User $user): Builder
    {
        if (! $user || $this->isAdminPanelUser($user)) {
            return $query;
        }

        if ($user->isBuyer()) {
            return $query->where('user_id', $user->id);
        }

        if ($user->isSeller()) {
            return $query->whereHas(
                'order',
                fn (Builder $o) => $o->where('seller_id', $user->id)
            );
        }

        return $query->whereRaw('1 = 0');
    }

    /**
     * Scope reviews by role.
     */
    protected function scopeReviewsQuery(Builder $query, ?User $user): Builder
    {
        if (! $user || $this->isAdminPanelUser($user)) {
            return $query;
        }

        if ($user->isBuyer()) {
            return $query->where(function (Builder $q) use ($user) {
                $q->where('reviewer_id', $user->id)
                    ->orWhere('reviewee_id', $user->id);
            });
        }

        if ($user->isSeller()) {
            return $query->where(function (Builder $q) use ($user) {
                $q->where('reviewer_id', $user->id)
                    ->orWhere('reviewee_id', $user->id)
                    // Products owned by this seller (seller_id is the user id)
                    ->orWhereHas(
                        'product',
                        fn (Builder $p) => $p->where('seller_id', $user->id)
                    );
            });
        }

        // Drivers and other roles: no review list access
        return $query->whereRaw('1 = 0');
    }
}
