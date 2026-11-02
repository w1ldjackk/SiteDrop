<?php
// app/Http/Controllers/Backend/DashController.php

namespace App\Http\Controllers\Backend;

use App\Http\Controllers\Controller;
use App\Models\ActivityLog;
use App\Models\Order;
use App\Models\User;
use App\Models\Product;
use App\Models\Delivery;
use App\Models\SellerProfile;
use App\Models\Site;
use App\Models\Truck;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Inertia\Inertia;

class DashController extends Controller
{
    /**
     * Show dashboard based on user role (Web)
     */
    public function index(Request $request)
    {
        $user = $request->user();

        // Get dashboard data
        $data = $this->getDashboardData($user);

        // Admin area only (buyer/seller/driver use their own route files).
        // Super-admin has a dedicated page; admin/ops-manager share Admin.
        if ($user->isSuperAdmin()) {
            return Inertia::render('backend/Dashboard/SuperAdminDashboard', $data);
        }

        return Inertia::render('backend/Dashboard/Admin', $data);
    }

    // ====================== API Methods for admin.php routes ======================

    /**
     * Get dashboard statistics (API)
     */
    public function stats(Request $request)
    {
        $period = $request->get('period', 'today');
        $dateRange = $this->getDateRange($period);

        $stats = [
            'users' => [
                'total' => User::count(),
                'new' => User::whereBetween('created_at', $dateRange)->count(),
                'buyers' => User::where('role', 'buyer')->count(),
                'sellers' => User::where('role', 'seller')->count(),
                'drivers' => User::where('role', 'driver')->count(),
                'growth' => $this->calculateGrowth('users', $period),
            ],
            'orders' => [
                'total' => Order::count(),
                'new' => Order::whereBetween('created_at', $dateRange)->count(),
                'pending' => Order::where('status', Order::STATUS_PENDING)->count(),
                'processing' => Order::where('status', Order::STATUS_PROCESSING)->count(),
                'completed' => Order::where('status', Order::STATUS_COMPLETED)->count(),
                'cancelled' => Order::where('status', Order::STATUS_CANCELLED)->count(),
                'revenue' => Order::where('status', Order::STATUS_COMPLETED)
                    ->whereBetween('created_at', $dateRange)
                    ->sum('total_amount'),
                'growth' => $this->calculateGrowth('orders', $period),
            ],
            'deliveries' => [
                'total' => Delivery::count(),
                'pending' => Delivery::where('status', Delivery::STATUS_PENDING)->count(),
                'in_transit' => Delivery::where('status', Delivery::STATUS_IN_TRANSIT)->count(),
                'completed' => Delivery::where('status', Delivery::STATUS_COMPLETED)->count(),
                'failed' => Delivery::where('status', Delivery::STATUS_FAILED)->count(),
                'growth' => $this->calculateGrowth('deliveries', $period),
            ],
            'products' => [
                'total' => Product::count(),
                'available' => Product::where('is_available', true)->count(),
                'featured' => Product::where('is_featured', true)->count(),
                'new' => Product::whereBetween('created_at', $dateRange)->count(),
            ],
            'sellers' => [
                'total' => SellerProfile::count(),
                'pending' => SellerProfile::where('status', 'pending')->count(),
                'approved' => SellerProfile::where('status', 'approved')->count(),
                'suspended' => SellerProfile::where('status', 'suspended')->count(),
            ],
            'revenue' => [
                'total' => Order::where('status', Order::STATUS_COMPLETED)->sum('total_amount'),
                'platform_fee' => Order::where('status', Order::STATUS_COMPLETED)->sum('platform_fee'),
                'seller_earnings' => Order::where('status', Order::STATUS_COMPLETED)->sum('seller_earnings'),
                'this_period' => Order::where('status', Order::STATUS_COMPLETED)
                    ->whereBetween('created_at', $dateRange)
                    ->sum('total_amount'),
                'growth' => $this->calculateGrowth('revenue', $period),
            ],
        ];

        return response()->json([
            'status' => 'success',
            'data' => $stats,
        ]);
    }

    /**
     * Get chart data for dashboard (API)
     */
    public function charts(Request $request)
    {
        $period = $request->get('period', 'month');
        $days = $this->getDaysFromPeriod($period);

        // Combined series for the admin dashboard Recharts component
        $chartData = $this->getChartData($days);

        // Separate series (API clients / widgets)
        $revenueData = $this->getRevenueChartData($days);
        $ordersData = $this->getOrdersChartData($days);
        $usersData = $this->getUsersChartData($days);

        return response()->json([
            'status' => 'success',
            'data' => [
                'chart_data' => $chartData,
                'revenue' => $revenueData,
                'orders' => $ordersData,
                'users' => $usersData,
                'period' => $period,
                'days' => $days,
            ],
        ]);
    }

    /**
     * Get recent activity (API) — paginated for the admin dashboard widget.
     */
    public function recentActivity(Request $request)
    {
        $perPage = max(4, min(50, (int) $request->get('per_page', 4)));
        $page = max(1, (int) $request->get('page', 1));

        $result = $this->getRecentActivityPaginated($perPage, $page);

        return response()->json([
            'status' => 'success',
            'data' => $result['data'],
            'meta' => [
                'current_page' => $result['current_page'],
                'last_page' => $result['last_page'],
                'per_page' => $result['per_page'],
                'total' => $result['total'],
            ],
        ]);
    }

    /**
     * Get quick stats for dashboard widgets (API)
     */
    public function quickStats(Request $request)
    {
        $today = Carbon::today();
        $yesterday = Carbon::yesterday();

        $stats = [
            'today' => [
                'orders' => Order::whereDate('created_at', $today)->count(),
                'revenue' => Order::whereDate('created_at', $today)
                    ->where('status', Order::STATUS_COMPLETED)
                    ->sum('total_amount'),
                'new_users' => User::whereDate('created_at', $today)->count(),
                'deliveries' => Delivery::whereDate('created_at', $today)->count(),
            ],
            'yesterday' => [
                'orders' => Order::whereDate('created_at', $yesterday)->count(),
                'revenue' => Order::whereDate('created_at', $yesterday)
                    ->where('status', Order::STATUS_COMPLETED)
                    ->sum('total_amount'),
                'new_users' => User::whereDate('created_at', $yesterday)->count(),
                'deliveries' => Delivery::whereDate('created_at', $yesterday)->count(),
            ],
            'pending_actions' => [
                'seller_approvals' => SellerProfile::where('status', 'pending')->count(),
                'pending_orders' => Order::where('status', Order::STATUS_PENDING)->count(),
                'pending_deliveries' => Delivery::where('status', Delivery::STATUS_PENDING)->count(),
                'reported_reviews' => \App\Models\Review::where('status', 'reported')->count(),
            ],
        ];

        return response()->json([
            'status' => 'success',
            'data' => $stats,
        ]);
    }

    // ====================== Dashboard Data Methods ======================

    /**
     * Get dashboard data for all roles
     */
    private function getDashboardData($user): array
    {
        $baseData = [
            'user' => $user,
            'breadcrumbs' => [
                ['title' => 'Dashboard', 'href' => $user->homePath()],
            ],
        ];

        if ($user->isSuperAdmin() || $user->isAdmin()) {
            return array_merge($baseData, $this->getAdminDashboardData());
        }

        if ($user->isSeller()) {
            return array_merge($baseData, $this->getSellerDashboardData($user));
        }

        if ($user->isDriver()) {
            return array_merge($baseData, $this->getDriverDashboardData($user));
        }

        // Buyer dashboard
        return array_merge($baseData, $this->getBuyerDashboardData($user));
    }

    /**
     * Get Admin/Super Admin dashboard data
     */
    private function getAdminDashboardData(): array
    {
        $today = Carbon::today();
        $thisMonth = Carbon::now()->month;

        // Quick Stats
        $stats = [
            'total_orders' => Order::count(),
            'total_users' => User::count(),
            'total_sellers' => SellerProfile::count(),
            'total_products' => Product::count(),
            'total_sites' => Site::count(),
            'total_trucks' => Truck::count(),
        ];

        // Recent Activity
        // First page of platform activity (4 per page, paginated in the UI)
        $recentActivity = $this->getRecentActivityPaginated(4, 1);

        // Revenue Stats
        $revenueData = [
            'total_revenue' => Order::where('status', Order::STATUS_COMPLETED)->sum('total_amount'),
            'platform_fee' => Order::where('status', Order::STATUS_COMPLETED)->sum('platform_fee'),
            'seller_earnings' => Order::where('status', Order::STATUS_COMPLETED)->sum('seller_earnings'),
            'monthly_revenue' => Order::where('status', Order::STATUS_COMPLETED)
                ->whereMonth('created_at', $thisMonth)
                ->sum('total_amount'),
            'today_revenue' => Order::where('status', Order::STATUS_COMPLETED)
                ->whereDate('created_at', $today)
                ->sum('total_amount'),
        ];

        // Order Stats
        $orderStats = [
            'pending' => Order::where('status', Order::STATUS_PENDING)->count(),
            'processing' => Order::where('status', Order::STATUS_PROCESSING)->count(),
            'in_transit' => Order::where('status', Order::STATUS_IN_TRANSIT)->count(),
            'completed' => Order::where('status', Order::STATUS_COMPLETED)->count(),
            'cancelled' => Order::where('status', Order::STATUS_CANCELLED)->count(),
        ];

        // Seller Stats
        $sellerStats = [
            'pending_approval' => SellerProfile::where('status', 'pending')->count(),
            'approved' => SellerProfile::where('status', 'approved')->count(),
            'suspended' => SellerProfile::where('status', 'suspended')->count(),
        ];

        // Delivery Stats
        $deliveryStats = [
            'pending' => Delivery::where('status', Delivery::STATUS_PENDING)->count(),
            'assigned' => Delivery::where('status', Delivery::STATUS_ASSIGNED)->count(),
            'in_transit' => Delivery::where('status', Delivery::STATUS_IN_TRANSIT)->count(),
            'completed' => Delivery::where('status', Delivery::STATUS_COMPLETED)->count(),
            'failed' => Delivery::where('status', Delivery::STATUS_FAILED)->count(),
        ];

        // Chart Data (last 30 days)
        $chartData = $this->getChartData(30);

        // Quick Actions
        $quickActions = $this->getQuickActions('admin');

        // Platform Health
        $platformHealth = $this->getPlatformHealth();

        return [
            'stats' => $stats,
            'recent_activity' => $recentActivity,
            'revenue_data' => $revenueData,
            'order_stats' => $orderStats,
            'seller_stats' => $sellerStats,
            'delivery_stats' => $deliveryStats,
            'chart_data' => $chartData,
            'quick_actions' => $quickActions,
            'platform_health' => $platformHealth,
        ];
    }

    /**
     * Get Seller dashboard data
     */
    private function getSellerDashboardData($user): array
    {
        $sellerId = $user->id;
        $today = Carbon::today();

        // Seller Profile
        $sellerProfile = SellerProfile::where('user_id', $sellerId)->first();

        // Order Stats
        $orderStats = [
            'total' => Order::where('seller_id', $sellerId)->count(),
            'pending' => Order::where('seller_id', $sellerId)
                ->where('status', Order::STATUS_PENDING)->count(),
            'processing' => Order::where('seller_id', $sellerId)
                ->where('status', Order::STATUS_PROCESSING)->count(),
            'completed' => Order::where('seller_id', $sellerId)
                ->where('status', Order::STATUS_COMPLETED)->count(),
            'cancelled' => Order::where('seller_id', $sellerId)
                ->where('status', Order::STATUS_CANCELLED)->count(),
        ];

        // Revenue
        $revenue = [
            'total' => Order::where('seller_id', $sellerId)
                ->where('status', Order::STATUS_COMPLETED)
                ->sum('total_amount'),
            'platform_fee' => Order::where('seller_id', $sellerId)
                ->where('status', Order::STATUS_COMPLETED)
                ->sum('platform_fee'),
            'earnings' => Order::where('seller_id', $sellerId)
                ->where('status', Order::STATUS_COMPLETED)
                ->sum('seller_earnings'),
            'today' => Order::where('seller_id', $sellerId)
                ->where('status', Order::STATUS_COMPLETED)
                ->whereDate('created_at', $today)
                ->sum('seller_earnings'),
        ];

        // Product Stats
        $productStats = [
            'total' => Product::where('seller_id', $sellerId)->count(),
            'available' => Product::where('seller_id', $sellerId)
                ->where('is_available', true)->count(),
            'out_of_stock' => Product::where('seller_id', $sellerId)
                ->where('stock_quantity', 0)->count(),
            'featured' => Product::where('seller_id', $sellerId)
                ->where('is_featured', true)->count(),
        ];

        // Recent Orders
        $recentOrders = Order::where('seller_id', $sellerId)
            ->with(['buyer', 'product'])
            ->orderBy('created_at', 'desc')
            ->limit(10)
            ->get();

        // Rating
        $rating = [
            'average' => \App\Models\Review::where('reviewee_id', $sellerId)
                ->avg('rating') ?? 0,
            'total' => \App\Models\Review::where('reviewee_id', $sellerId)->count(),
        ];

        // Quick Actions
        $quickActions = $this->getQuickActions('seller');

        return [
            'seller_profile' => $sellerProfile,
            'order_stats' => $orderStats,
            'revenue' => $revenue,
            'product_stats' => $productStats,
            'recent_orders' => $recentOrders,
            'rating' => $rating,
            'quick_actions' => $quickActions,
        ];
    }

    /**
     * Get Driver dashboard data
     */
    private function getDriverDashboardData($user): array
    {
        $driverId = $user->id;

        // Delivery Stats
        $deliveryStats = [
            'total' => Delivery::where('driver_id', $driverId)->count(),
            'pending' => Delivery::where('driver_id', $driverId)
                ->where('status', Delivery::STATUS_PENDING)->count(),
            'assigned' => Delivery::where('driver_id', $driverId)
                ->where('status', Delivery::STATUS_ASSIGNED)->count(),
            'accepted' => Delivery::where('driver_id', $driverId)
                ->where('status', Delivery::STATUS_ACCEPTED)->count(),
            'in_transit' => Delivery::where('driver_id', $driverId)
                ->where('status', Delivery::STATUS_IN_TRANSIT)->count(),
            'completed' => Delivery::where('driver_id', $driverId)
                ->where('status', Delivery::STATUS_COMPLETED)->count(),
            'failed' => Delivery::where('driver_id', $driverId)
                ->where('status', Delivery::STATUS_FAILED)->count(),
        ];

        // Earnings (70% share, floored on the standard base fee so
        // free-delivery promos still pay out — mirrors driver_payout).
        // CASE instead of GREATEST() keeps the query portable (SQLite/Postgres).
        $payoutBase = '(CASE WHEN COALESCE(delivery_fee, 0) > 20 THEN delivery_fee ELSE 20 END)';
        $earnings = [
            'total' => Delivery::where('driver_id', $driverId)
                ->where('status', Delivery::STATUS_COMPLETED)
                ->sum(DB::raw("{$payoutBase} * 0.70")),
            'this_month' => Delivery::where('driver_id', $driverId)
                ->where('status', Delivery::STATUS_COMPLETED)
                ->whereMonth('created_at', Carbon::now()->month)
                ->sum(DB::raw("{$payoutBase} * 0.70")),
            'today' => Delivery::where('driver_id', $driverId)
                ->where('status', Delivery::STATUS_COMPLETED)
                ->whereDate('created_at', Carbon::today())
                ->sum(DB::raw("{$payoutBase} * 0.70")),
        ];

        // Current Assignment
        $currentDelivery = Delivery::where('driver_id', $driverId)
            ->whereIn('status', [
                Delivery::STATUS_ASSIGNED,
                Delivery::STATUS_ACCEPTED,
                Delivery::STATUS_PICKED_UP,
                Delivery::STATUS_IN_TRANSIT,
            ])
            ->with(['order', 'order.buyer'])
            ->first();

        // Recent Deliveries
        $recentDeliveries = Delivery::where('driver_id', $driverId)
            ->with(['order'])
            ->orderBy('created_at', 'desc')
            ->limit(10)
            ->get();

        // Truck Assignment
        $truck = Truck::where('driver_id', $driverId)
            ->where('status', 'available')
            ->first();

        // Quick Actions
        $quickActions = $this->getQuickActions('driver');

        return [
            'delivery_stats' => $deliveryStats,
            'earnings' => $earnings,
            'current_delivery' => $currentDelivery,
            'recent_deliveries' => $recentDeliveries,
            'truck' => $truck,
            'quick_actions' => $quickActions,
        ];
    }

    /**
     * Get Buyer dashboard data
     */
    private function getBuyerDashboardData($user): array
    {
        $buyerId = $user->id;

        // Order Stats
        $orderStats = [
            'total' => Order::where('buyer_id', $buyerId)->count(),
            'pending' => Order::where('buyer_id', $buyerId)
                ->where('status', Order::STATUS_PENDING)->count(),
            'processing' => Order::where('buyer_id', $buyerId)
                ->where('status', Order::STATUS_PROCESSING)->count(),
            'in_transit' => Order::where('buyer_id', $buyerId)
                ->where('status', Order::STATUS_IN_TRANSIT)->count(),
            'completed' => Order::where('buyer_id', $buyerId)
                ->where('status', Order::STATUS_COMPLETED)->count(),
            'cancelled' => Order::where('buyer_id', $buyerId)
                ->where('status', Order::STATUS_CANCELLED)->count(),
        ];

        // Spending
        $spending = [
            'total' => Order::where('buyer_id', $buyerId)
                ->where('status', Order::STATUS_COMPLETED)
                ->sum('total_amount'),
            'this_month' => Order::where('buyer_id', $buyerId)
                ->where('status', Order::STATUS_COMPLETED)
                ->whereMonth('created_at', Carbon::now()->month)
                ->sum('total_amount'),
            'average_order' => Order::where('buyer_id', $buyerId)
                ->where('status', Order::STATUS_COMPLETED)
                ->avg('total_amount') ?? 0,
        ];

        // Recent Orders
        $recentOrders = Order::where('buyer_id', $buyerId)
            ->with(['product', 'seller'])
            ->orderBy('created_at', 'desc')
            ->limit(10)
            ->get();

        // Active Deliveries
        $activeDeliveries = Delivery::whereHas('order', function ($q) use ($buyerId) {
            $q->where('buyer_id', $buyerId);
        })->whereIn('status', [
            Delivery::STATUS_ASSIGNED,
            Delivery::STATUS_ACCEPTED,
            Delivery::STATUS_PICKED_UP,
            Delivery::STATUS_IN_TRANSIT,
        ])->with(['order', 'driver'])
            ->get();

        // Recommended Products
        $recommendedProducts = Product::where('is_available', true)
            ->where('is_featured', true)
            ->with(['seller'])
            ->limit(6)
            ->get();

        // Quick Actions
        $quickActions = $this->getQuickActions('buyer');

        return [
            'order_stats' => $orderStats,
            'spending' => $spending,
            'recent_orders' => $recentOrders,
            'active_deliveries' => $activeDeliveries,
            'recommended_products' => $recommendedProducts,
            'quick_actions' => $quickActions,
        ];
    }

    // ====================== Helper Methods ======================

    private function getDateRange(string $period): array
    {
        $end = Carbon::now();

        switch ($period) {
            case 'today':
                $start = Carbon::today();
                break;
            case 'week':
                $start = Carbon::now()->subWeek();
                break;
            case 'month':
                $start = Carbon::now()->subMonth();
                break;
            case 'quarter':
                $start = Carbon::now()->subQuarter();
                break;
            case 'year':
                $start = Carbon::now()->subYear();
                break;
            default:
                $start = Carbon::today();
        }

        return [$start, $end];
    }

    private function getDaysFromPeriod(string $period): int
    {
        return match ($period) {
            'today', '1_day', '1_days' => 1,
            'week', '7_days' => 7,
            'month', '30_days' => 30,
            'quarter', '90_days' => 90,
            'year', '365_days' => 365,
            default => 30,
        };
    }

    private function calculateGrowth(string $metric, string $period): float
    {
        $currentRange = $this->getDateRange($period);
        $previousRange = [
            Carbon::parse($currentRange[0])->subDays($this->getDaysFromPeriod($period)),
            Carbon::parse($currentRange[1])->subDays($this->getDaysFromPeriod($period)),
        ];

        $current = $this->getMetricValue($metric, $currentRange);
        $previous = $this->getMetricValue($metric, $previousRange);

        if ($previous == 0) {
            return $current > 0 ? 100 : 0;
        }

        return round((($current - $previous) / $previous) * 100, 2);
    }

    private function getMetricValue(string $metric, array $range): float
    {
        switch ($metric) {
            case 'users':
                return User::whereBetween('created_at', $range)->count();
            case 'orders':
                return Order::whereBetween('created_at', $range)->count();
            case 'deliveries':
                return Delivery::whereBetween('created_at', $range)->count();
            case 'revenue':
                return Order::where('status', Order::STATUS_COMPLETED)
                    ->whereBetween('created_at', $range)
                    ->sum('total_amount');
            default:
                return 0;
        }
    }

    /**
     * Paginated recent platform activity (min 4 per page).
     * Prefers activity_logs; falls back to orders + users.
     *
     * @return array{
     *     data: list<array<string, mixed>>,
     *     current_page: int,
     *     last_page: int,
     *     per_page: int,
     *     total: int
     * }
     */
    private function getRecentActivityPaginated(int $perPage = 4, int $page = 1): array
    {
        $perPage = max(4, $perPage);
        $page = max(1, $page);

        if (class_exists(ActivityLog::class)) {
            try {
                $paginator = ActivityLog::query()
                    ->with(['user:id,name,role'])
                    ->latest('id')
                    ->paginate($perPage, ['*'], 'page', $page);

                if ($paginator->total() > 0) {
                    $data = $paginator->getCollection()->map(function (ActivityLog $log) {
                        $color = (string) ($log->level_color ?? 'slate');
                        $colorKey = match ($color) {
                            'red', 'danger' => 'red',
                            'amber', 'warning', 'warn' => 'amber',
                            'indigo', 'blue' => 'indigo',
                            'emerald', 'green' => 'emerald',
                            'slate', 'gray', 'grey' => 'slate',
                            default => 'teal',
                        };

                        return [
                            'id' => $log->id,
                            'type' => $log->module ?? 'general',
                            'title' => $log->action_label ?: ($log->action ?? 'Activity'),
                            'subtitle' => $log->description
                                ?: (($log->user?->name ? $log->user->name.' · ' : '').($log->module ?? 'system')),
                            'time' => $log->created_at?->diffForHumans() ?? '',
                            'icon' => 'activity',
                            'color' => $colorKey,
                            'user' => $log->user?->name,
                        ];
                    })->values()->all();

                    return [
                        'data' => $data,
                        'current_page' => $paginator->currentPage(),
                        'last_page' => max(1, $paginator->lastPage()),
                        'per_page' => $paginator->perPage(),
                        'total' => $paginator->total(),
                    ];
                }
            } catch (\Throwable) {
                // Table may not exist yet during first deploy
            }
        }

        return $this->getFallbackActivityPaginated($perPage, $page);
    }

    /**
     * Fallback activity feed from recent orders + users (paginated).
     *
     * @return array{
     *     data: list<array<string, mixed>>,
     *     current_page: int,
     *     last_page: int,
     *     per_page: int,
     *     total: int
     * }
     */
    private function getFallbackActivityPaginated(int $perPage, int $page): array
    {
        $activities = [];

        $orders = Order::query()
            ->with(['buyer:id,name'])
            ->orderByDesc('created_at')
            ->limit(50)
            ->get();

        foreach ($orders as $order) {
            $activities[] = [
                'id' => 'order-'.$order->id,
                'type' => 'order',
                'title' => 'New order placed',
                'subtitle' => "Order #{$order->order_number} by ".($order->buyer->name ?? 'Buyer'),
                'time' => $order->created_at?->diffForHumans() ?? '',
                'sort_at' => optional($order->created_at)?->timestamp ?? 0,
                'icon' => 'shopping-bag',
                'color' => 'teal',
            ];
        }

        $users = User::query()
            ->orderByDesc('created_at')
            ->limit(50)
            ->get(['id', 'name', 'role', 'created_at']);

        foreach ($users as $user) {
            $activities[] = [
                'id' => 'user-'.$user->id,
                'type' => 'user',
                'title' => 'New user registered',
                'subtitle' => "{$user->name} - {$user->role}",
                'time' => $user->created_at?->diffForHumans() ?? '',
                'sort_at' => optional($user->created_at)?->timestamp ?? 0,
                'icon' => 'user-plus',
                'color' => 'indigo',
            ];
        }

        usort($activities, fn ($a, $b) => ($b['sort_at'] ?? 0) <=> ($a['sort_at'] ?? 0));

        $total = count($activities);
        $lastPage = max(1, (int) ceil($total / $perPage));
        $page = min($page, $lastPage);
        $offset = ($page - 1) * $perPage;

        $slice = array_slice($activities, $offset, $perPage);
        $data = array_map(function (array $row) {
            unset($row['sort_at']);

            return $row;
        }, $slice);

        return [
            'data' => array_values($data),
            'current_page' => $page,
            'last_page' => $lastPage,
            'per_page' => $perPage,
            'total' => $total,
        ];
    }

    /**
     * @deprecated Use getRecentActivityPaginated()
     */
    private function getRecentActivity($limit = 10): array
    {
        $result = $this->getRecentActivityPaginated(max(4, (int) $limit), 1);

        return $result['data'];
    }

    /**
     * Get chart data for admin dashboard
     */
    private function getChartData(int $days): array
    {
        $data = [];
        $startDate = Carbon::now()->subDays($days);

        for ($i = $days; $i >= 0; $i--) {
            $date = Carbon::now()->subDays($i);

            $orders = Order::whereDate('created_at', $date)->count();
            $revenue = Order::where('status', Order::STATUS_COMPLETED)
                ->whereDate('created_at', $date)
                ->sum('total_amount');
            $users = User::whereDate('created_at', $date)->count();

            $data[] = [
                'date' => $date->format('Y-m-d'),
                'label' => $date->format('M d'),
                'orders' => $orders,
                'revenue' => round($revenue, 2),
                'users' => $users,
            ];
        }

        return $data;
    }

    /**
     * Get revenue chart data
     */
    private function getRevenueChartData(int $days): array
    {
        $data = [];
        for ($i = $days; $i >= 0; $i--) {
            $date = Carbon::now()->subDays($i);
            $revenue = Order::where('status', Order::STATUS_COMPLETED)
                ->whereDate('created_at', $date)
                ->sum('total_amount');

            $data[] = [
                'date' => $date->format('Y-m-d'),
                'label' => $date->format('M d'),
                'revenue' => round($revenue, 2),
            ];
        }

        return $data;
    }

    /**
     * Get orders chart data
     */
    private function getOrdersChartData(int $days): array
    {
        $data = [];
        for ($i = $days; $i >= 0; $i--) {
            $date = Carbon::now()->subDays($i);
            $orders = Order::whereDate('created_at', $date)->count();
            $completed = Order::where('status', Order::STATUS_COMPLETED)
                ->whereDate('created_at', $date)
                ->count();

            $data[] = [
                'date' => $date->format('Y-m-d'),
                'label' => $date->format('M d'),
                'total' => $orders,
                'completed' => $completed,
            ];
        }

        return $data;
    }

    /**
     * Get users chart data
     */
    private function getUsersChartData(int $days): array
    {
        $data = [];
        for ($i = $days; $i >= 0; $i--) {
            $date = Carbon::now()->subDays($i);
            $count = User::whereDate('created_at', $date)->count();

            $data[] = [
                'date' => $date->format('Y-m-d'),
                'label' => $date->format('M d'),
                'users' => $count,
            ];
        }

        return $data;
    }

    /**
     * Get quick actions based on user role
     */
    private function getQuickActions(string $role): array
    {
        // Hrefs must match routes/{role}.php area prefixes.
        $actions = [
            'admin' => [
                [
                    'icon' => 'Users',
                    'label' => 'Manage Users',
                    'href' => '/admin/users',
                    'color' => 'indigo',
                ],
                [
                    'icon' => 'Store',
                    'label' => 'Manage Sellers',
                    'href' => '/admin/sellers',
                    'color' => 'teal',
                ],
                [
                    'icon' => 'ShoppingBag',
                    'label' => 'View Orders',
                    'href' => '/admin/orders',
                    'color' => 'emerald',
                ],
                [
                    'icon' => 'Settings',
                    'label' => 'System Settings',
                    'href' => '/admin/system-settings',
                    'color' => 'amber',
                ],
                [
                    'icon' => 'BarChart3',
                    'label' => 'Reports',
                    'href' => '/admin/reports',
                    'color' => 'purple',
                ],
                [
                    'icon' => 'Truck',
                    'label' => 'Manage Trucks',
                    'href' => '/admin/trucks',
                    'color' => 'blue',
                ],
            ],
            'seller' => [
                [
                    'icon' => 'Package',
                    'label' => 'Products',
                    'href' => '/seller/products',
                    'color' => 'teal',
                ],
                [
                    'icon' => 'ShoppingBag',
                    'label' => 'View Orders',
                    'href' => '/seller/orders',
                    'color' => 'indigo',
                ],
                [
                    'icon' => 'Truck',
                    'label' => 'Deliveries',
                    'href' => '/seller/deliveries',
                    'color' => 'emerald',
                ],
                [
                    'icon' => 'DollarSign',
                    'label' => 'Payments',
                    'href' => '/seller/payments',
                    'color' => 'amber',
                ],
                [
                    'icon' => 'Settings',
                    'label' => 'Settings',
                    'href' => '/seller/settings/profile',
                    'color' => 'purple',
                ],
            ],
            'driver' => [
                [
                    'icon' => 'Truck',
                    'label' => 'Deliveries',
                    'href' => '/driver/deliveries',
                    'color' => 'teal',
                ],
                [
                    'icon' => 'ShoppingBag',
                    'label' => 'Orders',
                    'href' => '/driver/orders',
                    'color' => 'indigo',
                ],
                [
                    'icon' => 'Settings',
                    'label' => 'Settings',
                    'href' => '/driver/settings/profile',
                    'color' => 'amber',
                ],
            ],
            'buyer' => [
                [
                    'icon' => 'ShoppingBag',
                    'label' => 'Browse Products',
                    'href' => '/buyer/products',
                    'color' => 'teal',
                ],
                [
                    'icon' => 'Package',
                    'label' => 'My Orders',
                    'href' => '/buyer/orders',
                    'color' => 'indigo',
                ],
                [
                    'icon' => 'Truck',
                    'label' => 'Deliveries',
                    'href' => '/buyer/deliveries',
                    'color' => 'emerald',
                ],
                [
                    'icon' => 'DollarSign',
                    'label' => 'Payments',
                    'href' => '/buyer/payments',
                    'color' => 'amber',
                ],
            ],
        ];

        return $actions[$role] ?? [];
    }

    /**
     * Get platform health metrics
     */
    private function getPlatformHealth(): array
    {
        $totalUsers = User::count();
        $activeUsers = User::where('last_active_at', '>=', Carbon::now()->subDays(30))->count();
        $activeSellers = SellerProfile::where('status', 'approved')->count();
        $completedOrders = Order::where('status', Order::STATUS_COMPLETED)->count();
        $totalOrders = Order::count();

        return [
            'active_users' => [
                'value' => $activeUsers,
                'total' => $totalUsers,
                'percentage' => $totalUsers > 0 ? round(($activeUsers / $totalUsers) * 100, 2) : 0,
            ],
            'active_sellers' => [
                'value' => $activeSellers,
                'total' => SellerProfile::count(),
                'percentage' => SellerProfile::count() > 0 ? round(($activeSellers / SellerProfile::count()) * 100, 2) : 0,
            ],
            'order_completion_rate' => [
                'value' => $completedOrders,
                'total' => $totalOrders,
                'percentage' => $totalOrders > 0 ? round(($completedOrders / $totalOrders) * 100, 2) : 0,
            ],
            'system_uptime' => '99.98%',
            'last_backup' => Carbon::now()->subHours(6)->format('Y-m-d H:i A'),
            'total_revenue' => Order::where('status', Order::STATUS_COMPLETED)->sum('total_amount'),
        ];
    }
}
