<?php
// app/Http/Controllers/Api/TripLogController.php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\TripLog;
use App\Models\TruckLog;
use Illuminate\Http\Request;
use Illuminate\Foundation\Auth\Access\AuthorizesRequests;

class TripLogController extends Controller
{
    use AuthorizesRequests;

    /**
     * Get trip logs with filters
     */
    public function index(Request $request)
    {
        $query = TripLog::with(['truck', 'driver', 'order']);

        // Filter by truck
        if ($request->has('truck_id')) {
            $query->where('truck_id', $request->truck_id);
        }

        // Filter by driver
        if ($request->has('driver_id')) {
            $query->where('driver_id', $request->driver_id);
        }

        // Filter by status
        if ($request->has('status')) {
            $query->where('status', $request->status);
        }

        // Filter by date range
        if ($request->has('from_date')) {
            $query->whereDate('started_at', '>=', $request->from_date);
        }
        if ($request->has('to_date')) {
            $query->whereDate('started_at', '<=', $request->to_date);
        }

        $trips = $query->orderBy('created_at', 'desc')
            ->paginate($request->get('per_page', 20));

        return response()->json([
            'status' => 'success',
            'data' => [
                'trips' => $trips->items(),
                'pagination' => [
                    'current_page' => $trips->currentPage(),
                    'last_page' => $trips->lastPage(),
                    'per_page' => $trips->perPage(),
                    'total' => $trips->total(),
                ],
            ],
        ]);
    }

    /**
     * Get single trip log
     */
    public function show($id)
    {
        $trip = TripLog::with(['truck', 'driver', 'order'])->findOrFail($id);

        return response()->json([
            'status' => 'success',
            'data' => $trip,
        ]);
    }

    /**
     * Create a new trip log
     */
    public function store(Request $request)
    {
        $request->validate([
            'truck_id' => 'required|exists:trucks,id',
            'driver_id' => 'required|exists:users,id',
            'order_id' => 'nullable|exists:orders,id',
            'start_location' => 'required|array',
            'start_location.lat' => 'required|numeric|between:-90,90',
            'start_location.lng' => 'required|numeric|between:-180,180',
            'end_location' => 'nullable|array',
            'end_location.lat' => 'required_with:end_location|numeric|between:-90,90',
            'end_location.lng' => 'required_with:end_location|numeric|between:-180,180',
            'distance_km' => 'nullable|numeric|min:0',
            'started_at' => 'required|date',
            'status' => 'nullable|in:scheduled,in_progress,completed,cancelled,delayed',
        ]);

        $tripData = $request->all();

        // Set default status
        if (empty($tripData['status'])) {
            $tripData['status'] = TripLog::STATUS_SCHEDULED;
        }

        // Encode location arrays
        $tripData['start_location'] = json_encode($request->start_location);
        if ($request->has('end_location')) {
            $tripData['end_location'] = json_encode($request->end_location);
        }

        $trip = TripLog::create($tripData);

        // Log trip creation in truck logs
        TruckLog::logTrip(
            $request->truck_id,
            $trip->id,
            TruckLog::ACTION_TRIP_STARTED,
            'Trip scheduled',
            ['start_location' => $request->start_location]
        );

        return response()->json([
            'status' => 'success',
            'message' => 'Trip log created successfully',
            'data' => $trip,
        ], 201);
    }

    /**
     * Update trip log
     */
    public function update(Request $request, $id)
    {
        $trip = TripLog::findOrFail($id);

        $request->validate([
            'end_location' => 'nullable|array',
            'end_location.lat' => 'required_with:end_location|numeric|between:-90,90',
            'end_location.lng' => 'required_with:end_location|numeric|between:-180,180',
            'distance_km' => 'nullable|numeric|min:0',
            'duration_minutes' => 'nullable|integer|min:0',
            'fuel_consumed_liters' => 'nullable|numeric|min:0',
            'status' => 'nullable|in:scheduled,in_progress,completed,cancelled,delayed',
            'notes' => 'nullable|string|max:500',
        ]);

        $updateData = $request->only([
            'distance_km',
            'duration_minutes',
            'fuel_consumed_liters',
            'fuel_efficiency_km_per_liter',
            'status',
            'notes',
            'average_speed',
            'max_speed',
        ]);

        if ($request->has('end_location')) {
            $updateData['end_location'] = json_encode($request->end_location);
        }

        if ($request->has('ended_at')) {
            $updateData['ended_at'] = $request->ended_at;
        }

        $trip->update($updateData);

        return response()->json([
            'status' => 'success',
            'message' => 'Trip log updated successfully',
            'data' => $trip->fresh(),
        ]);
    }

    /**
     * Start a trip
     */
    public function startTrip($id)
    {
        $trip = TripLog::findOrFail($id);

        if ($trip->status === TripLog::STATUS_IN_PROGRESS) {
            return response()->json([
                'status' => 'error',
                'message' => 'Trip is already in progress',
            ], 400);
        }

        $trip->startTrip();

        // Log trip start in truck logs
        TruckLog::logTrip(
            $trip->truck_id,
            $trip->id,
            TruckLog::ACTION_TRIP_STARTED,
            'Trip started',
            ['start_location' => $trip->start_location]
        );

        return response()->json([
            'status' => 'success',
            'message' => 'Trip started successfully',
            'data' => $trip->fresh(),
        ]);
    }

    /**
     * End a trip
     */
    public function endTrip(Request $request, $id)
    {
        $trip = TripLog::findOrFail($id);

        if ($trip->status === TripLog::STATUS_COMPLETED) {
            return response()->json([
                'status' => 'error',
                'message' => 'Trip is already completed',
            ], 400);
        }

        $request->validate([
            'end_location' => 'required|array',
            'end_location.lat' => 'required|numeric|between:-90,90',
            'end_location.lng' => 'required|numeric|between:-180,180',
            'distance_km' => 'required|numeric|min:0',
            'duration_minutes' => 'nullable|integer|min:0',
            'fuel_consumed_liters' => 'nullable|numeric|min:0',
            'fuel_efficiency_km_per_liter' => 'nullable|numeric|min:0',
        ]);

        $trip->update([
            'end_location' => json_encode($request->end_location),
            'distance_km' => $request->distance_km,
            'duration_minutes' => $request->duration_minutes ?? now()->diffInMinutes($trip->started_at),
            'fuel_consumed_liters' => $request->fuel_consumed_liters,
            'fuel_efficiency_km_per_liter' => $request->fuel_efficiency_km_per_liter,
            'ended_at' => now(),
            'completed_at' => now(),
            'status' => TripLog::STATUS_COMPLETED,
        ]);

        // Log trip end in truck logs
        TruckLog::logTrip(
            $trip->truck_id,
            $trip->id,
            TruckLog::ACTION_TRIP_ENDED,
            'Trip completed',
            [
                'distance' => $request->distance_km,
                'duration' => $request->duration_minutes,
            ]
        );

        return response()->json([
            'status' => 'success',
            'message' => 'Trip ended successfully',
            'data' => $trip->fresh(),
        ]);
    }

    /**
     * Update trip location
     */
    public function updateLocation(Request $request, $id)
    {
        $trip = TripLog::findOrFail($id);

        if ($trip->status !== TripLog::STATUS_IN_PROGRESS) {
            return response()->json([
                'status' => 'error',
                'message' => 'Trip must be in progress to update location',
            ], 400);
        }

        $request->validate([
            'lat' => 'required|numeric|between:-90,90',
            'lng' => 'required|numeric|between:-180,180',
        ]);

        $trip->updateLocation($request->lat, $request->lng);

        return response()->json([
            'status' => 'success',
            'message' => 'Location updated',
            'data' => [
                'route_path' => $trip->route_path,
            ],
        ]);
    }

    /**
     * Get trip statistics
     */
    public function statistics(Request $request)
    {
        $query = TripLog::query();

        // Filter by truck
        if ($request->has('truck_id')) {
            $query->where('truck_id', $request->truck_id);
        }

        // Filter by driver
        if ($request->has('driver_id')) {
            $query->where('driver_id', $request->driver_id);
        }

        // Date filters
        if ($request->has('from_date')) {
            $query->whereDate('started_at', '>=', $request->from_date);
        }
        if ($request->has('to_date')) {
            $query->whereDate('started_at', '<=', $request->to_date);
        }

        $stats = [
            'total_trips' => $query->count(),
            'completed_trips' => (clone $query)->where('status', TripLog::STATUS_COMPLETED)->count(),
            'in_progress_trips' => (clone $query)->where('status', TripLog::STATUS_IN_PROGRESS)->count(),
            'total_distance' => (clone $query)->sum('distance_km'),
            'total_duration' => (clone $query)->sum('duration_minutes'),
            'total_fuel_consumed' => (clone $query)->sum('fuel_consumed_liters'),
            'average_fuel_efficiency' => (clone $query)->avg('fuel_efficiency_km_per_liter'),
        ];

        return response()->json([
            'status' => 'success',
            'data' => $stats,
        ]);
    }
}
