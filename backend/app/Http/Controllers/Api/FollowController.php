<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\SellerFollow;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class FollowController extends Controller
{
    /**
     * Followers count + my follow state for a seller.
     * GET /sellers/{id}/follow-status
     */
    public function status(Request $request, $id): JsonResponse
    {
        $seller = User::findOrFail($id);

        $followers = SellerFollow::where('seller_id', $seller->id)->count();
        $following = $request->user()
            ? SellerFollow::where('user_id', $request->user()->id)
                ->where('seller_id', $seller->id)
                ->exists()
            : false;

        return $this->success([
            'seller_id' => (string) $seller->id,
            'following' => $following,
            'followers_count' => $followers,
        ]);
    }

    /**
     * Toggle follow for a seller.
     * POST /sellers/{id}/follow
     */
    public function toggle(Request $request, $id): JsonResponse
    {
        $user = $request->user();
        $seller = User::findOrFail($id);

        if ((int) $seller->id === (int) $user->id) {
            return $this->error('You cannot follow yourself.', 422);
        }

        $existing = SellerFollow::where('user_id', $user->id)
            ->where('seller_id', $seller->id)
            ->first();

        if ($existing) {
            $existing->delete();
            $following = false;
            $message = 'Unfollowed seller';
        } else {
            SellerFollow::create([
                'user_id' => $user->id,
                'seller_id' => $seller->id,
            ]);
            $following = true;
            $message = 'Following seller';
        }

        return $this->success(
            data: [
                'following' => $following,
                'seller_id' => (string) $seller->id,
                'followers_count' => SellerFollow::where('seller_id', $seller->id)->count(),
            ],
            message: $message,
        );
    }

    /**
     * Sellers I follow.
     * GET /sellers/following
     */
    public function following(Request $request): JsonResponse
    {
        $user = $request->user();

        $sellers = User::whereIn(
            'id',
            SellerFollow::where('user_id', $user->id)->pluck('seller_id')
        )->get(['id', 'name', 'email']);

        return $this->success([
            'sellers' => $sellers,
            'count' => $sellers->count(),
        ]);
    }
}
