<?php
// app/Http/Controllers/Api/CartController.php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\AddToCartRequest;
use App\Models\Cart;
use App\Models\CartItem;
use App\Models\Product;
use App\Services\Activity\ActivityActions;
use App\Services\Activity\ActivityLogger;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Foundation\Auth\Access\AuthorizesRequests;

class CartController extends Controller
{
    use AuthorizesRequests;

    /**
     * Get user's cart
     */
    public function show(Request $request): JsonResponse
    {
        $user = $request->user();
        $cart = $this->getOrCreateCart($user);

        // Load cart items with product details
        $cart->load(['items.product', 'items.product.seller']);

        return response()->json([
            'status' => 'success',
            'data' => [
                'cart' => [
                    'id' => $cart->id,
                    'items' => $cart->items->map(function ($item) {
                        // Decode images properly
                        $images = $item->product->images;
                        $productImage = '';

                        if (is_array($images) && count($images) > 0) {
                            $productImage = $images[0];
                        } elseif (is_string($images)) {
                            $decoded = json_decode($images, true);
                            if (is_array($decoded) && count($decoded) > 0) {
                                $productImage = $decoded[0];
                            } else {
                                $productImage = $images;
                            }
                        }

                        return [
                            'id' => $item->id,
                            'product_id' => $item->product_id,
                            'product_name' => $item->product->name,
                            'product_image' => $productImage,
                            'quantity' => $item->quantity,
                            'price' => $item->price,
                            'subtotal' => $item->subtotal,
                            'seller_id' => $item->product->seller_id,
                            'seller_name' => $item->product->seller->name,
                            'max_quantity' => $item->product->stock_quantity,
                            'unit' => $item->product->unit,
                        ];
                    }),
                    'total_items' => $cart->item_count,
                    'total_price' => $cart->total,
                    'subtotal' => $cart->total,
                    'delivery_fee' => $this->calculateDeliveryFee($cart),
                    'grand_total' => $cart->total + $this->calculateDeliveryFee($cart),
                ]
            ]
        ]);
    }


    /**
     * Add item to cart
     */
    public function add(AddToCartRequest $request): JsonResponse
    {
        $user = $request->user();
        $product = Product::findOrFail($request->product_id);

        // Check if product is available
        if (!$product->is_available) {
            return response()->json([
                'status' => 'error',
                'message' => 'This product is currently not available'
            ], 400);
        }

        // Check stock
        if ($product->stock_quantity < $request->quantity) {
            return response()->json([
                'status' => 'error',
                'message' => 'Not enough stock available. Available: ' . $product->stock_quantity
            ], 400);
        }

        $cart = $this->getOrCreateCart($user);

        // Check if item already exists in cart
        $existingItem = $cart->items()->where('product_id', $product->id)->first();

        DB::beginTransaction();
        try {
            if ($existingItem) {
                // Update quantity
                $newQuantity = $existingItem->quantity + $request->quantity;

                // Check if new quantity exceeds stock
                if ($product->stock_quantity < $newQuantity) {
                    return response()->json([
                        'status' => 'error',
                        'message' => 'Cannot add more. Max available: ' . $product->stock_quantity
                    ], 400);
                }

                $existingItem->update([
                    'quantity' => $newQuantity,
                    'price' => $product->price_per_unit,
                ]);
            } else {
                // Add new item
                $cart->items()->create([
                    'product_id' => $product->id,
                    'quantity' => $request->quantity,
                    'price' => $product->price_per_unit,
                    'variations' => $request->variations ?? null,
                ]);
            }

            DB::commit();

            ActivityLogger::log(
                ActivityActions::CART_ADD,
                "Added {$request->quantity}× {$product->name} to cart",
                $product,
                [
                    'product_id' => $product->id,
                    'quantity' => $request->quantity,
                ],
                module: 'cart',
                userId: $user->id,
            );

            return response()->json([
                'status' => 'success',
                'message' => 'Item added to cart successfully',
                'data' => [
                    'cart' => $this->getCartSummary($cart)
                ]
            ]);
        } catch (\Exception $e) {
            DB::rollBack();
            Log::error('Add to cart failed', [
                'user_id' => $user->id,
                'product_id' => $request->product_id ?? null,
                'error' => $e->getMessage(),
            ]);
            return response()->json([
                'status' => 'error',
                'message' => 'Failed to add item to cart. Please try again.'
            ], 500);
        }
    }

    /**
     * Update cart item quantity
     */
    public function updateQuantity(Request $request, $itemId): JsonResponse
    {
        $request->validate([
            'quantity' => 'required|integer|min:1'
        ]);

        $user = $request->user();
        $cart = $this->getOrCreateCart($user);

        $cartItem = $cart->items()->with('product')->findOrFail($itemId);

        // Check stock
        if ($cartItem->product->stock_quantity < $request->quantity) {
            return response()->json([
                'status' => 'error',
                'message' => 'Not enough stock. Available: ' . $cartItem->product->stock_quantity
            ], 400);
        }

        $cartItem->update(['quantity' => $request->quantity]);

        ActivityLogger::log(
            ActivityActions::CART_UPDATE,
            "Updated cart quantity to {$request->quantity} for {$cartItem->product->name}",
            $cartItem->product,
            [
                'cart_item_id' => $cartItem->id,
                'product_id' => $cartItem->product_id,
                'quantity' => $request->quantity,
            ],
            module: 'cart',
            userId: $user->id,
        );

        return response()->json([
            'status' => 'success',
            'message' => 'Cart updated successfully',
            'data' => [
                'cart' => $this->getCartSummary($cart->fresh())
            ]
        ]);
    }

    /**
     * Remove item from cart
     */
    public function remove($itemId): JsonResponse
    {
        $user = request()->user();
        $cart = $this->getOrCreateCart($user);

        $cartItem = $cart->items()->with('product')->findOrFail($itemId);
        $productName = $cartItem->product->name ?? 'item';
        $productId = $cartItem->product_id;
        $cartItem->delete();

        ActivityLogger::log(
            ActivityActions::CART_REMOVE,
            "Removed {$productName} from cart",
            null,
            ['product_id' => $productId, 'cart_item_id' => $itemId],
            module: 'cart',
            userId: $user->id,
        );

        return response()->json([
            'status' => 'success',
            'message' => 'Item removed from cart',
            'data' => [
                'cart' => $this->getCartSummary($cart->fresh())
            ]
        ]);
    }

    /**
     * Clear cart
     */
    public function clear(Request $request): JsonResponse
    {
        $user = $request->user();
        $cart = $this->getOrCreateCart($user);

        $count = $cart->items()->count();
        $cart->items()->delete();

        ActivityLogger::log(
            ActivityActions::CART_CLEAR,
            "Cleared cart ({$count} items)",
            $cart,
            ['items_cleared' => $count],
            module: 'cart',
            userId: $user->id,
        );

        return response()->json([
            'status' => 'success',
            'message' => 'Cart cleared successfully'
        ]);
    }

    /**
     * Get or create cart for user
     */
    private function getOrCreateCart($user): Cart
    {
        $cart = Cart::where('user_id', $user->id)
            ->where('status', 'active')
            ->first();

        if (!$cart) {
            $cart = Cart::create([
                'user_id' => $user->id,
                'status' => 'active',
                'expires_at' => now()->addDays(7),
            ]);
        }

        return $cart;
    }

    /**
     * Calculate delivery fee based on cart items
     */
    private function calculateDeliveryFee(Cart $cart): float
    {
        // Group items by seller and calculate delivery fee
        $deliveryFee = 0;
        $uniqueSellers = $cart->items->pluck('product.seller_id')->unique();

        foreach ($uniqueSellers as $sellerId) {
            $sellerItems = $cart->items->filter(function ($item) use ($sellerId) {
                return $item->product->seller_id === $sellerId;
            });

            // Calculate based on total weight or quantity
            $totalWeight = $sellerItems->sum(function ($item) {
                return $item->product->weight_kg * $item->quantity;
            });

            // Basic delivery fee calculation
            $deliveryFee += 10.00; // Base fee per seller
            if ($totalWeight > 0) {
                $deliveryFee += ($totalWeight / 1000) * 5.00; // Extra for heavy items
            }
        }

        return round($deliveryFee, 2);
    }

    /**
     * Get cart summary
     */
    private function getCartSummary(Cart $cart): array
    {
        $cart->load(['items.product', 'items.product.seller']);

        return [
            'id' => $cart->id,
            'items_count' => $cart->items->count(),
            'total_items' => $cart->item_count,
            'subtotal' => $cart->total,
            'delivery_fee' => $this->calculateDeliveryFee($cart),
            'grand_total' => $cart->total + $this->calculateDeliveryFee($cart),
            'items' => $cart->items->map(function ($item) {
                return [
                    'id' => $item->id,
                    'product_id' => $item->product_id,
                    'product_name' => $item->product->name,
                    'quantity' => $item->quantity,
                    'price' => $item->price,
                    'subtotal' => $item->subtotal,
                    'unit' => $item->product->unit,
                ];
            }),
        ];
    }
}
