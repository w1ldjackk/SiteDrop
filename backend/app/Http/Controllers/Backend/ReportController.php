<?php

namespace App\Http\Controllers\Backend;

use App\Http\Controllers\Controller;
use App\Models\Delivery;
use App\Models\Order;
use App\Models\Payment;
use App\Models\Product;
use App\Models\SellerProfile;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Inertia\Inertia;
use Inertia\Response;

class ReportController extends Controller
{
    public function index(Request $request): Response
    {
        $period = $request->input('period', '30d');
        [$from, $to] = $this->range($period);

        $ordersInRange = Order::whereBetween('created_at', [$from, $to]);
        $paymentsInRange = Payment::whereBetween('created_at', [$from, $to])
            ->where('status', Payment::STATUS_SUCCESS);

        $dailyOrders = Order::query()
            ->select(DB::raw('DATE(created_at) as date'), DB::raw('COUNT(*) as count'), DB::raw('SUM(total_amount) as revenue'))
            ->whereBetween('created_at', [$from, $to])
            ->groupBy(DB::raw('DATE(created_at)'))
            ->orderBy('date')
            ->get()
            ->map(fn ($row) => [
                'date' => $row->date,
                'orders' => (int) $row->count,
                'revenue' => (float) $row->revenue,
            ]);

        return Inertia::render('backend/Reports/index', [
            'period' => $period,
            'summary' => [
                'orders' => (clone $ordersInRange)->count(),
                'revenue' => (float) (clone $ordersInRange)->where('status', Order::STATUS_COMPLETED)->sum('total_amount'),
                'payments' => (float) $paymentsInRange->sum('amount'),
                'new_users' => User::whereBetween('created_at', [$from, $to])->count(),
                'new_sellers' => SellerProfile::whereBetween('created_at', [$from, $to])->count(),
                'deliveries_completed' => Delivery::where('status', Delivery::STATUS_COMPLETED ?? 'completed')
                    ->whereBetween('completed_at', [$from, $to])
                    ->count(),
                'products' => Product::whereBetween('created_at', [$from, $to])->count(),
            ],
            'daily' => $dailyOrders,
            'from' => $from->toDateString(),
            'to' => $to->toDateString(),
        ]);
    }

    /** @return array{0: Carbon, 1: Carbon} */
    private function range(string $period): array
    {
        $to = now()->endOfDay();

        $from = match ($period) {
            '7d' => now()->subDays(7)->startOfDay(),
            '90d' => now()->subDays(90)->startOfDay(),
            'year' => now()->subYear()->startOfDay(),
            default => now()->subDays(30)->startOfDay(),
        };

        return [$from, $to];
    }
}
