<?php
// app/Http/Controllers/Api/DeliveryController.php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\AssignDriverRequest;
use App\Http\Requests\Api\UpdateDeliveryStatusRequest;
use App\Models\Delivery;
use App\Models\DeliveryOffer;
use App\Models\Notification;
use App\Models\Order;
use App\Models\Truck;
use App\Models\User;
use App\Services\Activity\ActivityActions;
use App\Services\Activity\ActivityLogger;
use App\Services\Delivery\DeliveryService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Foundation\Auth\Access\AuthorizesRequests;

class DeliveryController extends Controller
{
    use AuthorizesRequests;

    protected DeliveryService $deliveryService;

    public function __construct(DeliveryService $deliveryService)
    {
        $this->deliveryService = $deliveryService;
    }

    /**
     * Get deliveries
     */
    public function index(Request $request): JsonResponse
    {
        $user = $request->user();

        $query = Delivery::with(['order', 'driver', 'vehicle']);

        // Filter by user role
        if ($user->isDriver()) {
            $query->where('driver_id', $user->id);
        } elseif ($user->isSeller()) {
            $query->whereHas('order', function ($q) use ($user) {
                $q->where('seller_id', $user->id);
            });
        } elseif ($user->isBuyer()) {
            $query->whereHas('order', function ($q) use ($user) {
                $q->where('buyer_id', $user->id);
            });
        }

        // Filter by status
        if ($request->has('status')) {
            $query->where('status', $request->status);
        }

        // Filter by order (buyer tracking: GET /deliveries?order_id=4).
        // Role scoping above already restricts rows to the caller's own
        // deliveries, so this cannot leak other users' orders.
        if ($request->filled('order_id')) {
            $query->where('order_id', $request->order_id);
        }

        $deliveries = $query->orderBy('created_at', 'desc')
            ->paginate($request->get('per_page', 20));

        return response()->json([
            'status' => 'success',
            'data' => [
                'deliveries' => $deliveries->items(),
                'pagination' => [
                    'current_page' => $deliveries->currentPage(),
                    'last_page' => $deliveries->lastPage(),
                    'per_page' => $deliveries->perPage(),
                    'total' => $deliveries->total(),
                ],
            ],
        ]);
    }

    /**
     * Get single delivery
     */
    public function show($id): JsonResponse
    {
        $user = Auth::user();
        $delivery = Delivery::with(['order', 'driver', 'vehicle', 'order.buyer', 'order.seller', 'order.product.sourceSite'])
            ->findOrFail($id);

        // Check access
        if (
            $delivery->order->buyer_id !== $user->id &&
            $delivery->order->seller_id !== $user->id &&
            $delivery->driver_id !== $user->id &&
            !$user->isAdmin()
        ) {
            return response()->json([
                'status' => 'error',
                'message' => 'You do not have permission to view this delivery',
            ], 403);
        }

        return response()->json([
            'status' => 'success',
            'data' => [
                'delivery' => $delivery,
                'pickup' => $delivery->pickup_point,
                'eta' => $delivery->getDeliveryETA(),
                'is_late' => $delivery->is_late,
                'time_remaining' => $delivery->time_remaining,
            ],
        ]);
    }

    /**
     * Suggested trucks for a delivery (capacity fit + verified + insured).
     */
    public function suggestedTrucks(Request $request, $id): JsonResponse
    {
        $user = Auth::user();
        $delivery = Delivery::with(['order.orderItems.product', 'order.product'])->findOrFail($id);

        if (
            $delivery->order->buyer_id !== $user->id &&
            $delivery->order->seller_id !== $user->id &&
            $delivery->driver_id !== $user->id &&
            ! $user->isAdmin()
        ) {
            return response()->json([
                'status' => 'error',
                'message' => 'You do not have permission to view this delivery',
            ], 403);
        }

        $request->validate([
            'vehicle_type' => 'nullable|in:tipper,flatbed,tanker,dump_truck,concrete_mixer,carrier,other',
            'limit' => 'nullable|integer|min:1|max:50',
        ]);

        $matcher = app(\App\Services\Delivery\TruckMatcher::class);

        return response()->json([
            'status' => 'success',
            'data' => $matcher->suggestions(
                $delivery,
                (int) ($request->get('limit', 10)),
                $request->get('vehicle_type')
            ),
        ]);
    }

    /**
     * Assign driver to delivery
     */
    public function assignDriver(AssignDriverRequest $request): JsonResponse
    {
        $user = Auth::user();

        // Only admin or seller can assign drivers
        if (!$user->isAdmin() && !$user->isSeller()) {
            return response()->json([
                'status' => 'error',
                'message' => 'Unauthorized to assign drivers',
            ], 403);
        }

        $delivery = Delivery::findOrFail($request->delivery_id);

        // Check if seller owns the order
        if ($user->isSeller() && $delivery->order->seller_id !== $user->id) {
            return response()->json([
                'status' => 'error',
                'message' => 'You can only assign drivers to your own orders',
            ], 403);
        }

        // Check if delivery is already assigned
        if ($delivery->status !== Delivery::STATUS_PENDING) {
            return response()->json([
                'status' => 'error',
                'message' => 'This delivery is already assigned or in progress',
            ], 400);
        }

        $driver = User::findOrFail($request->driver_id);
        if (! $driver->isDriver()) {
            return response()->json([
                'status' => 'error',
                'message' => 'Selected user is not a driver',
            ], 422);
        }

        try {
            DB::beginTransaction();

            // Assign driver
            $delivery->assignDriver($request->driver_id);

            // Manual override wins over any live broadcast offers.
            $this->deliveryService->expireLiveOffers($delivery);

            // Assign + validate vehicle when provided.
            if ($request->has('vehicle_id') && $request->vehicle_id) {
                $truck = \App\Models\Truck::findOrFail($request->vehicle_id);
                $reason = app(\App\Services\Delivery\TruckMatcher::class)
                    ->rejectionReason($truck, $delivery->order);
                if ($reason) {
                    DB::rollBack();

                    return response()->json([
                        'status' => 'error',
                        'message' => "Truck not eligible: {$reason}",
                    ], 422);
                }
                $delivery->update(['vehicle_id' => $truck->id]);
            }

            DB::commit();

            ActivityLogger::log(
                ActivityActions::DELIVERY_ASSIGNED,
                "Driver #{$request->driver_id} assigned to delivery #{$delivery->id}",
                $delivery,
                [
                    'delivery_id' => $delivery->id,
                    'driver_id' => $request->driver_id,
                    'vehicle_id' => $request->vehicle_id ?? null,
                ],
                module: 'deliveries',
                userId: $user->id,
            );

            return response()->json([
                'status' => 'success',
                'message' => 'Driver assigned successfully',
                'data' => ['delivery' => $delivery->fresh()],
            ]);
        } catch (\Exception $e) {
            DB::rollBack();
            Log::error('Driver assignment failed', [
                'delivery_id' => $request->delivery_id ?? null,
                'driver_id' => $request->driver_id ?? null,
                'error' => $e->getMessage(),
            ]);
            return response()->json([
                'status' => 'error',
                'message' => 'Failed to assign driver. Please try again.',
            ], 500);
        }
    }

    /**
     * Accept delivery (by driver)
     */
    public function accept($id): JsonResponse
    {
        $user = Auth::user();
        $delivery = Delivery::findOrFail($id);

        // Check if user is the assigned driver
        if ($delivery->driver_id !== $user->id) {
            return response()->json([
                'status' => 'error',
                'message' => 'You are not assigned to this delivery',
            ], 403);
        }

        if ($delivery->status !== Delivery::STATUS_ASSIGNED) {
            return response()->json([
                'status' => 'error',
                'message' => 'This delivery cannot be accepted',
            ], 400);
        }

        $delivery->acceptByDriver();

        ActivityLogger::log(
            ActivityActions::DELIVERY_ACCEPTED,
            "Driver accepted delivery #{$delivery->id}",
            $delivery,
            ['delivery_id' => $delivery->id],
            module: 'deliveries',
            userId: $user->id,
        );

        return response()->json([
            'status' => 'success',
            'message' => 'Delivery accepted successfully',
            'data' => ['delivery' => $delivery->fresh()],
        ]);
    }

    /**
     * Decline a directly-assigned delivery (by driver).
     * Unassigns the driver and re-broadcasts the trip to the next
     * online drivers so the order is not stuck.
     */
    public function decline($id): JsonResponse
    {
        $user = Auth::user();
        $delivery = Delivery::findOrFail($id);

        if ((int) $delivery->driver_id !== (int) $user->id) {
            return response()->json([
                'status' => 'error',
                'message' => 'You are not assigned to this delivery',
            ], 403);
        }

        if ($delivery->status !== Delivery::STATUS_ASSIGNED) {
            return response()->json([
                'status' => 'error',
                'message' => 'This delivery can no longer be declined',
            ], 400);
        }

        try {
            DB::beginTransaction();

            $delivery->update([
                'driver_id' => null,
                'status' => Delivery::STATUS_PENDING,
                'assigned_at' => null,
            ]);

            \App\Models\OrderTimeline::log(
                $delivery->order,
                $delivery->status,
                "Driver {$user->name} declined the assignment — re-dispatching",
                ['delivery_id' => $delivery->id, 'driver_id' => $user->id]
            );

            DB::commit();
        } catch (\Exception $e) {
            DB::rollBack();

            Log::error('Delivery decline failed', [
                'delivery_id' => $delivery->id ?? null,
                'driver_id' => $user->id,
                'error' => $e->getMessage(),
            ]);
            return response()->json([
                'status' => 'error',
                'message' => 'Failed to decline delivery. Please try again.',
            ], 500);
        }

        // Re-broadcast to online drivers (best-effort).
        $dispatchResult = null;
        try {
            $dispatchResult = $this->deliveryService->dispatch($delivery->fresh(), 5, true);
        } catch (\Throwable) {
        }

        ActivityLogger::log(
            ActivityActions::DELIVERY_STATUS,
            "Driver declined delivery #{$delivery->id}",
            $delivery,
            ['delivery_id' => $delivery->id, 'dispatch' => $dispatchResult],
            module: 'deliveries',
            userId: $user->id,
        );

        return response()->json([
            'status' => 'success',
            'message' => 'Assignment declined — trip re-offered to other drivers',
            'data' => ['delivery' => $delivery->fresh(), 'dispatch' => $dispatchResult],
        ]);
    }

    /**
     * Update delivery status (by driver)
     */
    public function updateStatus(UpdateDeliveryStatusRequest $request, $id): JsonResponse
    {
        $user = Auth::user();
        $delivery = Delivery::findOrFail($id);

        // Check if user is the assigned driver
        if ($delivery->driver_id !== $user->id && !$user->isAdmin()) {
            return response()->json([
                'status' => 'error',
                'message' => 'You are not authorized to update this delivery',
            ], 403);
        }

        try {
            $status = $request->status;
            $notes = $request->notes;

            switch ($status) {
                case 'picked_up':
                    $delivery->markAsPickedUp();
                    break;

                case 'in_transit':
                    $delivery->markAsInTransit();
                    break;

                case 'arrived':
                    $delivery->markAsArrived();
                    break;

                case 'completed':
                    $delivery->markAsCompleted(
                        $request->signature,
                        $request->rating,
                        $request->comment
                    );
                    break;

                case 'failed':
                    $delivery->markAsFailed($notes);
                    break;

                default:
                    return response()->json([
                        'status' => 'error',
                        'message' => 'Invalid status update',
                    ], 400);
            }

            ActivityLogger::log(
                ActivityActions::DELIVERY_STATUS,
                "Delivery #{$delivery->id} marked as {$status}",
                $delivery,
                [
                    'delivery_id' => $delivery->id,
                    'status' => $status,
                    'notes' => $notes,
                ],
                module: 'deliveries',
                userId: $user->id,
            );

            return response()->json([
                'status' => 'success',
                'message' => "Delivery marked as {$status}",
                'data' => ['delivery' => $delivery->fresh()],
            ]);
        } catch (\Exception $e) {
            Log::error('Delivery status update failed', [
                'delivery_id' => $delivery->id ?? null,
                'user_id' => $user->id,
                'error' => $e->getMessage(),
            ]);
            return response()->json([
                'status' => 'error',
                'message' => 'Failed to update delivery. Please try again.',
            ], 500);
        }
    }

    /**
     * Update delivery location (by driver)
     */
    public function updateLocation(Request $request, $id): JsonResponse
    {
        $request->validate([
            'lat' => 'required|numeric|between:-90,90',
            'lng' => 'required|numeric|between:-180,180',
        ]);

        $user = Auth::user();
        $delivery = Delivery::findOrFail($id);

        // Check if user is the assigned driver
        if ($delivery->driver_id !== $user->id) {
            return response()->json([
                'status' => 'error',
                'message' => 'You are not authorized to update this delivery location',
            ], 403);
        }

        $delivery->updateLocation($request->lat, $request->lng);

        return response()->json([
            'status' => 'success',
            'message' => 'Location updated successfully',
            'data' => [
                'location' => $delivery->location,
                'eta' => $delivery->getDeliveryETA(),
            ],
        ]);
    }

    /**
     * Get available drivers (online first; optional online_only filter
     * used by admin assign UI so confirmed orders push to online drivers).
     */
    public function availableDrivers(Request $request): JsonResponse
    {
        $user = $request->user();

        // Driver contact details are operational data: only admins (dispatch)
        // and sellers (own deliveries) may list drivers.
        if (! $user->isAdmin() && ! $user->isSeller()) {
            return response()->json([
                'status' => 'error',
                'message' => 'Only sellers and admins can view available drivers',
            ], 403);
        }

        $request->validate([
            'lat' => 'nullable|numeric|between:-90,90',
            'lng' => 'nullable|numeric|between:-180,180',
            'radius' => 'nullable|numeric|min:1|max:100',
            'online_only' => 'nullable|boolean',
        ]);

        $query = User::where(function ($q) {
            $q->where('role', 'driver')
                ->orWhereHas('roles', function ($r) {
                    $r->where('name', 'driver');
                });
        })->whereDoesntHave('deliveries', function ($q) {
            $q->whereIn('status', [
                Delivery::STATUS_ASSIGNED,
                Delivery::STATUS_ACCEPTED,
                Delivery::STATUS_PICKED_UP,
                Delivery::STATUS_IN_TRANSIT,
            ]);
        })->whereHas('trucks', function ($q) {
            $q->where('is_verified', true)
                ->where('status', \App\Models\Truck::STATUS_AVAILABLE)
                ->where(function ($insurance) {
                    $insurance->whereNull('insurance_expiry')
                        ->orWhere('insurance_expiry', '>', now());
                });
        });

        if ($request->boolean('online_only', false)) {
            $query->where('is_online', true);
        }

        // Filter by location if provided
        if ($request->has('lat') && $request->has('lng')) {
            $radius = $request->get('radius', 20);
            // This would use geospatial queries
            // For now, return all available drivers
        }

        $drivers = $query->orderByDesc('is_online')
            ->orderByDesc('last_active_at')
            ->get(['id', 'name', 'phone', 'is_online', 'last_active_at'])
            ->map(fn (User $driver) => [
                'id' => $driver->id,
                'name' => $driver->name,
                'phone' => $this->maskPhone($driver->phone),
                'is_online' => (bool) $driver->is_online,
                'last_active_at' => $driver->last_active_at?->toIso8601String(),
            ])
            ->values();

        return response()->json([
            'status' => 'success',
            'data' => $drivers,
        ]);
    }

    /**
     * Mask a phone number for list responses (keep prefix + last 3 digits).
     */
    protected function maskPhone(?string $phone): ?string
    {
        if (! $phone) {
            return null;
        }

        $digits = preg_replace('/\D/', '', $phone);
        if (strlen($digits) < 7) {
            return '****' . substr($digits, -2);
        }

        return substr($digits, 0, 3) . '****' . substr($digits, -3);
    }

    /**
     * Get delivery statistics
     */
    public function statistics(Request $request): JsonResponse
    {
        $user = Auth::user();

        $query = Delivery::query();

        if ($user->isDriver()) {
            $query->where('driver_id', $user->id);
        } elseif ($user->isSeller()) {
            $query->whereHas('order', function ($q) use ($user) {
                $q->where('seller_id', $user->id);
            });
        }

        $stats = [
            'total' => $query->count(),
            'pending' => (clone $query)->where('status', Delivery::STATUS_PENDING)->count(),
            'assigned' => (clone $query)->where('status', Delivery::STATUS_ASSIGNED)->count(),
            'in_transit' => (clone $query)->where('status', Delivery::STATUS_IN_TRANSIT)->count(),
            'completed' => (clone $query)->where('status', Delivery::STATUS_COMPLETED)->count(),
            'failed' => (clone $query)->where('status', Delivery::STATUS_FAILED)->count(),
            'overdue' => (clone $query)->overdue()->count(),
        ];

        // Calculate earnings for driver (70% share, floored on the
        // standard base fee so free-delivery promos still pay out).
        // Computed in PHP so the query stays portable (no GREATEST()).
        if ($user->isDriver()) {
            $stats['earnings'] = (float) (clone $query)
                ->where('status', Delivery::STATUS_COMPLETED)
                ->get(['delivery_fee'])
                ->sum(fn (Delivery $delivery) => max((float) ($delivery->delivery_fee ?? 0), 20.0) * 0.70);
            $stats['formatted_earnings'] = 'GHS ' . number_format($stats['earnings'], 2);
        }

        return response()->json([
            'status' => 'success',
            'data' => $stats,
        ]);
    }

    // ============================================================
    // DISPATCH (broadcast offers, first-accept wins)
    // ============================================================

    /**
     * My live trip requests (driver inbox). Lazy-expires stale offers.
     * GET /deliveries/offers
     */
    public function offers(Request $request): JsonResponse
    {
        $user = Auth::user();
        if (!$user->isDriver() && !$user->isAdmin()) {
            return response()->json([
                'status' => 'error',
                'message' => 'Only drivers can view trip requests',
            ], 403);
        }

        $offers = $this->deliveryService->driverOffers($user);

        $payload = $offers->map(function (DeliveryOffer $offer) {
            $delivery = $offer->delivery;
            $order = $delivery->order ?? null;
            return [
                'id' => $offer->id,
                'status' => $offer->status,
                'expires_at' => $offer->expires_at?->toIso8601String(),
                'seconds_left' => max(0, $offer->expires_at->timestamp - now()->timestamp),
                'delivery' => [
                    'id' => $delivery->id,
                    'tracking_number' => $delivery->tracking_number,
                    'status' => $delivery->status,
                    'delivery_fee' => (float) $delivery->delivery_fee,
                    'driver_payout' => (float) $delivery->driver_payout,
                    'distance_km' => $delivery->distance_km,
                    'estimated_arrival' => $delivery->estimated_arrival?->toIso8601String(),
                ],
                'order' => $order ? [
                    'id' => $order->id,
                    'order_number' => $order->order_number,
                    'delivery_address' => $order->delivery_address,
                    'delivery_coordinates' => $order->delivery_coordinates,
                    'total_amount' => (float) $order->total_amount,
                    'item_count' => $order->orderItems()->count(),
                ] : null,
            ];
        })->values();

        return response()->json([
            'status' => 'success',
            'data' => ['offers' => $payload],
        ]);
    }

    /**
     * Accept a trip request — first-accept-wins (atomic).
     * POST /deliveries/offers/{offer}/accept
     */
    public function acceptOffer($offerId): JsonResponse
    {
        $user = Auth::user();
        if (!$user->isDriver()) {
            return response()->json([
                'status' => 'error',
                'message' => 'Only drivers can accept trip requests',
            ], 403);
        }

        $offer = DeliveryOffer::findOrFail($offerId);
        $result = $this->deliveryService->acceptOffer($offer, $user);

        if (!($result['accepted'] ?? false)) {
            return response()->json([
                'status' => 'error',
                'message' => $result['message'] ?? 'Could not accept',
            ], 409);
        }

        // Buyer gets a live-tracker event via timeline + in-app notification.
        $delivery = $result['delivery'];
        Notification::createNotification(
            $delivery->order->buyer_id,
            'Driver is on the way',
            "{$user->name} accepted your order #{$delivery->order->order_number}",
            'delivery',
            [
                'delivery_id' => $delivery->id,
                'driver_name' => $user->name,
                'tracking_number' => $delivery->tracking_number,
            ],
            'in_app',
            'high'
        );

        return response()->json([
            'status' => 'success',
            'message' => 'Trip accepted — head to pickup',
            'data' => ['delivery' => $delivery],
        ]);
    }

    /**
     * Decline a trip request → instantly re-offered to the next driver.
     * POST /deliveries/offers/{offer}/decline
     */
    public function declineOffer($offerId): JsonResponse
    {
        $user = Auth::user();
        if (!$user->isDriver()) {
            return response()->json([
                'status' => 'error',
                'message' => 'Only drivers can decline trip requests',
            ], 403);
        }

        $offer = DeliveryOffer::findOrFail($offerId);
        $result = $this->deliveryService->declineOffer($offer, $user);

        return response()->json([
            'status' => ($result['declined'] ?? false) ? 'success' : 'error',
            'message' => $result['message'] ?? 'Offer declined',
            'data' => $result,
        ]);
    }

    /**
     * (Re-)dispatch a delivery to available drivers (admin/seller retry).
     * POST /deliveries/{id}/dispatch
     */
    public function dispatch($id): JsonResponse
    {
        $user = Auth::user();
        if (!$user->isAdmin() && !$user->isSeller()) {
            return response()->json([
                'status' => 'error',
                'message' => 'Unauthorized to dispatch deliveries',
            ], 403);
        }

        $delivery = Delivery::findOrFail($id);
        if ($user->isSeller() && $delivery->order->seller_id !== $user->id) {
            return response()->json([
                'status' => 'error',
                'message' => 'You can only dispatch your own orders',
            ], 403);
        }

        $result = $this->deliveryService->dispatch($delivery);

        return response()->json([
            'status' => $result['dispatched'] ? 'success' : 'error',
            'message' => $result['dispatched']
                ? "Broadcast to {$result['offers']} driver(s)"
                : 'No drivers available (' . ($result['reason'] ?? 'unknown') . ')',
            'data' => $result,
        ], $result['dispatched'] ? 200 : 409);
    }

    /**
     * Driver presence: online toggle + GPS ping for offer targeting.
     * POST /deliveries/presence
     */
    public function presence(Request $request): JsonResponse
    {
        $request->validate([
            'is_online' => 'required|boolean',
            'lat' => 'nullable|numeric|between:-90,90',
            'lng' => 'nullable|numeric|between:-180,180',
        ]);

        $user = Auth::user();
        if (!$user->isDriver()) {
            return response()->json([
                'status' => 'error',
                'message' => 'Only drivers can update presence',
            ], 403);
        }

        $user->update([
            'is_online' => (bool) $request->is_online,
            'last_location' => $request->lat !== null && $request->lng !== null
                ? ['lat' => (float) $request->lat, 'lng' => (float) $request->lng, 'timestamp' => now()->toIso8601String()]
                : $user->last_location,
            'last_active_at' => now(),
        ]);

        return response()->json([
            'status' => 'success',
            'message' => $request->is_online ? 'You are online' : 'You are offline',
            'data' => ['is_online' => (bool) $user->is_online],
        ]);
    }
}
