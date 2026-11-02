<?php

namespace App\Http\Controllers\Backend;

use App\Http\Controllers\Concerns\ScopesByRoleArea;
use App\Http\Controllers\Controller;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\OrderTimeline;
use App\Models\Product;
use App\Models\User;
use App\Services\Activity\ActivityLogger;
use App\Services\Order\OrderFeeCalculator;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use Inertia\Inertia;
use Inertia\Response;

class OrderController extends Controller
{
    use ScopesByRoleArea;

    public function index(Request $request): Response
    {
        $user = $request->user();
        abort_unless($this->canViewOrders($user), 403);

        $query = Order::query()
            ->with([
                'buyer:id,name,email,phone',
                'seller:id,name,email,phone',
                'product:id,name',
                'orderItems.product:id,name',
            ])
            ->withCount('orderItems')
            ->latest();

        $this->scopeOrdersQuery($query, $user);

        if ($search = $request->input('search')) {
            $query->where(function ($q) use ($search) {
                $q->where('order_number', 'like', "%{$search}%")
                    ->orWhereHas('buyer', fn ($b) => $b->where('name', 'like', "%{$search}%"))
                    ->orWhereHas('seller', fn ($s) => $s->where('name', 'like', "%{$search}%"));
            });
        }

        if ($status = $request->input('status')) {
            $query->where('status', $status);
        }

        if ($paymentStatus = $request->input('payment_status')) {
            $query->where('payment_status', $paymentStatus);
        }

        $orders = $query->paginate((int) $request->input('per_page', 15))
            ->withQueryString()
            ->through(fn (Order $o) => $this->transformList($o));

        return Inertia::render('backend/Orders/index', [
            'orders' => $orders,
            'filters' => $request->only(['search', 'status', 'payment_status']),
            'statuses' => $this->statuses(),
            'payment_statuses' => $this->paymentStatuses(),
            'area' => $this->roleAreaPrefix($request),
            'can' => [
                'create' => $this->can($user, 'create orders', 'manage orders'),
                'update' => $this->can($user, 'edit orders', 'process orders', 'manage orders'),
                'delete' => $this->can($user, 'delete orders', 'manage orders'),
            ],
        ]);
    }

    public function create(Request $request): Response
    {
        abort_unless($this->can($request->user(), 'create orders', 'manage orders'), 403);

        return Inertia::render('backend/Orders/create', [
            'statuses' => $this->statuses(),
            'payment_statuses' => $this->paymentStatuses(),
            'payment_methods' => $this->paymentMethods(),
            'buyers' => User::query()
                ->where(function ($q) {
                    $q->where('role', 'buyer')
                        ->orWhereHas('roles', fn ($r) => $r->where('name', 'buyer'));
                })
                ->orderBy('name')
                ->limit(150)
                ->get(['id', 'name', 'email', 'phone'])
                ->map(fn (User $u) => [
                    'id' => $u->id,
                    'label' => trim($u->name.' · '.($u->email ?: $u->phone ?: '#'.$u->id)),
                ]),
            'sellers' => User::query()
                ->where(function ($q) {
                    $q->where('role', 'seller')
                        ->orWhereHas('roles', fn ($r) => $r->where('name', 'seller'));
                })
                ->orderBy('name')
                ->limit(150)
                ->get(['id', 'name', 'email', 'phone'])
                ->map(fn (User $u) => [
                    'id' => $u->id,
                    'label' => trim($u->name.' · '.($u->email ?: $u->phone ?: '#'.$u->id)),
                ]),
            'products' => Product::query()
                ->orderBy('name')
                ->limit(200)
                ->get(['id', 'name', 'seller_id', 'price_per_unit', 'unit'])
                ->map(fn (Product $p) => [
                    'id' => $p->id,
                    'name' => $p->name,
                    'seller_id' => $p->seller_id,
                    'price_per_unit' => (float) $p->price_per_unit,
                    'unit' => $p->unit,
                    'label' => $p->name.' (GHS '.number_format((float) $p->price_per_unit, 2).'/'.($p->unit ?: 'unit').')',
                ]),
        ]);
    }

    public function store(Request $request): RedirectResponse
    {
        abort_unless($this->can($request->user(), 'create orders', 'manage orders'), 403);

        $data = $request->validate($this->storeRules());
        $lines = $this->resolveLineItems($data);

        $order = DB::transaction(function () use ($data, $lines) {
            $first = $lines[0];
            $sellerId = (int) ($data['seller_id'] ?? $first['seller_id']);

            $deliveryOverride = array_key_exists('delivery_fee', $data) && $data['delivery_fee'] !== '' && $data['delivery_fee'] !== null
                ? (float) $data['delivery_fee']
                : null;
            $serviceOverride = array_key_exists('service_fee', $data) && $data['service_fee'] !== '' && $data['service_fee'] !== null
                ? (float) $data['service_fee']
                : null;

            $totals = OrderFeeCalculator::calculate(
                $lines,
                $sellerId,
                $deliveryOverride,
                $serviceOverride,
                (float) ($data['discount_amount'] ?? 0),
                (float) ($data['tax_amount'] ?? 0),
            );

            $status = $data['status'] ?? Order::STATUS_PENDING;

            $order = Order::create([
                'buyer_id' => $data['buyer_id'],
                'seller_id' => $sellerId,
                // Legacy single-product columns (first line) — checkout does the same
                'product_id' => $first['product_id'],
                'order_number' => $this->generateOrderNumber(),
                'quantity' => $totals['quantity'] ?: collect($lines)->sum('quantity'),
                'unit_price' => $first['price'],
                'subtotal' => $totals['subtotal'],
                'delivery_fee' => $totals['delivery_fee'],
                'service_fee' => $totals['service_fee'],
                'discount_amount' => $totals['discount_amount'],
                'tax_amount' => $totals['tax_amount'],
                'total_amount' => $totals['total_amount'],
                'status' => $status,
                'payment_status' => $data['payment_status'] ?? Order::PAYMENT_STATUS_PENDING,
                'payment_method' => $data['payment_method'] ?? null,
                'delivery_address' => $data['delivery_address'] ?? null,
                'delivery_phone' => $data['delivery_phone'] ?? null,
                'special_instructions' => $data['special_instructions'] ?? null,
                'currency' => $data['currency'] ?? 'GHS',
                'commission_amount' => $totals['commission_amount'],
                'seller_earnings' => $totals['seller_earnings'],
                'platform_fee' => $totals['platform_fee'],
            ]);

            $this->syncOrderItems($order, $lines);

            OrderTimeline::log(
                $order,
                $status,
                'Order created by admin',
                [
                    'source' => 'admin',
                    'items_count' => count($lines),
                    'total_amount' => $order->total_amount,
                ]
            );

            return $order;
        });

        ActivityLogger::log(
            'order.created',
            "Admin created order {$order->order_number}",
            $order,
            [
                'order_id' => $order->id,
                'total' => $order->total_amount,
                'items_count' => count($lines),
            ],
            module: 'orders',
            userId: Auth::id(),
        );

        return redirect()
            ->to($this->roleAreaUrl($request, "orders/{$order->id}"))
            ->with('success', 'Order created successfully.');
    }

    public function show(Request $request, int $id): Response
    {
        $user = $request->user();
        abort_unless($this->canViewOrders($user), 403);

        $order = Order::with([
            'buyer:id,name,email,phone',
            'seller:id,name,email,phone',
            'product:id,name,price_per_unit,unit,seller_id',
            'orderItems.product:id,name,unit,price_per_unit',
            'delivery.driver:id,name,phone',
            'payment',
            'timeline' => fn ($q) => $q->latest()->limit(20),
        ])->findOrFail($id);

        abort_unless($this->canAccessOrder($user, $order), 403);

        return Inertia::render('backend/Orders/show', [
            'order' => $this->transformDetail($order),
            'statuses' => $this->statuses(),
            'payment_statuses' => $this->paymentStatuses(),
            'payment_methods' => $this->paymentMethods(),
            'area' => $this->roleAreaPrefix($request),
            'can' => [
                'update' => $this->can($user, 'edit orders', 'process orders', 'manage orders'),
                'delete' => $this->can($user, 'delete orders', 'manage orders'),
                'cancel' => $this->can($user, 'cancel orders', 'manage orders')
                    || ($user && $user->isBuyer() && (int) $order->buyer_id === (int) $user->id),
            ],
        ]);
    }

    public function edit(Request $request, int $id): Response
    {
        abort_unless(
            $this->can($request->user(), 'edit orders', 'process orders', 'manage orders'),
            403
        );

        $order = Order::with([
            'buyer:id,name,email,phone',
            'seller:id,name,email,phone',
            'product:id,name,price_per_unit,unit',
            'orderItems.product:id,name,unit,price_per_unit',
        ])->findOrFail($id);

        return Inertia::render('backend/Orders/edit', [
            'order' => $this->transformDetail($order),
            'statuses' => $this->statuses(),
            'payment_statuses' => $this->paymentStatuses(),
            'payment_methods' => $this->paymentMethods(),
            'buyers' => User::query()
                ->orderBy('name')
                ->limit(150)
                ->get(['id', 'name', 'email', 'phone'])
                ->map(fn (User $u) => [
                    'id' => $u->id,
                    'label' => trim($u->name.' · '.($u->email ?: $u->phone ?: '#'.$u->id)),
                ]),
            'sellers' => User::query()
                ->orderBy('name')
                ->limit(150)
                ->get(['id', 'name', 'email', 'phone'])
                ->map(fn (User $u) => [
                    'id' => $u->id,
                    'label' => trim($u->name.' · '.($u->email ?: $u->phone ?: '#'.$u->id)),
                ]),
            'products' => Product::query()
                ->orderBy('name')
                ->limit(200)
                ->get(['id', 'name', 'seller_id', 'price_per_unit', 'unit'])
                ->map(fn (Product $p) => [
                    'id' => $p->id,
                    'name' => $p->name,
                    'seller_id' => $p->seller_id,
                    'price_per_unit' => (float) $p->price_per_unit,
                    'unit' => $p->unit,
                    'label' => $p->name.' (GHS '.number_format((float) $p->price_per_unit, 2).')',
                ]),
        ]);
    }

    public function update(Request $request, int $id): RedirectResponse
    {
        abort_unless(
            $this->can($request->user(), 'edit orders', 'process orders', 'manage orders'),
            403
        );

        $order = Order::findOrFail($id);
        $data = $request->validate($this->updateRules());

        $oldStatus = $order->status;
        $oldPaymentStatus = $order->payment_status;

        // Quick status-only updates from show page
        if ($request->boolean('status_only')) {
            $newStatus = $data['status'] ?? $order->status;
            $newPayment = $data['payment_status'] ?? $order->payment_status;

            $order->update(array_filter([
                'status' => $data['status'] ?? null,
                'payment_status' => $data['payment_status'] ?? null,
                'cancellation_reason' => $data['cancellation_reason'] ?? null,
                'cancelled_by' => ($data['status'] ?? null) === Order::STATUS_CANCELLED
                    ? Auth::id()
                    : $order->cancelled_by,
                'processed_at' => in_array($data['status'] ?? '', [
                    Order::STATUS_PROCESSING,
                    Order::STATUS_COMPLETED,
                    Order::STATUS_DELIVERED,
                ], true) ? ($order->processed_at ?? now()) : $order->processed_at,
                'delivered_at' => in_array($data['status'] ?? '', [
                    Order::STATUS_DELIVERED,
                    Order::STATUS_COMPLETED,
                ], true) ? ($order->delivered_at ?? now()) : $order->delivered_at,
            ], static fn ($v) => $v !== null));

            $order->refresh();

            $this->logOrderTimeline(
                $order,
                $oldStatus,
                $oldPaymentStatus,
                $order->status,
                $order->payment_status,
                $data['cancellation_reason'] ?? null,
                'quick_status'
            );

            ActivityLogger::log(
                'order.updated',
                "Admin updated order {$order->order_number} status",
                $order,
                $data,
                module: 'orders',
                userId: Auth::id(),
            );

            return back()->with('success', 'Order updated.');
        }

        DB::transaction(function () use ($order, $data, $oldStatus, $oldPaymentStatus) {
            // Multi-line items when provided; otherwise keep existing lines / single product fields
            $hasItems = ! empty($data['items']) && is_array($data['items']);
            $hasSingle = ! empty($data['product_id']);

            if ($hasItems || $hasSingle) {
                $lines = $this->resolveLineItems($data, $order);
                $sellerId = (int) ($data['seller_id'] ?? $lines[0]['seller_id'] ?? $order->seller_id);

                $deliveryOverride = array_key_exists('delivery_fee', $data)
                    ? (float) $data['delivery_fee']
                    : (float) ($order->delivery_fee ?? 0);
                $serviceOverride = array_key_exists('service_fee', $data)
                    ? (float) $data['service_fee']
                    : (float) ($order->service_fee ?? 0);

                $totals = OrderFeeCalculator::calculate(
                    $lines,
                    $sellerId,
                    $deliveryOverride,
                    $serviceOverride,
                    (float) ($data['discount_amount'] ?? $order->discount_amount ?? 0),
                    (float) ($data['tax_amount'] ?? $order->tax_amount ?? 0),
                );
                $first = $lines[0];

                $payload = [
                    'buyer_id' => $data['buyer_id'] ?? $order->buyer_id,
                    'seller_id' => $sellerId,
                    'product_id' => $first['product_id'],
                    'quantity' => $totals['quantity'] ?: collect($lines)->sum('quantity'),
                    'unit_price' => $first['price'],
                    'subtotal' => $totals['subtotal'],
                    'delivery_fee' => $totals['delivery_fee'],
                    'service_fee' => $totals['service_fee'],
                    'discount_amount' => $totals['discount_amount'],
                    'tax_amount' => $totals['tax_amount'],
                    'total_amount' => $totals['total_amount'],
                    'commission_amount' => $totals['commission_amount'],
                    'seller_earnings' => $totals['seller_earnings'],
                    'platform_fee' => $totals['platform_fee'],
                ];

                $this->syncOrderItems($order, $lines);
            } else {
                $payload = [];
            }

            $payload = array_merge($payload, array_filter([
                'buyer_id' => $data['buyer_id'] ?? null,
                'seller_id' => $data['seller_id'] ?? null,
                'status' => $data['status'] ?? null,
                'payment_status' => $data['payment_status'] ?? null,
                'payment_method' => $data['payment_method'] ?? null,
                'delivery_address' => $data['delivery_address'] ?? null,
                'delivery_phone' => $data['delivery_phone'] ?? null,
                'special_instructions' => $data['special_instructions'] ?? null,
                'currency' => $data['currency'] ?? null,
                'cancellation_reason' => $data['cancellation_reason'] ?? null,
            ], static fn ($v) => $v !== null));

            if (($payload['status'] ?? null) === Order::STATUS_CANCELLED) {
                $payload['cancelled_by'] = Auth::id();
            }

            if (isset($payload['status']) && in_array($payload['status'], [
                Order::STATUS_PROCESSING,
                Order::STATUS_COMPLETED,
                Order::STATUS_DELIVERED,
            ], true)) {
                $payload['processed_at'] = $order->processed_at ?? now();
            }
            if (isset($payload['status']) && in_array($payload['status'], [
                Order::STATUS_DELIVERED,
                Order::STATUS_COMPLETED,
            ], true)) {
                $payload['delivered_at'] = $order->delivered_at ?? now();
            }

            if ($payload !== []) {
                $order->update($payload);
            }

            $order->refresh();

            $this->logOrderTimeline(
                $order,
                $oldStatus,
                $oldPaymentStatus,
                $order->status,
                $order->payment_status,
                $data['cancellation_reason'] ?? null,
                'admin_edit',
                $hasItems || $hasSingle
            );
        });

        ActivityLogger::log(
            'order.updated',
            "Admin updated order {$order->order_number}",
            $order,
            module: 'orders',
            userId: Auth::id(),
        );

        return redirect()
            ->to("/admin/orders/{$order->id}")
            ->with('success', 'Order updated successfully.');
    }

    public function destroy(Request $request, int $id): RedirectResponse
    {
        abort_unless($this->can($request->user(), 'delete orders', 'manage orders'), 403);

        $order = Order::findOrFail($id);
        $number = $order->order_number;
        $orderId = $order->id;
        $order->delete();

        ActivityLogger::log(
            'order.deleted',
            "Admin deleted order {$number}",
            null,
            ['order_id' => $orderId, 'order_number' => $number],
            level: \App\Models\ActivityLog::LEVEL_WARNING,
            module: 'orders',
            userId: Auth::id(),
        );

        return redirect()
            ->to('/admin/orders')
            ->with('success', 'Order deleted.');
    }

    public function bulkUpdate(Request $request): RedirectResponse
    {
        abort_unless(
            $this->can($request->user(), 'edit orders', 'process orders', 'bulk update orders', 'manage orders'),
            403
        );

        $data = $request->validate([
            'ids' => ['required', 'array', 'min:1'],
            'ids.*' => ['integer', 'exists:orders,id'],
            'status' => ['required', 'string', Rule::in($this->statuses())],
        ]);

        $orders = Order::whereIn('id', $data['ids'])->get();
        $count = 0;

        foreach ($orders as $order) {
            $oldStatus = $order->status;
            $newStatus = $data['status'];
            if ($oldStatus === $newStatus) {
                continue;
            }
            $order->update(['status' => $newStatus]);
            OrderTimeline::logStatusChange(
                $order,
                $oldStatus,
                $newStatus,
                'Bulk update by admin'
            );
            $count++;
        }

        return back()->with('success', "{$count} order(s) updated.");
    }

    public function bulkDelete(Request $request): RedirectResponse
    {
        abort_unless($this->can($request->user(), 'delete orders', 'manage orders'), 403);

        $data = $request->validate([
            'ids' => ['required', 'array', 'min:1'],
            'ids.*' => ['integer', 'exists:orders,id'],
        ]);

        $count = Order::whereIn('id', $data['ids'])->delete();

        ActivityLogger::log(
            'order.bulk_deleted',
            "Admin deleted {$count} order(s)",
            null,
            ['ids' => $data['ids'], 'count' => $count],
            level: \App\Models\ActivityLog::LEVEL_WARNING,
            module: 'orders',
            userId: Auth::id(),
        );

        return back()->with('success', "{$count} order(s) deleted.");
    }

    public function statistics(Request $request): Response
    {
        $user = $request->user();
        abort_unless(
            $this->can($user, 'view orders', 'view reports', 'manage orders') || $user?->isSeller(),
            403
        );

        $base = Order::query();
        $this->scopeOrdersQuery($base, $user);

        $stats = [
            'total' => (clone $base)->count(),
            'pending' => (clone $base)->where('status', Order::STATUS_PENDING)->count(),
            'processing' => (clone $base)->where('status', Order::STATUS_PROCESSING)->count(),
            'completed' => (clone $base)->where('status', Order::STATUS_COMPLETED)->count(),
            'cancelled' => (clone $base)->where('status', Order::STATUS_CANCELLED)->count(),
            'revenue' => (float) (clone $base)->where('status', Order::STATUS_COMPLETED)->sum('total_amount'),
            'today' => (clone $base)->whereDate('created_at', today())->count(),
        ];

        return Inertia::render('backend/Orders/statistics', [
            'stats' => $stats,
            'area' => $this->roleAreaPrefix($request),
        ]);
    }

    // ───────────────────────── helpers ─────────────────────────

    private function canViewOrders($user): bool
    {
        if (! $user) {
            return false;
        }

        if ($this->can($user, 'view orders', 'manage orders')) {
            return true;
        }

        return $user->isBuyer() || $user->isSeller() || $user->isDriver();
    }

    private function canAccessOrder($user, Order $order): bool
    {
        if (! $user) {
            return false;
        }

        if ($this->isAdminPanelUser($user) || $this->can($user, 'view orders', 'manage orders')) {
            return true;
        }

        if ($user->isBuyer() && (int) $order->buyer_id === (int) $user->id) {
            return true;
        }

        if ($user->isSeller() && (int) $order->seller_id === (int) $user->id) {
            return true;
        }

        if ($user->isDriver()) {
            return $order->delivery && (int) $order->delivery->driver_id === (int) $user->id;
        }

        return false;
    }

    private function can($user, string ...$permissions): bool
    {
        if (! $user) {
            return false;
        }
        if ($user->isSuperAdmin()) {
            return true;
        }
        if ($user->isAdmin() || $user->hasRole('admin') || $user->role === 'admin') {
            return true;
        }
        foreach ($permissions as $permission) {
            try {
                if ($user->hasPermissionTo($permission, 'web')
                    || $user->hasPermissionTo($permission)
                ) {
                    return true;
                }
            } catch (\Throwable) {
                // Permission may not exist in guard — continue checking others.
            }
        }

        return false;
    }

    /** @return list<string> */
    private function statuses(): array
    {
        return [
            Order::STATUS_PENDING,
            Order::STATUS_CONFIRMED,
            Order::STATUS_PROCESSING,
            Order::STATUS_READY_FOR_DELIVERY,
            Order::STATUS_DISPATCHED,
            Order::STATUS_IN_TRANSIT,
            Order::STATUS_DELIVERED,
            Order::STATUS_COMPLETED,
            Order::STATUS_CANCELLED,
            Order::STATUS_REFUNDED,
        ];
    }

    /** @return list<string> */
    private function paymentStatuses(): array
    {
        return [
            Order::PAYMENT_STATUS_PENDING,
            Order::PAYMENT_STATUS_PAID,
            Order::PAYMENT_STATUS_FAILED,
            Order::PAYMENT_STATUS_REFUNDED,
            Order::PAYMENT_STATUS_PARTIAL,
        ];
    }

    /** @return list<string> */
    private function paymentMethods(): array
    {
        return [
            Order::PAYMENT_METHOD_MOBILE_MONEY,
            Order::PAYMENT_METHOD_BANK_TRANSFER,
            Order::PAYMENT_METHOD_CARD,
            Order::PAYMENT_METHOD_WALLET,
            Order::PAYMENT_METHOD_CASH,
        ];
    }

    private function generateOrderNumber(): string
    {
        // Canonical SD-YEAR-RANDOM6ALPHANUM (see Order::generateNumber).
        return \App\Models\Order::generateNumber();
    }

    /**
     * Write order_timelines rows for admin-driven changes.
     */
    private function logOrderTimeline(
        Order $order,
        string $oldStatus,
        ?string $oldPaymentStatus,
        string $newStatus,
        ?string $newPaymentStatus,
        ?string $reason = null,
        string $source = 'admin',
        bool $itemsChanged = false,
    ): void {
        $adminName = Auth::user()?->name ?? 'Admin';

        if ($oldStatus !== $newStatus) {
            OrderTimeline::logStatusChange(
                $order,
                $oldStatus,
                $newStatus,
                $reason ?: "Updated by {$adminName}"
            );
        }

        if ($oldPaymentStatus !== null
            && $newPaymentStatus !== null
            && $oldPaymentStatus !== $newPaymentStatus
        ) {
            OrderTimeline::log(
                $order,
                $newStatus,
                "Payment status changed from {$oldPaymentStatus} to {$newPaymentStatus} by {$adminName}",
                [
                    'old_payment_status' => $oldPaymentStatus,
                    'new_payment_status' => $newPaymentStatus,
                    'source' => $source,
                ]
            );
        }

        // Full edit with no status/payment change still needs a timeline breadcrumb
        if ($oldStatus === $newStatus
            && $oldPaymentStatus === $newPaymentStatus
            && ($itemsChanged || $source === 'admin_edit')
        ) {
            OrderTimeline::log(
                $order,
                $newStatus,
                "Order details updated by {$adminName}",
                [
                    'source' => $source,
                    'items_changed' => $itemsChanged,
                ]
            );
        }
    }

    private function storeRules(): array
    {
        return [
            'buyer_id' => ['required', 'integer', 'exists:users,id'],
            'seller_id' => ['nullable', 'integer', 'exists:users,id'],
            // Multi-line (preferred)
            'items' => ['nullable', 'array', 'min:1'],
            'items.*.product_id' => ['required_with:items', 'integer', 'exists:products,id'],
            'items.*.quantity' => ['required_with:items', 'numeric', 'min:0.01'],
            'items.*.price' => ['nullable', 'numeric', 'min:0'],
            // Single-line legacy (still accepted)
            'product_id' => ['required_without:items', 'nullable', 'integer', 'exists:products,id'],
            'quantity' => ['required_without:items', 'nullable', 'numeric', 'min:0.01'],
            'unit_price' => ['nullable', 'numeric', 'min:0'],
            'delivery_fee' => ['nullable', 'numeric', 'min:0'],
            'service_fee' => ['nullable', 'numeric', 'min:0'],
            'discount_amount' => ['nullable', 'numeric', 'min:0'],
            'tax_amount' => ['nullable', 'numeric', 'min:0'],
            'status' => ['nullable', Rule::in($this->statuses())],
            'payment_status' => ['nullable', Rule::in($this->paymentStatuses())],
            'payment_method' => ['nullable', Rule::in($this->paymentMethods())],
            'delivery_address' => ['nullable', 'string', 'max:500'],
            'delivery_phone' => ['nullable', 'string', 'max:30'],
            'special_instructions' => ['nullable', 'string', 'max:1000'],
            'currency' => ['nullable', 'string', 'max:10'],
        ];
    }

    private function updateRules(): array
    {
        return [
            'buyer_id' => ['sometimes', 'integer', 'exists:users,id'],
            'seller_id' => ['sometimes', 'nullable', 'integer', 'exists:users,id'],
            'items' => ['sometimes', 'array', 'min:1'],
            'items.*.product_id' => ['required_with:items', 'integer', 'exists:products,id'],
            'items.*.quantity' => ['required_with:items', 'numeric', 'min:0.01'],
            'items.*.price' => ['nullable', 'numeric', 'min:0'],
            'product_id' => ['sometimes', 'integer', 'exists:products,id'],
            'quantity' => ['sometimes', 'numeric', 'min:0.01'],
            'unit_price' => ['sometimes', 'numeric', 'min:0'],
            'delivery_fee' => ['sometimes', 'numeric', 'min:0'],
            'service_fee' => ['sometimes', 'numeric', 'min:0'],
            'discount_amount' => ['sometimes', 'numeric', 'min:0'],
            'tax_amount' => ['sometimes', 'numeric', 'min:0'],
            'status' => ['sometimes', 'string', Rule::in($this->statuses())],
            'payment_status' => ['sometimes', 'string', Rule::in($this->paymentStatuses())],
            'payment_method' => ['sometimes', 'nullable', Rule::in($this->paymentMethods())],
            'delivery_address' => ['sometimes', 'nullable', 'string', 'max:500'],
            'delivery_phone' => ['sometimes', 'nullable', 'string', 'max:30'],
            'special_instructions' => ['sometimes', 'nullable', 'string', 'max:1000'],
            'currency' => ['sometimes', 'nullable', 'string', 'max:10'],
            'cancellation_reason' => ['sometimes', 'nullable', 'string', 'max:500'],
            'status_only' => ['sometimes', 'boolean'],
        ];
    }

    /**
     * Normalize request into line items: [{product_id, quantity, price, seller_id, unit}].
     * Accepts either items[] or single product_id/quantity/unit_price.
     *
     * @return list<array{product_id:int,quantity:float,price:float,seller_id:int,unit:?string}>
     */
    private function resolveLineItems(array $data, ?Order $existing = null): array
    {
        $raw = [];

        if (! empty($data['items']) && is_array($data['items'])) {
            $raw = $data['items'];
        } elseif (! empty($data['product_id'])) {
            $raw = [[
                'product_id' => $data['product_id'],
                'quantity' => $data['quantity'] ?? 1,
                'price' => $data['unit_price'] ?? null,
            ]];
        } elseif ($existing) {
            $existing->loadMissing('orderItems.product');
            if ($existing->orderItems->isNotEmpty()) {
                foreach ($existing->orderItems as $item) {
                    $raw[] = [
                        'product_id' => $item->product_id,
                        'quantity' => $item->quantity,
                        'price' => $item->price,
                    ];
                }
            } elseif ($existing->product_id) {
                $raw[] = [
                    'product_id' => $existing->product_id,
                    'quantity' => $existing->quantity,
                    'price' => $existing->unit_price,
                ];
            }
        }

        if ($raw === []) {
            abort(422, 'At least one order line item is required.');
        }

        $lines = [];
        foreach ($raw as $row) {
            $product = Product::findOrFail($row['product_id']);
            $qty = (float) ($row['quantity'] ?? 1);
            $price = (float) ($row['price'] ?? $row['unit_price'] ?? $product->price_per_unit);
            $lines[] = [
                'product_id' => (int) $product->id,
                'quantity' => $qty,
                'price' => $price,
                'seller_id' => (int) $product->seller_id,
                'unit' => $product->unit,
            ];
        }

        // One order = one seller (same as checkout). Enforce shared seller when multiple lines.
        $sellerIds = array_unique(array_column($lines, 'seller_id'));
        if (count($sellerIds) > 1 && empty($data['seller_id'])) {
            abort(422, 'All line items must belong to the same seller. Split into separate orders (as checkout does).');
        }

        return $lines;
    }

    /**
     * Replace order_items with the given lines (source of truth for multi-product orders).
     *
     * @param  list<array{product_id:int,quantity:float,price:float,seller_id:int,unit:?string}>  $lines
     */
    private function syncOrderItems(Order $order, array $lines): void
    {
        $order->orderItems()->delete();

        foreach ($lines as $line) {
            OrderItem::create([
                'order_id' => $order->id,
                'product_id' => $line['product_id'],
                'quantity' => $line['quantity'],
                'price' => $line['price'],
                'subtotal' => round($line['quantity'] * $line['price'], 2),
                'unit' => $line['unit'] ?? null,
            ]);
        }
    }

    /**
     * @return list<array<string, mixed>>
     */
    private function transformItems(Order $order): array
    {
        if ($order->relationLoaded('orderItems') && $order->orderItems->isNotEmpty()) {
            return $order->orderItems->map(fn (OrderItem $item) => [
                'id' => $item->id,
                'product_id' => $item->product_id,
                'product' => $item->product ? [
                    'id' => $item->product->id,
                    'name' => $item->product->name,
                    'unit' => $item->product->unit ?? $item->unit,
                ] : null,
                'quantity' => (float) $item->quantity,
                'price' => (float) $item->price,
                'subtotal' => (float) ($item->subtotal ?? ($item->quantity * $item->price)),
                'unit' => $item->unit,
                'variations' => $item->variations,
            ])->values()->all();
        }

        // Fallback: legacy single-product order with no order_items rows
        if ($order->product_id) {
            return [[
                'id' => null,
                'product_id' => $order->product_id,
                'product' => $order->product ? [
                    'id' => $order->product->id,
                    'name' => $order->product->name,
                    'unit' => $order->product->unit ?? null,
                ] : null,
                'quantity' => (float) $order->quantity,
                'price' => (float) $order->unit_price,
                'subtotal' => (float) ($order->subtotal ?? ($order->quantity * $order->unit_price)),
                'unit' => $order->product->unit ?? null,
                'variations' => null,
            ]];
        }

        return [];
    }

    private function transformList(Order $o): array
    {
        $items = $this->transformItems($o);
        $names = collect($items)
            ->map(fn ($i) => $i['product']['name'] ?? null)
            ->filter()
            ->values();

        return [
            'id' => $o->id,
            'order_number' => $o->order_number,
            'status' => $o->status,
            'payment_status' => $o->payment_status,
            'total_amount' => (float) $o->total_amount,
            'currency' => $o->currency ?? 'GHS',
            'quantity' => $o->quantity,
            'items_count' => $o->order_items_count
                ?? count($items),
            'items_summary' => $names->count() <= 1
                ? ($names->first() ?: ($o->product?->name ?? '—'))
                : $names->first().' +'.($names->count() - 1).' more',
            'buyer' => $o->buyer,
            'seller' => $o->seller,
            'product' => $o->product,
            'created_at' => optional($o->created_at)?->toDateTimeString(),
        ];
    }

    private function transformDetail(Order $order): array
    {
        $items = $this->transformItems($order);

        return [
            'id' => $order->id,
            'order_number' => $order->order_number,
            'buyer_id' => $order->buyer_id,
            'seller_id' => $order->seller_id,
            'product_id' => $order->product_id,
            'quantity' => (float) $order->quantity,
            'unit_price' => (float) $order->unit_price,
            'subtotal' => (float) $order->subtotal,
            'delivery_fee' => (float) $order->delivery_fee,
            'service_fee' => (float) $order->service_fee,
            'discount_amount' => (float) ($order->discount_amount ?? 0),
            'tax_amount' => (float) ($order->tax_amount ?? 0),
            'total_amount' => (float) $order->total_amount,
            'commission_amount' => (float) ($order->commission_amount ?? 0),
            'seller_earnings' => (float) ($order->seller_earnings ?? 0),
            'platform_fee' => (float) ($order->platform_fee ?? 0),
            'status' => $order->status,
            'payment_status' => $order->payment_status,
            'payment_method' => $order->payment_method,
            'delivery_address' => $order->delivery_address,
            'delivery_phone' => $order->delivery_phone,
            'delivery_coordinates' => $order->delivery_coordinates,
            'special_instructions' => $order->special_instructions,
            'delivery_scheduled_at' => optional($order->delivery_scheduled_at)?->toDateTimeString(),
            'delivered_at' => optional($order->delivered_at)?->toDateTimeString(),
            'processed_at' => optional($order->processed_at)?->toDateTimeString(),
            'cancellation_reason' => $order->cancellation_reason,
            'currency' => $order->currency ?? 'GHS',
            'buyer' => $order->buyer,
            'seller' => $order->seller,
            'product' => $order->product,
            // Source of truth for multi-item orders
            'items' => $items,
            'items_count' => count($items),
            'delivery' => $order->relationLoaded('delivery') ? $order->delivery : null,
            'payment' => $order->relationLoaded('payment') ? $order->payment : null,
            'timeline' => $order->relationLoaded('timeline')
                ? $order->timeline->map(fn ($t) => [
                    'id' => $t->id,
                    'status' => $t->status ?? null,
                    'description' => $t->description ?? null,
                    'note' => $t->description ?? null,
                    'metadata' => $t->metadata,
                    'created_by' => $t->created_by,
                    'created_at' => optional($t->created_at)?->toDateTimeString(),
                ])->values()->all()
                : [],
            'created_at' => optional($order->created_at)?->toDateTimeString(),
            'updated_at' => optional($order->updated_at)?->toDateTimeString(),
        ];
    }
}
