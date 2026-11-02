<?php
// app/Http/Controllers/Api/ProductController.php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\ProductRequest;
use App\Models\Order;
use App\Models\Product;
use App\Models\ProductReport;
use App\Models\Review;
use App\Models\User;
use App\Services\Activity\ActivityActions;
use App\Services\Activity\ActivityLogger;
use App\Support\PublicAssetUploader;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Auth;
use Illuminate\Validation\Rule;
use Illuminate\Foundation\Auth\Access\AuthorizesRequests;

class ProductController extends Controller
{
    use AuthorizesRequests;

    /**
     * Get seller's products
     */
    public function index(Request $request): JsonResponse
    {
        $user = $request->user();

        $products = Product::where('seller_id', $user->id)
            ->with('sourceSite')
            ->when($request->filled('site_id'), fn ($q) => $q->where('site_id', $request->site_id))
            ->orderBy('created_at', 'desc')
            ->paginate($request->get('per_page', 20));

        return response()->json([
            'status' => 'success',
            'data' => [
                'products' => $products->items(),
                'pagination' => $this->paginationMeta($products),
            ]
        ]);
    }


    /**
     * Get public product listings (for buyers)
     */
    public function listings(Request $request): JsonResponse
    {
        $query = Product::where('is_available', true)
            ->where('stock_quantity', '>', 0)
            ->with(['seller', 'seller.sellerProfile', 'sourceSite']);

        // Filter by category
        if ($request->has('category') && !empty($request->category)) {
            $query->where('category', $request->category);
        }

        // Filter by seller (public "more from this seller")
        if ($request->has('seller_id') && !empty($request->seller_id)) {
            $query->where('seller_id', $request->seller_id);
        }

        // Filter by source site (quarry / warehouse pickup origin)
        if ($request->has('site_id') && !empty($request->site_id)) {
            $query->where('site_id', $request->site_id);
        }

        // Filter by search
        if ($request->has('search') && !empty($request->search)) {
            $query->where(function ($q) use ($request) {
                $q->where('name', 'like', '%' . $request->search . '%')
                    ->orWhere('description', 'like', '%' . $request->search . '%')
                    ->orWhere('category', 'like', '%' . $request->search . '%');
            });
        }

        // Filter by price range
        if ($request->has('min_price') && is_numeric($request->min_price)) {
            $query->where('price_per_unit', '>=', (float) $request->min_price);
        }
        if ($request->has('max_price') && is_numeric($request->max_price)) {
            $query->where('price_per_unit', '<=', (float) $request->max_price);
        }

        // Filter by seller rating (optional)
        if ($request->has('min_rating') && is_numeric($request->min_rating)) {
            $query->where('avg_rating', '>=', $request->min_rating);
        }

        // Sort
        $sortField = $request->get('sort_by', 'created_at');
        $sortDirection = $request->get('sort_direction', 'desc');

        // Allowed sort fields
        $allowedSortFields = ['created_at', 'price_per_unit', 'name', 'avg_rating', 'orders_count'];
        if (in_array($sortField, $allowedSortFields)) {
            $query->orderBy($sortField, $sortDirection);
        }

        $products = $query->paginate($request->get('per_page', 20));

        return response()->json([
            'status' => 'success',
            'data' => [
                'products' => $products->items(),
                'pagination' => $this->paginationMeta($products),
            ]
        ]);
    }

    /**
     * Distinct product categories for the marketplace filter UI.
     */
    public function categories(): JsonResponse
    {
        $categories = Product::where('is_available', true)
            ->whereNotNull('category')
            ->where('category', '!=', '')
            ->distinct()
            ->orderBy('category')
            ->pluck('category')
            ->values();

        return response()->json([
            'status' => 'success',
            'data' => [
                'categories' => $categories,
            ],
        ]);
    }

    /**
     * Create a new product
     */
    public function store(ProductRequest $request): JsonResponse
    {
        $user = $request->user();

        // Check if user is a seller and approved
        if (!$user->isSeller()) {
            return $this->error('Only sellers can create products', 403);
        }

        $sellerProfile = $user->sellerProfile;
        if (!$sellerProfile || $sellerProfile->status !== 'approved') {
            return $this->error(
                'Your seller account must be approved before adding products',
                403,
            );
        }

        $productData = $request->only([
            'name',
            'category',
            'sub_category',
            'description',
            'price_per_unit',
            'unit',
            'minimum_order_quantity',
            'maximum_order_quantity',
            'is_available',
            'is_featured',
            'stock_quantity',
            'weight_kg',
            'specifications',
            'delivery_fee_per_km',
            'preparation_time_minutes',
            'is_cod_available',
            'is_delivery_available',
        ]);

        // Validate source site ownership + type when provided.
        if (! empty($productData['site_id'] ?? null)) {
            $siteCheck = $this->validateSourceSite((int) $productData['site_id'], $user->id);
            if ($siteCheck !== true) {
                return $siteCheck;
            }
        }

        // Generate SKU
        $productData['sku'] = $this->generateSku($request->name, $user->id);
        $productData['seller_id'] = $user->id;

        $product = Product::create($productData);

        // Handle image uploads (public/assets).
        if ($request->hasFile('images')) {
            $images = [];
            foreach ($this->uploadedImages($request) as $image) {
                $images[] = PublicAssetUploader::put($image, 'img/products');
            }
            if ($request->filled('featured_image')) {
                $images = $this->moveFeaturedFirst(
                    $images,
                    $request->input('featured_image'),
                    [],
                );
            }
            $product->update(['images' => $images]);
        }

        $product = $product->fresh('sourceSite');

        ActivityLogger::log(
            ActivityActions::PRODUCT_CREATED,
            "Product \"{$product->name}\" created",
            $product,
            ['product_id' => $product->id, 'price' => $product->price_per_unit],
            module: 'products',
            userId: Auth::id(),
        );

        return response()->json([
            'status' => 'success',
            'message' => 'Product created successfully',
            'data' => ['product' => $product]
        ], 201);
    }

    /**
     * Get a single product
     */
    public function show(Request $request, $id): JsonResponse
    {
        $product = Product::with(['seller', 'seller.sellerProfile', 'reviews', 'sourceSite'])
            ->findOrFail($id);

        // Increment view count
        $product->increment('views_count');

        $publishedCount = $product->reviews()->published()->count();
        $avgRating = (float) ($product->reviews()->published()->avg('rating') ?? 0);

        return response()->json([
            'status' => 'success',
            'data' => [
                'product' => $product,
                'rating' => round($avgRating, 1),
                'total_reviews' => $publishedCount,
            ]
        ]);
    }

    /**
     * List published product reviews (public).
     */
    public function reviews(Request $request, $id): JsonResponse
    {
        $product = Product::findOrFail($id);
        $perPage = min(max((int) $request->get('per_page', 10), 1), 50);

        $paginator = Review::query()
            ->where('product_id', $product->id)
            ->where('type', Review::TYPE_BUYER_TO_PRODUCT)
            ->published()
            ->with(['reviewer:id,name', 'reviewer.profile'])
            ->latest()
            ->paginate($perPage);

        $reviews = collect($paginator->items())->map(fn (Review $review) => $this->formatReview($review));

        $avgRating = (float) (Review::query()
            ->where('product_id', $product->id)
            ->where('type', Review::TYPE_BUYER_TO_PRODUCT)
            ->published()
            ->avg('rating') ?? 0);

        return response()->json([
            'status' => 'success',
            'data' => [
                'reviews' => $reviews->values(),
                'summary' => [
                    'average_rating' => round($avgRating, 1),
                    'total' => $paginator->total(),
                ],
                'pagination' => [
                    'current_page' => $paginator->currentPage(),
                    'last_page' => $paginator->lastPage(),
                    'per_page' => $paginator->perPage(),
                    'total' => $paginator->total(),
                ],
            ],
        ]);
    }

    /**
     * Create (or update) a buyer's product review.
     */
    public function storeReview(Request $request, $id): JsonResponse
    {
        $user = $request->user();
        $product = Product::findOrFail($id);

        if ((int) $product->seller_id === (int) $user->id) {
            return response()->json([
                'status' => 'error',
                'message' => 'You cannot review your own product.',
            ], 422);
        }

        $data = $request->validate([
            'rating' => ['required', 'integer', 'min:1', 'max:5'],
            'comment' => ['nullable', 'string', 'max:2000'],
            'order_id' => ['nullable', 'integer', 'exists:orders,id'],
        ]);

        $comment = trim((string) ($data['comment'] ?? ''));
        if ($comment === '') {
            $comment = null;
        }

        // Prefer an eligible purchase for verified reviews.
        $orderId = $data['order_id'] ?? null;
        $isVerified = false;

        if ($orderId) {
            $order = Order::query()
                ->where('id', $orderId)
                ->where('buyer_id', $user->id)
                ->where(function ($q) use ($product) {
                    $q->where('product_id', $product->id)
                        ->orWhereHas('items', fn ($iq) => $iq->where('product_id', $product->id));
                })
                ->whereIn('status', [
                    Order::STATUS_DELIVERED,
                    Order::STATUS_COMPLETED,
                ])
                ->first();

            if (! $order) {
                return response()->json([
                    'status' => 'error',
                    'message' => 'That order is not eligible for reviewing this product.',
                ], 422);
            }

            $orderId = $order->id;
            $isVerified = true;
        } else {
            $eligibleOrder = Order::query()
                ->where('buyer_id', $user->id)
                ->where(function ($q) use ($product) {
                    $q->where('product_id', $product->id)
                        ->orWhereHas('items', fn ($iq) => $iq->where('product_id', $product->id));
                })
                ->whereIn('status', [
                    Order::STATUS_DELIVERED,
                    Order::STATUS_COMPLETED,
                ])
                ->latest()
                ->first();

            if ($eligibleOrder) {
                $orderId = $eligibleOrder->id;
                $isVerified = true;
            }
        }

        $review = Review::query()
            ->where('product_id', $product->id)
            ->where('reviewer_id', $user->id)
            ->where('type', Review::TYPE_BUYER_TO_PRODUCT)
            ->first();

        $payload = [
            'order_id' => $orderId,
            'reviewer_id' => $user->id,
            'reviewee_id' => $product->seller_id,
            'product_id' => $product->id,
            'rating' => (int) $data['rating'],
            'comment' => $comment,
            'type' => Review::TYPE_BUYER_TO_PRODUCT,
            'is_verified_purchase' => $isVerified,
            'status' => Review::STATUS_PUBLISHED,
        ];

        if ($review) {
            $review->update($payload);
            $review->refresh();
            $message = 'Review updated successfully.';
        } else {
            $review = Review::create($payload);
            $message = 'Review submitted successfully.';
        }

        $review->load(['reviewer:id,name', 'reviewer.profile']);

        // Keep denormalized product rating in sync.
        $avg = (float) (Review::query()
            ->where('product_id', $product->id)
            ->where('type', Review::TYPE_BUYER_TO_PRODUCT)
            ->published()
            ->avg('rating') ?? 0);
        $product->update(['avg_rating' => round($avg, 2)]);

        return response()->json([
            'status' => 'success',
            'message' => $message,
            'data' => [
                'review' => $this->formatReview($review),
                'summary' => [
                    'average_rating' => round($avg, 1),
                    'total' => Review::query()
                        ->where('product_id', $product->id)
                        ->where('type', Review::TYPE_BUYER_TO_PRODUCT)
                        ->published()
                        ->count(),
                ],
            ],
        ], $review->wasRecentlyCreated ? 201 : 200);
    }

    /**
     * Report a product (counterfeit, misleading, prohibited, ...).
     */
    public function report(Request $request, $id): JsonResponse
    {
        $user = $request->user();
        $product = Product::findOrFail($id);

        $data = $request->validate([
            'reason' => ['required', 'string', Rule::in(ProductReport::REASONS)],
            'details' => ['nullable', 'string', 'max:2000'],
        ]);

        $report = ProductReport::create([
            'user_id' => $user->id,
            'product_id' => $product->id,
            'reason' => $data['reason'],
            'details' => $data['details'] ?? null,
            'status' => ProductReport::STATUS_PENDING,
        ]);

        return response()->json([
            'status' => 'success',
            'message' => 'Thanks â€” our team will review this product.',
            'data' => ['report_id' => $report->id],
        ], 201);
    }

    /**
     * @return array<string, mixed>
     */
    private function formatReview(Review $review): array
    {
        $reviewer = $review->reviewer;
        $avatar = $reviewer?->profile?->avatar_url;

        return [
            'id' => $review->id,
            'rating' => (int) $review->rating,
            'comment' => $review->comment,
            'is_verified_purchase' => (bool) $review->is_verified_purchase,
            'helpful_count' => (int) $review->helpful_count,
            'created_at' => optional($review->created_at)?->toIso8601String(),
            'updated_at' => optional($review->updated_at)?->toIso8601String(),
            'reviewer' => [
                'id' => $reviewer?->id,
                'name' => $reviewer?->name ?? 'Buyer',
                'avatar' => $avatar,
            ],
        ];
    }

    /**
     * Update a product
     */
    public function update(ProductRequest $request, $id): JsonResponse
    {
        $product = Product::findOrFail($id);

        // Check if user owns this product
        if ($product->seller_id !== Auth::id()) {
            return response()->json([
                'status' => 'error',
                'message' => 'You do not have permission to update this product'
            ], 403);
        }

        $productData = $request->only([
            'name',
            'category',
            'sub_category',
            'description',
            'price_per_unit',
            'unit',
            'minimum_order_quantity',
            'maximum_order_quantity',
            'is_available',
            'is_featured',
            'stock_quantity',
            'weight_kg',
            'specifications',
            'delivery_fee_per_km',
            'preparation_time_minutes',
            'is_cod_available',
            'is_delivery_available',
            'site_id',
        ]);

        if (array_key_exists('site_id', $productData) && ! empty($productData['site_id'])) {
            $siteCheck = $this->validateSourceSite((int) $productData['site_id'], Auth::id());
            if ($siteCheck !== true) {
                return $siteCheck;
            }
        }

        $product->update($productData);

        // Handle image uploads (public/assets).
        // The app sends `existing_images` (JSON list of kept URLs, featured
        // first) so removals and featured ordering persist; anything stored
        // before but no longer kept is deleted from disk.
        $storedImages = is_array($product->images) ? array_values($product->images) : [];
        $keptImages = $storedImages;
        if ($request->filled('existing_images')) {
            $kept = $request->input('existing_images');
            if (is_string($kept)) {
                $decoded = json_decode($kept, true);
                $kept = is_array($decoded) ? $decoded : [];
            }
            $keptImages = array_values(array_filter(
                array_map(fn ($u) => is_string($u) ? trim($u) : '', (array) $kept),
                fn ($u) => $u !== '',
            ));
            foreach (array_diff($storedImages, $keptImages) as $removed) {
                PublicAssetUploader::delete($removed);
            }
        }

        if ($request->hasFile('images')) {
            $newImages = [];
            foreach ($this->uploadedImages($request) as $image) {
                $newImages[] = PublicAssetUploader::put($image, 'img/products');
            }
            $merged = array_merge($keptImages, $newImages);
            if ($request->filled('featured_image')) {
                $merged = $this->moveFeaturedFirst(
                    $merged,
                    $request->input('featured_image'),
                    $newImages,
                );
            }
            $product->update(['images' => $merged]);
        } elseif ($request->filled('existing_images')) {
            $final = $keptImages;
            if ($request->filled('featured_image')) {
                $final = $this->moveFeaturedFirst(
                    $final,
                    $request->input('featured_image'),
                    [],
                );
            }
            $product->update(['images' => $final]);
        }

        $product = $product->fresh('sourceSite');

        ActivityLogger::log(
            ActivityActions::PRODUCT_UPDATED,
            "Product \"{$product->name}\" updated",
            $product,
            ['product_id' => $product->id],
            module: 'products',
            userId: Auth::id(),
        );

        return response()->json([
            'status' => 'success',
            'message' => 'Product updated successfully',
            'data' => ['product' => $product]
        ]);
    }

    /**
     * Delete a product
     */
    public function destroy($id): JsonResponse
    {
        $product = Product::findOrFail($id);

        // Check if user owns this product
        if ($product->seller_id !== Auth::id()) {
            return response()->json([
                'status' => 'error',
                'message' => 'You do not have permission to delete this product'
            ], 403);
        }

        $productName = $product->name;
        $productId = $product->id;

        // Delete images (public/assets or legacy storage).
        if ($product->images) {
            foreach ($product->images as $image) {
                PublicAssetUploader::delete($image);
            }
        }

        $product->delete();

        ActivityLogger::log(
            ActivityActions::PRODUCT_DELETED,
            "Product \"{$productName}\" deleted",
            null,
            ['product_id' => $productId, 'name' => $productName],
            level: \App\Models\ActivityLog::LEVEL_WARNING,
            module: 'products',
            userId: Auth::id(),
        );

        return response()->json([
            'status' => 'success',
            'message' => 'Product deleted successfully'
        ]);
    }

    /**
     * Normalize the `images` upload to a list. Proper clients send `images[]`
     * (bracket notation is what makes PHP build an array); a lone `images`
     * part arrives as a single file, so wrap it instead of crashing.
     *
     * @return array<int, \Illuminate\Http\UploadedFile>
     */
    private function uploadedImages(Request $request): array
    {
        $uploaded = $request->file('images');
        if ($uploaded instanceof UploadedFile) {
            return [$uploaded];
        }

        return array_values(array_filter(
            (array) $uploaded,
            fn ($f) => $f instanceof UploadedFile,
        ));
    }

    /**
     * Move the featured image to the front of the list (images[0] is the
     * cover). $featured is either a kept image URL or "new:{index}" pointing
     * at one of the just-uploaded $newImages URLs.
     */    private function moveFeaturedFirst(array $all, mixed $featured, array $newImages): array
    {
        $featured = is_string($featured) ? trim($featured) : '';
        if ($featured === '') {
            return $all;
        }
        if (str_starts_with($featured, 'new:')) {
            $index = (int) substr($featured, 4);
            $featured = $newImages[$index] ?? '';
        }
        if ($featured === '' || ! in_array($featured, $all, true)) {
            return $all;
        }

        return array_values(array_merge(
            [$featured],
            array_diff($all, [$featured]),
        ));
    }

    /**
     * Toggle product availability
     */
    public function toggleAvailability($id): JsonResponse
    {
        $product = Product::findOrFail($id);

        if ($product->seller_id !== Auth::id()) {
            return response()->json([
                'status' => 'error',
                'message' => 'You do not have permission to modify this product'
            ], 403);
        }

        $product->update([
            'is_available' => !$product->is_available
        ]);

        ActivityLogger::log(
            ActivityActions::PRODUCT_AVAILABILITY,
            "Product \"{$product->name}\" availability set to ".
                ($product->is_available ? 'available' : 'unavailable'),
            $product,
            [
                'product_id' => $product->id,
                'is_available' => $product->is_available,
            ],
            module: 'products',
            userId: Auth::id(),
        );

        return response()->json([
            'status' => 'success',
            'message' => 'Product availability updated',
            'data' => [
                'is_available' => $product->is_available
            ]
        ]);
    }

    /**
     * Generate SKU
     */
    private function generateSku($name, $sellerId): string
    {
        $prefix = strtoupper(substr(preg_replace('/[^a-zA-Z0-9]/', '', $name), 0, 3));
        $sellerCode = str_pad($sellerId, 3, '0', STR_PAD_LEFT);
        $random = strtoupper(substr(uniqid(), -6));
        return $prefix . '-' . $sellerCode . '-' . $random;
    }

    /**
     * Source site must belong to the seller and be a pickup-type site
     * (quarry / warehouse / supplier / other). Construction sites are
     * buyer delivery destinations, not pickup origins.
     *
     * @return true|JsonResponse true when valid, error response otherwise
     */
    private function validateSourceSite(int $siteId, int $sellerId)
    {
        $site = \App\Models\Site::find($siteId);
        if (! $site) {
            return $this->error('Source site not found', 422);
        }
        if ((int) $site->user_id !== (int) $sellerId) {
            return $this->error('You do not own this source site', 403);
        }
        if (in_array($site->site_type, [\App\Models\Site::SITE_TYPE_CONSTRUCTION], true)) {
            return $this->error('Construction sites cannot be used as product pickup origins. Use a quarry, warehouse, or supplier site.', 422);
        }

        return true;
    }
}
