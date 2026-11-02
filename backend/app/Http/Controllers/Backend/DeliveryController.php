<?php

namespace App\Http\Controllers\Backend;

use App\Http\Controllers\Concerns\ScopesByRoleArea;
use App\Http\Controllers\Controller;
use App\Models\Delivery;
use App\Models\DeliveryOffer;
use App\Models\OrderTimeline;
use App\Services\Activity\ActivityLogger;
use App\Services\Delivery\DeliveryService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Inertia\Inertia;
use Inertia\Response;

class DeliveryController extends Controller
{
    use ScopesByRoleArea;

    public function index(Request $request): Response
    {
        $user = $request->user();
        $query = Delivery::query()
            ->with([
                'order:id,order_number,status,total_amount,buyer_id,seller_id',
                'driver:id,name,phone',
            ])
            ->latest();

        $this->scopeDeliveriesQuery($query, $user);

        if ($search = $request->input('search')) {
            $query->where(function ($q) use ($search) {
                $q->where('tracking_number', 'like', "%{$search}%")
                    ->orWhereHas('driver', fn ($d) => $d->where('name', 'like', "%{$search}%"))
                    ->orWhereHas('order', fn ($o) => $o->where('order_number', 'like', "%{$search}%"));
            });
        }

        if ($status = $request->input('status')) {
            $query->where('status', $status);
        }

        $deliveries = $query->paginate((int) $request->input('per_page', 15))
            ->withQueryString()
            ->through(fn (Delivery $d) => [
                'id' => $d->id,
                'tracking_number' => $d->tracking_number,
                'status' => $d->status,
                'delivery_fee' => (float) ($d->delivery_fee ?? 0),
                'distance_km' => $d->distance_km,
                'driver' => $d->driver,
                'order' => $d->order,
                'assigned_at' => optional($d->assigned_at)?->toDateTimeString(),
                'completed_at' => optional($d->completed_at)?->toDateTimeString(),
                'created_at' => optional($d->created_at)?->toDateTimeString(),
            ]);

        return Inertia::render('backend/Deliveries/index', [
            'deliveries' => $deliveries,
            'filters' => $request->only(['search', 'status']),
            'area' => $this->roleAreaPrefix($request),
            'statuses' => [
                Delivery::STATUS_PENDING ?? 'pending',
                Delivery::STATUS_ASSIGNED ?? 'assigned',
                Delivery::STATUS_IN_TRANSIT ?? 'in_transit',
                Delivery::STATUS_COMPLETED ?? 'completed',
                Delivery::STATUS_FAILED ?? 'failed',
            ],
        ]);
    }

    public function show(Request $request, int $id): Response
    {
        $user = $request->user();
        $delivery = Delivery::with([
            'order.buyer:id,name,phone',
            'order.seller:id,name,phone',
            'driver:id,name,email,phone,is_online',
            'offers.driver:id,name,phone,is_online',
        ])->findOrFail($id);

        if ($user && ! $this->isAdminPanelUser($user)) {
            $allowed = false;
            if ($user->isDriver() && (int) $delivery->driver_id === (int) $user->id) {
                $allowed = true;
            }
            if ($user->isBuyer() && $delivery->order && (int) $delivery->order->buyer_id === (int) $user->id) {
                $allowed = true;
            }
            if ($user->isSeller() && $delivery->order && (int) $delivery->order->seller_id === (int) $user->id) {
                $allowed = true;
            }
            abort_unless($allowed, 403);
        }

        $isAdmin = $this->isAdminPanelUser($user);

        return Inertia::render('backend/Deliveries/show', [
            'delivery' => $delivery,
            'area' => $this->roleAreaPrefix($request),
            'canAssign' => $isAdmin,
            'offers' => $isAdmin ? $delivery->offers->map(fn (DeliveryOffer $o) => [
                'id' => $o->id,
                'driver_id' => $o->driver_id,
                'driver_name' => $o->driver?->name,
                'is_online' => (bool) $o->driver?->is_online,
                'status' => $o->status,
                'expires_at' => optional($o->expires_at)?->toDateTimeString(),
                'responded_at' => optional($o->responded_at)?->toDateTimeString(),
            ])->values()->all() : [],
            'availableDrivers' => $isAdmin
                ? app(DeliveryService::class)->availableDrivers(20)->map(fn ($d) => [
                    'id' => $d->id,
                    'name' => $d->name,
                    'phone' => $d->phone,
                    'is_online' => (bool) $d->is_online,
                    'last_active_at' => optional($d->last_active_at)?->toDateTimeString(),
                ])->values()->all()
                : [],
        ]);
    }

    /**
     * Admin: manually assign a driver (override). Expires any live
     * broadcast offers so the manual assignment wins.
     */
    public function assign(Request $request, int $id): RedirectResponse
    {
        abort_unless($this->isAdminPanelUser($request->user()), 403);

        $data = $request->validate([
            'driver_id' => ['required', 'integer', 'exists:users,id'],
            'vehicle_id' => ['nullable', 'integer', 'exists:trucks,id'],
            'notes' => ['nullable', 'string', 'max:500'],
        ]);

        $delivery = Delivery::findOrFail($id);

        if (in_array($delivery->status, [
            Delivery::STATUS_ACCEPTED,
            Delivery::STATUS_PICKED_UP,
            Delivery::STATUS_IN_TRANSIT,
            Delivery::STATUS_ARRIVED,
            Delivery::STATUS_COMPLETED,
        ], true) || $delivery->driver_id) {
            return back()->withErrors(['driver_id' => 'Delivery already has a driver or is in progress.']);
        }

        $driver = \App\Models\User::findOrFail($data['driver_id']);
        if (! $driver->isDriver()) {
            return back()->withErrors(['driver_id' => 'Selected user is not a driver.']);
        }

        DB::transaction(function () use ($delivery, $data) {
            $delivery->assignDriver((int) $data['driver_id']);

            if (! empty($data['vehicle_id'])) {
                $delivery->update(['vehicle_id' => $data['vehicle_id']]);
            }
            if (! empty($data['notes'])) {
                $delivery->update(['dispatch_notes' => $data['notes']]);
            }

            // Manual override wins over any live broadcast offers.
            app(DeliveryService::class)->expireLiveOffers($delivery);

            OrderTimeline::log(
                $delivery->order,
                $delivery->status,
                "Admin assigned driver {$delivery->driver_id} manually",
                ['delivery_id' => $delivery->id, 'driver_id' => $delivery->driver_id]
            );
        });

        ActivityLogger::log(
            'delivery.assigned',
            "Admin assigned driver #{$data['driver_id']} to delivery #{$delivery->id}",
            $delivery,
            ['delivery_id' => $delivery->id, 'driver_id' => $data['driver_id']],
            module: 'deliveries',
            userId: $request->user()?->id,
        );

        return back()->with('success', 'Driver assigned successfully.');
    }

    /**
     * Admin: (re-)broadcast the trip request to online drivers.
     */
    public function dispatch(Request $request, int $id): RedirectResponse
    {
        abort_unless($this->isAdminPanelUser($request->user()), 403);

        $delivery = Delivery::findOrFail($id);
        $onlineOnly = $request->boolean('online_only', true);
        $max = max(1, min(20, (int) $request->input('max_drivers', 5)));

        $result = app(DeliveryService::class)->dispatch($delivery, $max, $onlineOnly);

        if (! ($result['dispatched'] ?? false)) {
            return back()->withErrors([
                'dispatch' => 'No drivers available ('.($result['reason'] ?? 'unknown').').',
            ]);
        }

        return back()->with('success', "Trip request sent to {$result['offers']} driver(s).");
    }
}
