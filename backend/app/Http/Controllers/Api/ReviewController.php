<?php
// app/Http/Controllers/Api/ReviewController.php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Review;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class ReviewController extends Controller
{
    /**
     * My reviews (reviewer = me): products + orders/trips in one feed.
     * GET /reviews/mine
     */
    public function mine(Request $request): JsonResponse
    {
        $user = Auth::user();
        $perPage = min(max((int) $request->get('per_page', 20), 1), 50);

        $paginator = Review::query()
            ->where('reviewer_id', $user->id)
            ->with([
                'product:id,name',
                'order:id,order_number,status',
                'reviewee:id,name',
            ])
            ->latest()
            ->paginate($perPage);

        $items = collect($paginator->items())->map(fn (Review $review) => [
            'id' => $review->id,
            'type' => $review->type,
            'rating' => (int) $review->rating,
            'comment' => $review->comment,
            'status' => $review->status,
            'is_verified_purchase' => (bool) $review->is_verified_purchase,
            'created_at' => optional($review->created_at)?->toIso8601String(),
            'product' => $review->product ? [
                'id' => $review->product->id,
                'name' => $review->product->name,
            ] : null,
            'order' => $review->order ? [
                'id' => $review->order->id,
                'order_number' => $review->order->order_number,
                'status' => $review->order->status,
            ] : null,
            'reviewee' => $review->reviewee ? [
                'id' => $review->reviewee->id,
                'name' => $review->reviewee->name,
            ] : null,
        ])->values();

        return response()->json([
            'status' => 'success',
            'data' => [
                'reviews' => $items,
                'pagination' => [
                    'current_page' => $paginator->currentPage(),
                    'last_page' => $paginator->lastPage(),
                    'per_page' => $paginator->perPage(),
                    'total' => $paginator->total(),
                ],
            ],
        ]);
    }
}
