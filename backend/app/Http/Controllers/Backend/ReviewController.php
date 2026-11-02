<?php

namespace App\Http\Controllers\Backend;

use App\Http\Controllers\Concerns\ScopesByRoleArea;
use App\Http\Controllers\Controller;
use App\Models\Review;
use App\Services\Activity\ActivityLogger;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Inertia\Inertia;
use Inertia\Response;
use Throwable;

class ReviewController extends Controller
{
    use ScopesByRoleArea;

    public function index(Request $request): Response
    {
        $user = $request->user();
        $area = $this->roleAreaPrefix($request);
        $isAdminArea = $this->isAdminPanelUser($user);

        $query = Review::query()
            ->with([
                'reviewer:id,name',
                'reviewee:id,name',
                'product:id,name,seller_id',
                'order:id,order_number',
            ])
            ->latest();

        $this->scopeReviewsQuery($query, $user);

        // Non-admin: only show published (+ own pending) reviews by default
        if (! $isAdminArea && ! $request->filled('status')) {
            $query->where(function ($q) use ($user) {
                $q->where('status', Review::STATUS_PUBLISHED)
                    ->orWhere(function ($own) use ($user) {
                        $own->where('reviewer_id', $user?->id)
                            ->whereIn('status', [
                                Review::STATUS_PENDING,
                                Review::STATUS_PUBLISHED,
                            ]);
                    });
            });
        }

        if ($search = $request->input('search')) {
            $query->where(function ($q) use ($search) {
                $q->where('comment', 'like', "%{$search}%")
                    ->orWhereHas('reviewer', fn ($u) => $u->where('name', 'like', "%{$search}%"))
                    ->orWhereHas('product', fn ($p) => $p->where('name', 'like', "%{$search}%"));
            });
        }

        if ($status = $request->input('status')) {
            $query->where('status', $status);
        }

        if ($type = $request->input('type')) {
            $query->where('type', $type);
        }

        $reviews = $query->paginate((int) $request->input('per_page', 15))
            ->withQueryString()
            ->through(fn (Review $r) => [
                'id' => $r->id,
                'rating' => $r->rating,
                'comment' => $r->comment,
                'type' => $r->type instanceof \BackedEnum ? $r->type->value : (string) $r->type,
                'status' => $r->status instanceof \BackedEnum ? $r->status->value : (string) $r->status,
                'is_verified_purchase' => (bool) $r->is_verified_purchase,
                'helpful_count' => $r->helpful_count,
                'reported_count' => $r->reported_count,
                'reviewer' => $r->reviewer
                    ? ['id' => $r->reviewer->id, 'name' => $r->reviewer->name]
                    : null,
                'reviewee' => $r->reviewee
                    ? ['id' => $r->reviewee->id, 'name' => $r->reviewee->name]
                    : null,
                'product' => $r->product
                    ? ['id' => $r->product->id, 'name' => $r->product->name]
                    : null,
                'order' => $r->order
                    ? ['id' => $r->order->id, 'order_number' => $r->order->order_number]
                    : null,
                'created_at' => optional($r->created_at)?->toDateTimeString(),
            ]);

        $canModerate = $isAdminArea && $user && (
            $user->isSuperAdmin()
            || $user->isAdmin()
            || $this->hasPerm($user, 'moderate reviews')
        );
        $canDelete = $isAdminArea && $this->userCanDeleteReviews($user);

        return Inertia::render('backend/Reviews/index', [
            'reviews' => $reviews,
            'filters' => $request->only(['search', 'status', 'type']),
            'area' => $area,
            'statuses' => $isAdminArea
                ? [
                    Review::STATUS_PENDING,
                    Review::STATUS_PUBLISHED,
                    Review::STATUS_HIDDEN,
                    Review::STATUS_REPORTED,
                ]
                : [
                    Review::STATUS_PUBLISHED,
                    Review::STATUS_PENDING,
                ],
            'can' => [
                'delete' => $canDelete,
                'moderate' => $canModerate,
            ],
        ]);
    }

    public function update(Request $request, int $id): RedirectResponse
    {
        $user = $request->user();
        abort_unless(
            $this->isAdminPanelUser($user)
            && (
                $user->isSuperAdmin()
                || $user->isAdmin()
                || $this->hasPerm($user, 'moderate reviews')
            ),
            403,
            'You do not have permission to moderate reviews.'
        );

        $review = Review::findOrFail($id);

        $data = $request->validate([
            'status' => ['required', 'string', 'in:pending,published,hidden,reported'],
        ]);

        $review->update($data);

        return back()->with('success', 'Review updated.');
    }

    /**
     * Permanently remove a review (admin moderation).
     */
    public function destroy(Request $request, int $id): RedirectResponse
    {
        $user = $request->user();

        if (! $this->userCanDeleteReviews($user)) {
            abort(403, 'You do not have permission to delete reviews.');
        }

        $review = Review::findOrFail($id);

        $snapshot = [
            'id' => $review->id,
            'rating' => $review->rating,
            'type' => $review->type,
            'status' => $review->status,
            'reviewer_id' => $review->reviewer_id,
            'product_id' => $review->product_id,
            'comment' => mb_substr((string) $review->comment, 0, 200),
        ];

        $review->delete();

        ActivityLogger::log(
            'review.deleted',
            'Admin deleted review #' . $snapshot['id'],
            null,
            $snapshot,
            level: \App\Models\ActivityLog::LEVEL_WARNING,
            module: 'reviews',
            userId: Auth::id(),
        );

        return back()->with('success', 'Review deleted.');
    }

    /**
     * Bulk delete selected reviews.
     */
    public function bulkDelete(Request $request): RedirectResponse
    {
        if (! $this->userCanDeleteReviews($request->user())) {
            abort(403, 'You do not have permission to delete reviews.');
        }

        $data = $request->validate([
            'ids' => ['required', 'array', 'min:1'],
            'ids.*' => ['integer', 'exists:reviews,id'],
        ]);

        $ids = $data['ids'];
        $count = Review::whereIn('id', $ids)->delete();

        ActivityLogger::log(
            'review.bulk_deleted',
            "Admin deleted {$count} review(s)",
            null,
            ['ids' => $ids, 'count' => $count],
            level: \App\Models\ActivityLog::LEVEL_WARNING,
            module: 'reviews',
            userId: Auth::id(),
        );

        return back()->with('success', "{$count} review(s) deleted.");
    }

    private function userCanDeleteReviews($user): bool
    {
        if (! $user) {
            return false;
        }

        if ($user->isSuperAdmin() || $user->isAdmin()) {
            return true;
        }

        return $this->hasPerm($user, 'delete reviews')
            || $this->hasPerm($user, 'moderate reviews');
    }

    private function hasPerm($user, string $permission): bool
    {
        try {
            return $user->hasPermissionTo($permission, 'web')
                || $user->hasPermissionTo($permission);
        } catch (Throwable) {
            return false;
        }
    }
}
