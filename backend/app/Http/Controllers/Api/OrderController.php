<?php
// app/Http/Controllers/Api/OrderController.php

namespace App\Http\Controllers\Api;

use App\Events\OrderStatusChanged;
use App\Http\Controllers\Controller;
use App\Http\Requests\Api\CreateOrderRequest;
use App\Jobs\Notification\SendOrderStatusNotification;
use App\Jobs\Order\ProcessRefund;
use App\Jobs\Order\ReleasePaymentToSeller;
use App\Models\Cart;
use App\Models\Order;
use App\Models\OrderTimeline;
use App\Models\User;
use App\Services\Activity\ActivityActions;
use App\Services\Activity\ActivityLogger;
use App\Services\Order\OrderService;
use App\Services\Order\OrderAnalyticsService;
use App\Exports\OrdersExport;
use Maatwebsite\Excel\Facades\Excel;
use Illuminate\Foundation\Auth\Access\AuthorizesRequests;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

class OrderController extends Controller
{
    use AuthorizesRequests;

    protected OrderService $orderService;
    protected OrderAnalyticsService $orderAnalyticsService;

    public function __construct(
        OrderService $orderService,
        OrderAnalyticsService $orderAnalyticsService,
    ) {
        $this->orderService = $orderService;
        $this->orderAnalyticsService = $orderAnalyticsService;
    }

    /**
     * Get user orders
     */
    public function index(Request $request): JsonResponse
    {
        $user = $request->user();

        $query = Order::where('buyer_id', $user->id)
            ->with(['orderItems.product', 'seller', 'delivery', 'buyer']); // ✅ Use orderItems

        // Filter by status
        if ($request->has('status')) {
            $query->where('status', $request->status);
        }

        // Filter by date range
        if ($request->has('from_date')) {
            $query->whereDate('created_at', '>=', $request->from_date);
        }
        if ($request->has('to_date')) {
            $query->whereDate('created_at', '<=', $request->to_date);
        }

        $orders = $query->orderBy('created_at', 'desc')
            ->paginate($request->get('per_page', 20));

        // ✅ Map each order to use api_response
        $mappedOrders = array_map(function ($order) {
            return $order->api_response;
        }, $orders->items());

        return response()->json([
            'status' => 'success',
            'data' => [
                'orders' => $mappedOrders,
                'pagination' => [
                    'current_page' => $orders->currentPage(),
                    'last_page' => $orders->lastPage(),
                    'per_page' => $orders->perPage(),
                    'total' => $orders->total(),
                ]
            ]
        ]);
    }

    /**
     * Create new order from cart
     */
    public function store(CreateOrderRequest $request): JsonResponse
    {
        $user = $request->user();

        // Get user's cart
        $cart = Cart::where('user_id', $user->id)
            ->where('status', 'active')
            ->with(['items.product'])
            ->first();

        if (!$cart || $cart->items->isEmpty()) {
            return response()->json([
                'status' => 'error',
                'message' => 'Your cart is empty'
            ], 400);
        }

        // Validate cart items
        foreach ($cart->items as $item) {
            if (!$item->product->is_available) {
                return response()->json([
                    'status' => 'error',
                    'message' => "{$item->product->name} is no longer available"
                ], 400);
            }

            if ($item->product->stock_quantity < $item->quantity) {
                return response()->json([
                    'status' => 'error',
                    'message' => "Not enough stock for {$item->product->name}. Available: {$item->product->stock_quantity}"
                ], 400);
            }
        }

        try {
            DB::beginTransaction();

            // Create order from cart
            $order = $this->orderService->createOrderFromCart($cart, $request->all());

            // Clear cart after order creation
            $cart->items()->delete();
            $cart->update(['status' => 'converted']);

            DB::commit();

            // Load relationships for response
            $order->load(['orderItems.product', 'seller', 'delivery', 'buyer']); // ✅ Use orderItems

            ActivityLogger::log(
                ActivityActions::ORDER_CREATED,
                "Order #{$order->id} created from cart",
                $order,
                [
                    'order_id' => $order->id,
                    'total' => $order->total_amount ?? null,
                    'seller_id' => $order->seller_id,
                ],
                module: 'orders',
                userId: $user->id,
            );

            return response()->json([
                'status' => 'success',
                'message' => 'Order created successfully',
                'data' => [
                    'order' => $order->api_response, // ✅ Use api_response
                    'next_steps' => 'Proceed to payment to confirm your order',
                ]
            ], 201);
        } catch (\Exception $e) {
            DB::rollBack();
            Log::error('Order creation failed', [
                'user_id' => $user->id,
                'error' => $e->getMessage(),
            ]);
            return response()->json([
                'status' => 'error',
                'message' => 'Failed to create order. Please try again.'
            ], 500);
        }
    }

    /**
     * Get single order details
     */
    public function show($id): JsonResponse
    {
        $user = Auth::user();

        $order = Order::with([
            'orderItems.product', // ✅ Use orderItems, not product
            'seller',
            'buyer',
            'delivery',
            'payment',
            'timeline',
            'review'
        ])->findOrFail($id);

        // Check if user has access to this order
        if ($order->buyer_id !== $user->id && $order->seller_id !== $user->id && !$user->isAdmin()) {
            return response()->json([
                'status' => 'error',
                'message' => 'You do not have permission to view this order'
            ], 403);
        }

        return response()->json([
            'status' => 'success',
            'data' => [
                'order' => $order->api_response, // ✅ Use api_response
                'timeline' => $order->timeline,
                'can_cancel' => $order->canCancel(),
                // Trip is done at delivered — same gate as storeReview.
                'can_review' => in_array($order->status, [
                    Order::STATUS_DELIVERED,
                    Order::STATUS_COMPLETED,
                ], true) && ! $order->review,
            ]
        ]);
    }

    /**
     * Update order status (for sellers)
     */
    public function updateStatus(Request $request, $id): JsonResponse
    {
        $request->validate([
            'status' => 'required|in:confirmed,processing,ready_for_delivery,dispatched,in_transit,delivered,completed,cancelled',
            'reason' => 'required_if:status,cancelled|string|max:500'
        ]);

        $user = Auth::user();
        $order = Order::findOrFail($id);

        // Only seller or admin can update status
        if ($order->seller_id !== $user->id && !$user->isAdmin()) {
            return response()->json([
                'status' => 'error',
                'message' => 'You do not have permission to update this order'
            ], 403);
        }

        // Validate status transition
        $validTransitions = [
            Order::STATUS_CONFIRMED => [Order::STATUS_PENDING],
            Order::STATUS_PROCESSING => [Order::STATUS_CONFIRMED],
            Order::STATUS_READY_FOR_DELIVERY => [Order::STATUS_PROCESSING],
            Order::STATUS_DISPATCHED => [Order::STATUS_READY_FOR_DELIVERY],
            Order::STATUS_IN_TRANSIT => [Order::STATUS_READY_FOR_DELIVERY, Order::STATUS_DISPATCHED],
            Order::STATUS_DELIVERED => [Order::STATUS_IN_TRANSIT],
            Order::STATUS_COMPLETED => [Order::STATUS_DELIVERED],
        ];

        $newStatus = $request->status;
        $oldStatus = $order->status;

        if ($newStatus !== Order::STATUS_CANCELLED && $newStatus !== Order::STATUS_COMPLETED) {
            if (
                !isset($validTransitions[$newStatus]) ||
                !in_array($order->status, $validTransitions[$newStatus])
            ) {
                return response()->json([
                    'status' => 'error',
                    'message' => "Invalid status transition from {$order->status} to {$newStatus}"
                ], 400);
            }
        }

        // Handle cancellation
        if ($newStatus === Order::STATUS_CANCELLED) {
            if (!$order->canCancel()) {
                return response()->json([
                    'status' => 'error',
                    'message' => 'This order cannot be cancelled at this stage'
                ], 400);
            }

            $order->update([
                'status' => Order::STATUS_CANCELLED,
                'cancellation_reason' => $request->reason,
                'cancelled_by' => $user->id,
            ]);

            // Process refund if paid
            if ($order->payment_status === Order::PAYMENT_STATUS_PAID) {
                dispatch(new ProcessRefund($order));
            }
        } else {
            $order->update(['status' => $newStatus]);

            // If delivered, update delivery timestamp
            if ($newStatus === Order::STATUS_DELIVERED) {
                $order->update(['delivered_at' => now()]);
            }

            // If completed, mark order as complete and release payment
            if ($newStatus === Order::STATUS_COMPLETED) {
                dispatch(new ReleasePaymentToSeller($order));
            }
        }

        // Refresh to ensure updated_at etc. are current for broadcast
        $order->refresh();
        $freshOrder = $order;

        // Log timeline
        OrderTimeline::logStatusChange($freshOrder, $oldStatus, $newStatus, $request->reason);

        // Send notification (realtime broadcast + buyer in-app/push) — only when status actually changed
        if ($oldStatus !== $newStatus) {
            event(new OrderStatusChanged($freshOrder, $oldStatus, $newStatus));
            dispatch(new SendOrderStatusNotification($freshOrder, $oldStatus, $newStatus));
        } else {
            \Illuminate\Support\Facades\Log::warning('OrderStatusChanged skipped: old and new status identical', [
                'order_id' => $order->id,
                'status' => $newStatus,
            ]);
        }

        ActivityLogger::log(
            $newStatus === Order::STATUS_CANCELLED
                ? ActivityActions::ORDER_CANCELLED
                : ActivityActions::ORDER_STATUS,
            "Order #{$order->id} status {$oldStatus} → {$newStatus}",
            $order,
            [
                'order_id' => $order->id,
                'old_status' => $oldStatus,
                'new_status' => $newStatus,
                'reason' => $request->reason,
            ],
            level: $newStatus === Order::STATUS_CANCELLED
                ? \App\Models\ActivityLog::LEVEL_WARNING
                : \App\Models\ActivityLog::LEVEL_INFO,
            module: 'orders',
            userId: $user->id,
        );

        // Bolt-style auto-dispatch: seller marked ready → broadcast trip
        // requests to available drivers (first-accept wins). Best-effort:
        // never breaks the status update itself.
        // Order confirmed → push to ONLINE drivers only (model hook also
        // fires — dispatch() is idempotent so the second call just
        // reports offers_pending instead of duplicating).
        $dispatchResult = null;
        if ($newStatus === Order::STATUS_CONFIRMED) {
            try {
                $dispatchResult = app(\App\Services\Delivery\DeliveryService::class)
                    ->dispatchOnConfirmed($freshOrder->fresh() ?? $freshOrder);
                \Illuminate\Support\Facades\Log::info('Auto-dispatch on confirmed', [
                    'order_id' => $order->id,
                    'result' => $dispatchResult,
                ]);
            } catch (\Throwable $e) {
                \Illuminate\Support\Facades\Log::warning('Auto-dispatch on confirmed failed', [
                    'order_id' => $order->id,
                    'error' => $e->getMessage(),
                ]);
            }
        }
        if ($newStatus === Order::STATUS_READY_FOR_DELIVERY) {
            try {
                $dispatchResult = app(\App\Services\Delivery\DeliveryService::class)
                    ->dispatchForOrder($freshOrder->fresh() ?? $freshOrder);
                \Illuminate\Support\Facades\Log::info('Auto-dispatch on ready', [
                    'order_id' => $order->id,
                    'result' => $dispatchResult,
                ]);
            } catch (\Throwable $e) {
                \Illuminate\Support\Facades\Log::warning('Auto-dispatch failed', [
                    'order_id' => $order->id,
                    'error' => $e->getMessage(),
                ]);
            }
        }

        // Load relationships for response
        $order->load(['orderItems.product', 'seller', 'buyer']);

        return response()->json([
            'status' => 'success',
            'message' => 'Order status updated successfully',
            'data' => [
                'order' => $order->api_response, // ✅ Use api_response
                'new_status' => $newStatus,
                'status_label' => $order->status_label,
                'dispatch' => $dispatchResult,
            ]
        ]);
    }

    /**
     * Cancel order (for buyers)
     */
    public function cancel(Request $request, $id): JsonResponse
    {
        $request->validate([
            'reason' => 'required|string|max:500'
        ]);

        $user = Auth::user();
        $order = Order::findOrFail($id);

        // Only buyer can cancel
        if ($order->buyer_id !== $user->id) {
            return response()->json([
                'status' => 'error',
                'message' => 'You do not have permission to cancel this order'
            ], 403);
        }

        if (!$order->canCancel()) {
            return response()->json([
                'status' => 'error',
                'message' => 'This order cannot be cancelled at this stage'
            ], 400);
        }

        DB::beginTransaction();
        try {
            $oldStatus = $order->status;

            $order->update([
                'status' => Order::STATUS_CANCELLED,
                'cancellation_reason' => $request->reason,
                'cancelled_by' => $user->id,
            ]);

            // Log timeline — use captured oldStatus, not getOriginal() which is synced to new after update
            OrderTimeline::logStatusChange(
                $order,
                $oldStatus,
                Order::STATUS_CANCELLED,
                $request->reason
            );

            // Process refund if paid
            if ($order->payment_status === Order::PAYMENT_STATUS_PAID) {
                dispatch(new ProcessRefund($order));
            }

            // Restore stock
            foreach ($order->orderItems as $orderItem) {
                $product = $orderItem->product;
                if ($product) {
                    $product->increment('stock_quantity', $orderItem->quantity);
                }
            }

            DB::commit();

            // Realtime broadcast + notification — only if status actually changed
            $freshOrder = $order->fresh();
            if ($oldStatus !== Order::STATUS_CANCELLED) {
                event(new OrderStatusChanged($freshOrder ?? $order, $oldStatus, Order::STATUS_CANCELLED));
                dispatch(new SendOrderStatusNotification($freshOrder ?? $order, $oldStatus, Order::STATUS_CANCELLED));
            }
            $order = $freshOrder ?? $order;

            // Load relationships for response
            $order->load(['orderItems.product', 'seller', 'buyer']);

            ActivityLogger::log(
                ActivityActions::ORDER_CANCELLED,
                "Buyer cancelled order #{$order->id}",
                $order,
                [
                    'order_id' => $order->id,
                    'reason' => $request->reason,
                    'refund_initiated' => $order->payment_status === Order::PAYMENT_STATUS_PAID,
                ],
                level: \App\Models\ActivityLog::LEVEL_WARNING,
                module: 'orders',
                userId: $user->id,
            );

            return response()->json([
                'status' => 'success',
                'message' => 'Order cancelled successfully',
                'data' => [
                    'order' => $order->api_response, // ✅ Use api_response
                    'refund_initiated' => $order->payment_status === Order::PAYMENT_STATUS_PAID,
                ]
            ]);
        } catch (\Exception $e) {
            DB::rollBack();
            Log::error('Order cancellation failed', [
                'order_id' => $id,
                'user_id' => $user->id,
                'error' => $e->getMessage(),
            ]);
            return response()->json([
                'status' => 'error',
                'message' => 'Failed to cancel order. Please try again.'
            ], 500);
        }
    }

    /**
     * Get seller orders
     */
    public function sellerOrders(Request $request): JsonResponse
    {
        $user = $request->user();

        if (!$user->isSeller()) {
            return response()->json([
                'status' => 'error',
                'message' => 'Only sellers can view seller orders'
            ], 403);
        }

        $query = Order::where('seller_id', $user->id)
            ->with(['orderItems.product', 'buyer', 'delivery']); // ✅ Use orderItems

        // Filter by status
        if ($request->has('status')) {
            $query->where('status', $request->status);
        }

        $orders = $query->orderBy('created_at', 'desc')
            ->paginate($request->get('per_page', 20));

        // Calculate statistics
        $stats = [
            'total_orders' => Order::where('seller_id', $user->id)->count(),
            'pending_orders' => Order::where('seller_id', $user->id)
                ->where('status', Order::STATUS_PENDING)->count(),
            'processing_orders' => Order::where('seller_id', $user->id)
                ->where('status', Order::STATUS_PROCESSING)->count(),
            'completed_orders' => Order::where('seller_id', $user->id)
                ->where('status', Order::STATUS_COMPLETED)->count(),
            'total_revenue' => Order::where('seller_id', $user->id)
                ->where('status', Order::STATUS_COMPLETED)
                ->sum('total_amount'),
        ];

        // ✅ Map each order to use api_response
        $mappedOrders = array_map(function ($order) {
            return $order->api_response;
        }, $orders->items());

        return response()->json([
            'status' => 'success',
            'data' => [
                'statistics' => $stats,
                'orders' => $mappedOrders,
                'pagination' => [
                    'current_page' => $orders->currentPage(),
                    'last_page' => $orders->lastPage(),
                    'per_page' => $orders->perPage(),
                    'total' => $orders->total(),
                ]
            ]
        ]);
    }

    /**
     * Rate a completed order: seller review + optional driver (trip) rating.
     * POST /orders/{id}/review
     */
    public function storeReview(Request $request, $id): JsonResponse
    {
        $data = $request->validate([
            'rating' => ['required', 'integer', 'min:1', 'max:5'],
            'comment' => ['nullable', 'string', 'max:2000'],
            'driver_rating' => ['nullable', 'integer', 'min:1', 'max:5'],
            'driver_comment' => ['nullable', 'string', 'max:2000'],
        ]);

        $user = Auth::user();
        $order = Order::with('delivery')->findOrFail($id);

        if ($order->buyer_id !== $user->id) {
            return response()->json([
                'status' => 'error',
                'message' => 'You can only review your own orders',
            ], 403);
        }

        if (!in_array($order->status, [Order::STATUS_DELIVERED, Order::STATUS_COMPLETED], true)) {
            return response()->json([
                'status' => 'error',
                'message' => 'You can review this order once it is delivered',
            ], 422);
        }

        $existing = \App\Models\Review::query()
            ->where('order_id', $order->id)
            ->where('reviewer_id', $user->id)
            ->where('type', \App\Models\Review::TYPE_BUYER_TO_SELLER)
            ->first();
        if ($existing) {
            return response()->json([
                'status' => 'error',
                'message' => 'You have already reviewed this order',
            ], 422);
        }

        $comment = trim((string) ($data['comment'] ?? ''));
        $driverComment = trim((string) ($data['driver_comment'] ?? ''));

        $review = \App\Models\Review::create([
            'order_id' => $order->id,
            'reviewer_id' => $user->id,
            'reviewee_id' => $order->seller_id,
            'rating' => (int) $data['rating'],
            'comment' => $comment === '' ? null : $comment,
            'type' => \App\Models\Review::TYPE_BUYER_TO_SELLER,
            'is_verified_purchase' => true,
            'status' => \App\Models\Review::STATUS_PUBLISHED,
        ]);

        // Bolt-style trip rating → stored on the delivery for the driver.
        $driverRating = isset($data['driver_rating']) ? (int) $data['driver_rating'] : null;
        if ($driverRating && $order->delivery) {
            $order->delivery->update([
                'delivery_rating' => $driverRating,
                'delivery_comment' => $driverComment === '' ? null : $driverComment,
            ]);
        }

        \App\Models\OrderTimeline::log(
            $order,
            $order->status,
            "Buyer rated order {$data['rating']}/5" .
                ($driverRating ? " and trip {$driverRating}/5" : ''),
            ['order_id' => $order->id, 'review_id' => $review->id]
        );

        return response()->json([
            'status' => 'success',
            'message' => 'Thanks for your review!',
            'data' => [
                'review' => [
                    'id' => $review->id,
                    'rating' => (int) $review->rating,
                    'comment' => $review->comment,
                    'driver_rating' => $driverRating,
                    'created_at' => optional($review->created_at)?->toIso8601String(),
                ],
            ],
        ], 201);
    }

    /**
     * Get order timeline
     */
    public function timeline($id): JsonResponse
    {
        $user = Auth::user();
        $order = Order::findOrFail($id);

        // Check access
        if ($order->buyer_id !== $user->id && $order->seller_id !== $user->id && !$user->isAdmin()) {
            return response()->json([
                'status' => 'error',
                'message' => 'You do not have permission to view this timeline'
            ], 403);
        }

        $timeline = $order->timeline()
            ->with('creator')
            ->orderBy('created_at', 'asc')
            ->get();

        return response()->json([
            'status' => 'success',
            'data' => [
                'order_id' => $order->id,
                'order_number' => $order->order_number,
                'timeline' => $timeline,
            ]
        ]);
    }

    /**
     * Export orders to CSV/Excel
     */
    public function export(Request $request): JsonResponse
    {
        $user = $request->user();

        if (!$user->isAdmin() && !$user->isSuperAdmin()) {
            return response()->json([
                'status' => 'error',
                'message' => 'Unauthorized access'
            ], 403);
        }

        $request->validate([
            'format' => 'in:csv,xlsx,pdf',
            'date_from' => 'nullable|date',
            'date_to' => 'nullable|date|after:date_from',
            'status' => 'nullable|string',
        ]);

        try {
            $export = new OrdersExport($request->all());
            $filename = 'orders_' . date('Y-m-d_H-i-s') . '.' . ($request->format ?? 'csv');

            // Generate under public/assets so the apps can download it directly.
            $targetDir = public_path('assets/exports');
            if (!is_dir($targetDir)) {
                mkdir($targetDir, 0755, true);
            }
            $tmpDir = storage_path('app/private/tmp');
            if (!is_dir($tmpDir)) {
                mkdir($tmpDir, 0755, true);
            }

            Excel::store($export, 'tmp/' . $filename, 'local');
            rename(
                $tmpDir . '/' . $filename,
                $targetDir . '/' . $filename,
            );

            return response()->json([
                'status' => 'success',
                'message' => 'Export generated successfully',
                'data' => [
                    'filename' => $filename,
                    'download_url' => asset('assets/exports/' . $filename),
                    'expires_at' => now()->addHours(24)->toIso8601String(),
                ],
            ]);
        } catch (\Exception $e) {
            Log::error('Order export failed', [
                'error' => $e->getMessage(),
                'user_id' => $user->id,
            ]);

            return response()->json([
                'status' => 'error',
                'message' => 'Failed to generate export. Please try again.',
            ], 500);
        }
    }

    /**
     * Get order statistics
     */
    public function statistics(Request $request): JsonResponse
    {
        $user = $request->user();

        $stats = [
            'total' => Order::where('buyer_id', $user->id)->count(),
            'pending' => Order::where('buyer_id', $user->id)
                ->where('status', Order::STATUS_PENDING)->count(),
            'processing' => Order::where('buyer_id', $user->id)
                ->where('status', Order::STATUS_PROCESSING)->count(),
            'in_transit' => Order::where('buyer_id', $user->id)
                ->where('status', Order::STATUS_IN_TRANSIT)->count(),
            'delivered' => Order::where('buyer_id', $user->id)
                ->where('status', Order::STATUS_DELIVERED)->count(),
            'completed' => Order::where('buyer_id', $user->id)
                ->where('status', Order::STATUS_COMPLETED)->count(),
            'cancelled' => Order::where('buyer_id', $user->id)
                ->where('status', Order::STATUS_CANCELLED)->count(),
        ];

        return response()->json([
            'status' => 'success',
            'data' => $stats,
        ]);
    }

    /**
     * Order metrics (sellers + admins).
     * GET /orders/metrics?days=30
     */
    public function metrics(Request $request): JsonResponse
    {
        $user = $request->user();

        $sellerId = null;
        if (! $user->isAdmin()) {
            if (! $user->isSeller()) {
                return response()->json([
                    'status' => 'error',
                    'message' => 'Only sellers and admins can view order metrics',
                ], 403);
            }
            $sellerId = (int) $user->id;
        }

        $days = max(1, min((int) $request->integer('days', 30), 365));

        return response()->json([
            'status' => 'success',
            'data' => [
                'daily' => $this->orderAnalyticsService->getDailyMetrics($days, $sellerId),
                'completion_rate' => $this->orderAnalyticsService->getCompletionRate($sellerId),
                'average_order_value' => $this->orderAnalyticsService->getAverageOrderValue($sellerId),
            ],
        ]);
    }

    /**
     * Platform order analytics (admin only).
     * GET /orders/analytics?days=30&year=2026&limit=10
     */
    public function analytics(Request $request): JsonResponse
    {
        $user = $request->user();

        if (! $user->isAdmin() && ! $user->isSuperAdmin()) {
            return response()->json([
                'status' => 'error',
                'message' => 'Unauthorized access',
            ], 403);
        }

        $days = max(1, min((int) $request->integer('days', 30), 365));
        $year = (int) $request->integer('year', now()->year);
        $limit = max(1, min((int) $request->integer('limit', 10), 50));

        return response()->json([
            'status' => 'success',
            'data' => [
                'daily' => $this->orderAnalyticsService->getDailyMetrics($days),
                'monthly' => $this->orderAnalyticsService->getMonthlyMetrics($year),
                'top_products' => $this->orderAnalyticsService->getTopProducts($limit),
                'completion_rate' => $this->orderAnalyticsService->getCompletionRate(),
                'average_order_value' => $this->orderAnalyticsService->getAverageOrderValue(),
                'status_breakdown' => Order::query()
                    ->select('status', DB::raw('COUNT(*) as total'))
                    ->groupBy('status')
                    ->pluck('total', 'status'),
            ],
        ]);
    }

    /**
     * Bulk update order status (admin only).
     * POST /orders/bulk-status
     */
    public function bulkUpdateStatus(Request $request): JsonResponse
    {
        $data = $request->validate([
            'ids' => ['required', 'array', 'min:1', 'max:200'],
            'ids.*' => ['integer', 'exists:orders,id'],
            'status' => ['required', 'in:confirmed,processing,ready_for_delivery,dispatched,in_transit,delivered,completed,cancelled'],
            'reason' => ['required_if:status,cancelled', 'nullable', 'string', 'max:500'],
        ]);

        $target = $data['status'];
        $user = $request->user();
        $updated = 0;
        $skipped = 0;

        DB::beginTransaction();
        try {
            $orders = Order::whereIn('id', $data['ids'])->lockForUpdate()->get();

            foreach ($orders as $order) {
                if ($order->status === $target) {
                    $skipped++;
                    continue;
                }

                if ($target === Order::STATUS_CANCELLED && ! $order->canCancel()) {
                    $skipped++;
                    continue;
                }

                $oldStatus = $order->status;
                $attributes = ['status' => $target];

                if ($target === Order::STATUS_CANCELLED) {
                    $attributes['cancellation_reason'] = $data['reason'] ?? 'Bulk cancelled by admin';
                    $attributes['cancelled_by'] = $user->id;
                }
                if ($target === Order::STATUS_DELIVERED) {
                    $attributes['delivered_at'] = now();
                }

                $order->update($attributes);

                if ($target === Order::STATUS_CANCELLED) {
                    if ($order->payment_status === Order::PAYMENT_STATUS_PAID) {
                        dispatch(new ProcessRefund($order));
                    }
                    foreach ($order->orderItems as $item) {
                        $item->product?->increment('stock_quantity', $item->quantity);
                    }
                }
                if ($target === Order::STATUS_COMPLETED) {
                    dispatch(new ReleasePaymentToSeller($order));
                }

                OrderTimeline::logStatusChange($order, $oldStatus, $target, $data['reason'] ?? null);

                if ($oldStatus !== $target) {
                    event(new OrderStatusChanged($order, $oldStatus, $target));
                    dispatch(new SendOrderStatusNotification($order, $oldStatus, $target));
                }

                $updated++;
            }

            DB::commit();
        } catch (\Throwable $e) {
            DB::rollBack();
            Log::error('Bulk order status update failed', [
                'ids' => $data['ids'],
                'status' => $target,
                'user_id' => $user->id,
                'error' => $e->getMessage(),
            ]);

            return response()->json([
                'status' => 'error',
                'message' => 'Failed to update orders. Please try again.',
            ], 500);
        }

        return response()->json([
            'status' => 'success',
            'message' => "Updated {$updated} order(s); skipped {$skipped}.",
            'data' => [
                'updated' => $updated,
                'skipped' => $skipped,
                'status' => $target,
            ],
        ]);
    }
}
