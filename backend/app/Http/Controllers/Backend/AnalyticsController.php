<?php

namespace App\Http\Controllers\Backend;

use App\Http\Controllers\Controller;
use App\Models\Delivery;
use App\Models\Order;
use App\Models\Payment;
use App\Models\Product;
use App\Models\SellerProfile;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Inertia\Inertia;
use Inertia\Response;

class AnalyticsController extends Controller
{
    public function index(): Response
    {
        $orderStatus = Order::query()
            ->select('status', DB::raw('COUNT(*) as count'))
            ->groupBy('status')
            ->pluck('count', 'status');

        $paymentStatus = Payment::query()
            ->select('status', DB::raw('COUNT(*) as count'))
            ->groupBy('status')
            ->pluck('count', 'status');

        $topProducts = Product::query()
            ->orderByDesc('orders_count')
            ->limit(10)
            ->get(['id', 'name', 'orders_count', 'avg_rating', 'price_per_unit'])
            ->map(fn (Product $p) => [
                'id' => $p->id,
                'name' => $p->name,
                'orders_count' => $p->orders_count,
                'avg_rating' => $p->avg_rating,
                'price_per_unit' => (float) $p->price_per_unit,
            ]);

        $topSellers = SellerProfile::query()
            ->withCount('orders')
            ->orderByDesc('orders_count')
            ->limit(10)
            ->get(['id', 'business_name', 'status'])
            ->map(fn (SellerProfile $s) => [
                'id' => $s->id,
                'business_name' => $s->business_name,
                'status' => $s->status,
                'orders_count' => $s->orders_count,
            ]);

        return Inertia::render('backend/Analytics/index', [
            'kpis' => [
                'users' => User::count(),
                'sellers' => SellerProfile::count(),
                'products' => Product::count(),
                'orders' => Order::count(),
                'revenue' => (float) Order::where('status', Order::STATUS_COMPLETED)->sum('total_amount'),
                'active_deliveries' => Delivery::whereIn('status', [
                    Delivery::STATUS_IN_TRANSIT ?? 'in_transit',
                    Delivery::STATUS_ASSIGNED ?? 'assigned',
                ])->count(),
            ],
            'order_status' => $orderStatus,
            'payment_status' => $paymentStatus,
            'top_products' => $topProducts,
            'top_sellers' => $topSellers,
            'users_by_role' => [
                'buyers' => User::where('role', 'buyer')->count(),
                'sellers' => User::where('role', 'seller')->count(),
                'drivers' => User::where('role', 'driver')->count(),
                'admins' => User::whereIn('role', ['admin', 'super-admin'])->count(),
            ],
        ]);
    }
}
