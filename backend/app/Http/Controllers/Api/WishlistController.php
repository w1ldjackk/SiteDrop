<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Product;
use App\Models\Wishlist;
use App\Services\Activity\ActivityActions;
use App\Services\Activity\ActivityLogger;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class WishlistController extends Controller
{
    /**
     * List wishlist products for the authenticated user.
     */
    public function index(Request $request): JsonResponse
    {
        $user = $request->user();

        $items = Wishlist::with(['product.seller', 'product.seller.sellerProfile'])
            ->where('user_id', $user->id)
            ->orderByDesc('created_at')
            ->get()
            ->filter(fn (Wishlist $w) => $w->product !== null)
            ->values();

        $products = $items->map(fn (Wishlist $w) => $w->product);

        return $this->success([
            'products' => $products,
            'count' => $products->count(),
        ]);
    }

    /**
     * Add a product to the wishlist.
     */
    public function add(Request $request): JsonResponse
    {
        $request->validate([
            'product_id' => 'required|integer|exists:products,id',
        ]);

        $user = $request->user();
        $product = Product::findOrFail($request->product_id);

        $item = Wishlist::firstOrCreate([
            'user_id' => $user->id,
            'product_id' => $product->id,
        ]);

        if ($item->wasRecentlyCreated) {
            ActivityLogger::log(
                ActivityActions::WISHLIST_ADD,
                "Added product \"{$product->name}\" to wishlist",
                $product,
                ['product_id' => $product->id],
                module: 'wishlist',
                userId: $user->id,
            );
        }

        return $this->success(
            data: [
                'in_wishlist' => true,
                'product_id' => (string) $product->id,
                'count' => Wishlist::where('user_id', $user->id)->count(),
            ],
            message: $item->wasRecentlyCreated
                ? 'Added to wishlist'
                : 'Already in wishlist',
            status: $item->wasRecentlyCreated ? 201 : 200,
        );
    }

    /**
     * Remove a product from the wishlist.
     */
    public function remove(Request $request): JsonResponse
    {
        $request->validate([
            'product_id' => 'required|integer|exists:products,id',
        ]);

        $user = $request->user();

        $product = Product::find($request->product_id);

        Wishlist::where('user_id', $user->id)
            ->where('product_id', $request->product_id)
            ->delete();

        ActivityLogger::log(
            ActivityActions::WISHLIST_REMOVE,
            'Removed product from wishlist'.
                ($product ? " \"{$product->name}\"" : ''),
            $product,
            ['product_id' => $request->product_id],
            module: 'wishlist',
            userId: $user->id,
        );

        return $this->success(
            data: [
                'in_wishlist' => false,
                'product_id' => (string) $request->product_id,
                'count' => Wishlist::where('user_id', $user->id)->count(),
            ],
            message: 'Removed from wishlist',
        );
    }

    /**
     * Toggle wishlist membership for a product.
     */
    public function toggle(Request $request): JsonResponse
    {
        $request->validate([
            'product_id' => 'required|integer|exists:products,id',
        ]);

        $user = $request->user();
        $productId = $request->product_id;

        $existing = Wishlist::where('user_id', $user->id)
            ->where('product_id', $productId)
            ->first();

        if ($existing) {
            $existing->delete();
            $inWishlist = false;
            $message = 'Removed from wishlist';
            $product = Product::find($productId);
            ActivityLogger::log(
                ActivityActions::WISHLIST_REMOVE,
                'Removed product from wishlist'.
                    ($product ? " \"{$product->name}\"" : ''),
                $product,
                ['product_id' => $productId],
                module: 'wishlist',
                userId: $user->id,
            );
        } else {
            $product = Product::findOrFail($productId);
            Wishlist::create([
                'user_id' => $user->id,
                'product_id' => $productId,
            ]);
            $inWishlist = true;
            $message = 'Added to wishlist';
            ActivityLogger::log(
                ActivityActions::WISHLIST_ADD,
                "Added product \"{$product->name}\" to wishlist",
                $product,
                ['product_id' => $productId],
                module: 'wishlist',
                userId: $user->id,
            );
        }

        return $this->success(
            data: [
                'in_wishlist' => $inWishlist,
                'product_id' => (string) $productId,
                'count' => Wishlist::where('user_id', $user->id)->count(),
            ],
            message: $message,
        );
    }

    /**
     * Check whether a product is wishlisted.
     */
    public function check(Request $request): JsonResponse
    {
        $request->validate([
            'product_id' => 'required|integer|exists:products,id',
        ]);

        $user = $request->user();
        $inWishlist = Wishlist::where('user_id', $user->id)
            ->where('product_id', $request->product_id)
            ->exists();

        return $this->success([
            'in_wishlist' => $inWishlist,
            'product_id' => (string) $request->product_id,
        ]);
    }
}
