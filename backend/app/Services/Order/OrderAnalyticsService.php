<?php
// app/Services/Order/OrderAnalyticsService.php

namespace App\Services\Order;

use App\Models\Order;
use Carbon\Carbon;
use Illuminate\Support\Facades\DB;

/**
 * Order analytics.
 *
 * All aggregation is done in PHP (or with portable SQL) so the same code
 * works on MySQL, PostgreSQL and SQLite (the test/default driver).
 */
class OrderAnalyticsService
{
    /**
     * Get order statistics for a buyer.
     */
    public function getUserOrderStats($userId): array
    {
        $totalOrders = Order::where('buyer_id', $userId)->count();
        $pendingOrders = Order::where('buyer_id', $userId)
            ->where('status', Order::STATUS_PENDING)
            ->count();
        $completedOrders = Order::where('buyer_id', $userId)
            ->where('status', Order::STATUS_COMPLETED)
            ->count();
        $cancelledOrders = Order::where('buyer_id', $userId)
            ->where('status', Order::STATUS_CANCELLED)
            ->count();

        $totalSpent = Order::where('buyer_id', $userId)
            ->where('status', Order::STATUS_COMPLETED)
            ->sum('total_amount');

        return [
            'total_orders' => $totalOrders,
            'pending_orders' => $pendingOrders,
            'completed_orders' => $completedOrders,
            'cancelled_orders' => $cancelledOrders,
            'total_spent' => $totalSpent,
            'formatted_total_spent' => 'GHS ' . number_format($totalSpent, 2),
        ];
    }

    /**
     * Get seller order statistics.
     */
    public function getSellerOrderStats($sellerId): array
    {
        $totalOrders = Order::where('seller_id', $sellerId)->count();
        $pendingOrders = Order::where('seller_id', $sellerId)
            ->where('status', Order::STATUS_PENDING)
            ->count();
        $processingOrders = Order::where('seller_id', $sellerId)
            ->where('status', Order::STATUS_PROCESSING)
            ->count();
        $completedOrders = Order::where('seller_id', $sellerId)
            ->where('status', Order::STATUS_COMPLETED)
            ->count();

        $totalRevenue = Order::where('seller_id', $sellerId)
            ->where('status', Order::STATUS_COMPLETED)
            ->sum('seller_earnings');

        $platformFees = Order::where('seller_id', $sellerId)
            ->where('status', Order::STATUS_COMPLETED)
            ->sum('platform_fee');

        return [
            'total_orders' => $totalOrders,
            'pending_orders' => $pendingOrders,
            'processing_orders' => $processingOrders,
            'completed_orders' => $completedOrders,
            'total_revenue' => $totalRevenue,
            'formatted_total_revenue' => 'GHS ' . number_format($totalRevenue, 2),
            'platform_fees' => $platformFees,
            'formatted_platform_fees' => 'GHS ' . number_format($platformFees, 2),
        ];
    }

    /**
     * Daily order metrics, optionally scoped to one seller.
     *
     * @return array<int, array<string, mixed>>
     */
    public function getDailyMetrics($days = 30, ?int $sellerId = null): array
    {
        $startDate = Carbon::now()->subDays(max(1, (int) $days))->startOfDay();

        $query = Order::query()->where('created_at', '>=', $startDate);
        if ($sellerId !== null) {
            $query->where('seller_id', $sellerId);
        }

        return $query->get(['created_at', 'total_amount', 'status'])
            ->groupBy(fn (Order $order) => $order->created_at->format('Y-m-d'))
            ->sortKeys()
            ->map(fn ($group, $date) => [
                'date' => $date,
                'total_orders' => $group->count(),
                'total_revenue' => round((float) $group->sum('total_amount'), 2),
                'completed_orders' => $group->where('status', Order::STATUS_COMPLETED)->count(),
                'cancelled_orders' => $group->where('status', Order::STATUS_CANCELLED)->count(),
            ])
            ->values()
            ->all();
    }

    /**
     * Monthly order metrics for a year, optionally scoped to one seller.
     *
     * @return array<int, array<string, mixed>>
     */
    public function getMonthlyMetrics($year = null, ?int $sellerId = null): array
    {
        $year = $year ?? now()->year;

        $query = Order::query()->whereYear('created_at', $year);
        if ($sellerId !== null) {
            $query->where('seller_id', $sellerId);
        }

        return $query->get(['created_at', 'total_amount', 'status'])
            ->groupBy(fn (Order $order) => $order->created_at->format('n'))
            ->sortKeys()
            ->map(fn ($group, $month) => [
                'month' => (int) $month,
                'total_orders' => $group->count(),
                'total_revenue' => round((float) $group->sum('total_amount'), 2),
                'completed_orders' => $group->where('status', Order::STATUS_COMPLETED)->count(),
            ])
            ->values()
            ->all();
    }

    /**
     * Top selling products, optionally scoped to one seller.
     *
     * @return array<int, array<string, mixed>>
     */
    public function getTopProducts($limit = 10, ?int $sellerId = null): array
    {
        $query = DB::table('order_items')
            ->join('orders', 'order_items.order_id', '=', 'orders.id')
            ->join('products', 'order_items.product_id', '=', 'products.id')
            ->select(
                'products.id',
                'products.name',
                DB::raw('COUNT(order_items.id) as total_orders'),
                DB::raw('SUM(order_items.quantity) as total_quantity'),
                DB::raw('SUM(order_items.subtotal) as total_revenue')
            )
            ->where('orders.status', Order::STATUS_COMPLETED);

        if ($sellerId !== null) {
            $query->where('orders.seller_id', $sellerId);
        }

        return $query
            ->groupBy('products.id', 'products.name')
            ->orderByDesc('total_orders')
            ->limit(max(1, (int) $limit))
            ->get()
            ->toArray();
    }

    /**
     * Order completion rate (0-100), optionally scoped to one seller.
     */
    public function getCompletionRate(?int $sellerId = null): float
    {
        $query = Order::query();
        if ($sellerId !== null) {
            $query->where('seller_id', $sellerId);
        }

        $total = (clone $query)->count();
        $completed = (clone $query)->where('status', Order::STATUS_COMPLETED)->count();

        if ($total === 0) {
            return 0;
        }

        return round(($completed / $total) * 100, 2);
    }

    /**
     * Average completed order value, optionally scoped to one seller.
     */
    public function getAverageOrderValue(?int $sellerId = null): float
    {
        $query = Order::where('status', Order::STATUS_COMPLETED);
        if ($sellerId !== null) {
            $query->where('seller_id', $sellerId);
        }

        return round((float) ($query->avg('total_amount') ?? 0), 2);
    }
}
