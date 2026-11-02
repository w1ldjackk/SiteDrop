<?php
// app/Http/Controllers/Api/TruckController.php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Truck;
use App\Models\TruckDocument;
use App\Models\TruckInsurance;
use App\Models\TruckMaintenance;
use App\Models\TruckLog;
use App\Models\User;
use App\Support\PublicAssetUploader;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Foundation\Auth\Access\AuthorizesRequests;

class TruckController extends Controller
{
    use AuthorizesRequests;

    /**
     * Get all trucks with filters
     */
    public function index(Request $request)
    {
        $query = Truck::with(['user', 'driver']);

        // Filter by status
        if ($request->has('status')) {
            $query->where('status', $request->status);
        }

        // Filter by vehicle type
        if ($request->has('vehicle_type')) {
            $query->where('vehicle_type', $request->vehicle_type);
        }

        // Filter by verified
        if ($request->has('verified')) {
            $query->where('is_verified', $request->boolean('verified'));
        }

        // Filter by owner
        if ($request->has('user_id')) {
            $query->where('user_id', $request->user_id);
        }

        // Search
        if ($request->has('search')) {
            $search = $request->search;
            $query->where(function ($q) use ($search) {
                $q->where('registration_number', 'like', "%{$search}%")
                    ->orWhere('make', 'like', "%{$search}%")
                    ->orWhere('model', 'like', "%{$search}%");
            });
        }

        $trucks = $query->orderBy('created_at', 'desc')
            ->paginate($request->get('per_page', 20));

        return response()->json([
            'status' => 'success',
            'data' => [
                'trucks' => $trucks->items(),
                'pagination' => [
                    'current_page' => $trucks->currentPage(),
                    'last_page' => $trucks->lastPage(),
                    'per_page' => $trucks->perPage(),
                    'total' => $trucks->total(),
                ],
            ],
        ]);
    }

    /**
     * Get available trucks
     */
    public function available(Request $request)
    {
        $query = Truck::with(['user', 'driver'])
            ->where('status', Truck::STATUS_AVAILABLE)
            ->where('is_verified', true);

        // Filter by capacity
        if ($request->has('capacity_tons')) {
            $query->where('capacity_tons', '>=', $request->capacity_tons);
        }

        // Filter by vehicle type
        if ($request->has('vehicle_type')) {
            $query->where('vehicle_type', $request->vehicle_type);
        }

        $trucks = $query->get();

        return response()->json([
            'status' => 'success',
            'data' => $trucks,
        ]);
    }

    /**
     * Get nearby trucks
     */
    public function nearby(Request $request)
    {
        $request->validate([
            'lat' => 'required|numeric|between:-90,90',
            'lng' => 'required|numeric|between:-180,180',
            'radius' => 'nullable|numeric|min:1|max:100',
        ]);

        $radius = $request->get('radius', 20);
        $lat = $request->lat;
        $lng = $request->lng;

        $trucks = Truck::nearby($lat, $lng, $radius)
            ->with(['user', 'driver'])
            ->where('status', Truck::STATUS_AVAILABLE)
            ->where('is_verified', true)
            ->get();

        return response()->json([
            'status' => 'success',
            'data' => $trucks,
        ]);
    }

    /**
     * Get single truck details
     */
    public function show($id)
    {
        $truck = Truck::with([
            'user',
            'driver',
            'deliveries',
            'tripLogs',
            'maintenanceRecords',
            'documents',
            'insurance'
        ])->findOrFail($id);

        // Get statistics
        $stats = [
            'total_deliveries' => $truck->deliveries->count(),
            'total_trips' => $truck->tripLogs->count(),
            'total_distance' => $truck->total_distance,
            'average_efficiency' => $truck->average_fuel_efficiency,
            'maintenance_count' => $truck->maintenanceRecords->count(),
            'is_due_for_maintenance' => $truck->is_due_for_maintenance,
            'insurance_status' => $truck->insurance_status,
        ];

        return response()->json([
            'status' => 'success',
            'data' => [
                'truck' => $truck,
                'statistics' => $stats,
            ],
        ]);
    }

    /**
     * Create a new truck
     */
    public function store(Request $request)
    {
        $request->validate([
            'registration_number' => 'required|string|unique:trucks',
            'make' => 'required|string|max:100',
            'model' => 'required|string|max:100',
            'year' => 'required|integer|min:1990|max:' . date('Y'),
            'color' => 'nullable|string|max:50',
            'capacity_tons' => 'required|numeric|min:0',
            'capacity_cubic_meters' => 'nullable|numeric|min:0',
            'vehicle_type' => 'required|in:tipper,flatbed,tanker,dump_truck,concrete_mixer,carrier,other',
            'fuel_type' => 'nullable|in:diesel,petrol,electric,hybrid',
            'owner_type' => 'nullable|in:personal,company',
            'company_name' => 'required_if:owner_type,company|nullable|string|max:255',
            'status' => 'nullable|in:available,in_transit,maintenance,inactive,out_of_service',
            // Matcher-critical compliance fields (driver onboarding).
            'insurance_expiry' => 'nullable|date|after:today',
            'registration_expiry' => 'nullable|date',
            'current_mileage' => 'nullable|numeric|min:0',
            'driver_id' => 'nullable|exists:users,id',
        ]);

        $truckData = $request->all();
        $truckData['user_id'] = Auth::id();

        // Driver onboarding: a driver registering their own truck becomes
        // both owner and assigned driver unless specified otherwise.
        if (empty($truckData['driver_id']) && Auth::user()->isDriver()) {
            $truckData['driver_id'] = Auth::id();
            $truckData['driver_assigned_at'] = now();
        }

        // Set default status
        if (empty($truckData['status'])) {
            $truckData['status'] = Truck::STATUS_AVAILABLE;
        }

        $truck = Truck::create($truckData);

        // Log creation
        TruckLog::log(
            $truck->id,
            TruckLog::ACTION_CREATED,
            'Truck added to fleet',
            ['registration_number' => $truck->registration_number]
        );

        return response()->json([
            'status' => 'success',
            'message' => 'Truck created successfully',
            'data' => $truck,
        ], 201);
    }

    /**
     * Update a truck
     */
    public function update(Request $request, $id)
    {
        $truck = Truck::findOrFail($id);

        if ($truck->user_id !== Auth::id() && !Auth::user()->isAdmin()) {
            return response()->json([
                'status' => 'error',
                'message' => 'You do not have permission to update this truck',
            ], 403);
        }

        $request->validate([
            'registration_number' => 'sometimes|string|unique:trucks,registration_number,' . $truck->id,
            'make' => 'sometimes|string|max:100',
            'model' => 'sometimes|string|max:100',
            'year' => 'sometimes|integer|min:1990|max:' . date('Y'),
            'color' => 'nullable|string|max:50',
            'capacity_tons' => 'sometimes|numeric|min:0',
            'capacity_cubic_meters' => 'nullable|numeric|min:0',
            'vehicle_type' => 'sometimes|in:tipper,flatbed,tanker,dump_truck,concrete_mixer,carrier,other',
            'fuel_type' => 'nullable|in:diesel,petrol,electric,hybrid',
            'owner_type' => 'nullable|in:personal,company',
            'company_name' => 'required_if:owner_type,company|nullable|string|max:255',
            'status' => 'nullable|in:available,in_transit,maintenance,inactive,out_of_service',
            'is_verified' => 'sometimes|boolean',
            'insurance_expiry' => 'nullable|date',
            'registration_expiry' => 'nullable|date',
            'current_mileage' => 'nullable|numeric|min:0',
        ]);

        $oldStatus = $truck->status;
        $truck->update($request->all());

        // Log status change if status was updated
        if ($request->has('status') && $oldStatus !== $request->status) {
            TruckLog::logStatusChange(
                $truck->id,
                $oldStatus,
                $request->status,
                'Status updated via API'
            );
        }

        return response()->json([
            'status' => 'success',
            'message' => 'Truck updated successfully',
            'data' => $truck->fresh(),
        ]);
    }

    /**
     * Delete a truck
     */
    public function destroy($id)
    {
        $truck = Truck::findOrFail($id);

        if ($truck->user_id !== Auth::id() && !Auth::user()->isAdmin()) {
            return response()->json([
                'status' => 'error',
                'message' => 'You do not have permission to delete this truck',
            ], 403);
        }

        $truck->delete();

        return response()->json([
            'status' => 'success',
            'message' => 'Truck deleted successfully',
        ]);
    }

    /**
     * Update truck status
     */
    public function updateStatus(Request $request, $id)
    {
        $truck = Truck::findOrFail($id);

        if ($truck->user_id !== Auth::id() && !Auth::user()->isAdmin()) {
            return response()->json([
                'status' => 'error',
                'message' => 'You do not have permission to update this truck',
            ], 403);
        }

        $request->validate([
            'status' => 'required|in:available,in_transit,maintenance,inactive,out_of_service',
            'reason' => 'nullable|string|max:500',
        ]);

        $oldStatus = $truck->status;
        $truck->update(['status' => $request->status]);

        // Log status change
        TruckLog::logStatusChange(
            $truck->id,
            $oldStatus,
            $request->status,
            $request->reason
        );

        return response()->json([
            'status' => 'success',
            'message' => 'Truck status updated successfully',
            'data' => [
                'truck' => $truck->fresh(),
                'old_status' => $oldStatus,
                'new_status' => $truck->status,
            ],
        ]);
    }

    /**
     * Update truck location
     */
    public function updateLocation(Request $request, $id)
    {
        $truck = Truck::findOrFail($id);

        if ($truck->driver_id !== Auth::id() && !Auth::user()->isAdmin()) {
            return response()->json([
                'status' => 'error',
                'message' => 'You do not have permission to update location for this truck',
            ], 403);
        }

        $request->validate([
            'lat' => 'required|numeric|between:-90,90',
            'lng' => 'required|numeric|between:-180,180',
        ]);

        $truck->updateLocation($request->lat, $request->lng);

        // Log location update
        TruckLog::log(
            $truck->id,
            TruckLog::ACTION_LOCATION_UPDATED,
            'Location updated',
            ['lat' => $request->lat, 'lng' => $request->lng]
        );

        return response()->json([
            'status' => 'success',
            'message' => 'Location updated successfully',
            'data' => [
                'location' => $truck->location,
            ],
        ]);
    }

    /**
     * Assign driver to truck
     */
    public function assignDriver(Request $request, $id)
    {
        $truck = Truck::findOrFail($id);

        if ($truck->user_id !== Auth::id() && !Auth::user()->isAdmin()) {
            return response()->json([
                'status' => 'error',
                'message' => 'You do not have permission to assign drivers to this truck',
            ], 403);
        }

        $request->validate([
            'driver_id' => 'required|exists:users,id',
        ]);

        $truck->update([
            'driver_id' => $request->driver_id,
            'driver_assigned_at' => now(),
        ]);

        // Log assignment
        TruckLog::log(
            $truck->id,
            TruckLog::ACTION_UPDATED,
            'Driver assigned',
            ['driver_id' => $request->driver_id]
        );

        return response()->json([
            'status' => 'success',
            'message' => 'Driver assigned successfully',
            'data' => $truck->fresh(),
        ]);
    }

    /**
     * Get truck documents
     */
    public function documents($truckId)
    {
        $truck = Truck::findOrFail($truckId);
        $documents = $truck->documents()->with(['user', 'verifier'])->get();

        return response()->json([
            'status' => 'success',
            'data' => $documents,
        ]);
    }

    /**
     * Upload document to truck
     */
    public function uploadDocument(Request $request, $truckId)
    {
        $truck = Truck::findOrFail($truckId);

        if ($truck->user_id !== Auth::id() && !Auth::user()->isAdmin()) {
            return response()->json([
                'status' => 'error',
                'message' => 'You do not have permission to upload documents',
            ], 403);
        }

        $request->validate([
            'document' => 'required|file|max:10240|mimes:pdf,doc,docx,jpg,jpeg,png',
            'document_type' => 'required|in:insurance,registration,road_worthy,permit,inspection,license,other',
            'title' => 'required|string|max:255',
            'description' => 'nullable|string|max:500',
            'expiry_date' => 'nullable|date',
        ]);

        $file = $request->file('document');
        // Store under public/assets so the apps can load it directly.
        $path = PublicAssetUploader::put($file, 'docs/truck-documents/'.$truck->id);

        $document = TruckDocument::create([
            'truck_id' => $truck->id,
            'user_id' => Auth::id(),
            'document_type' => $request->document_type,
            'title' => $request->title,
            'description' => $request->description,
            'file_path' => $path,
            'file_name' => $file->getClientOriginalName(),
            'file_size' => $file->getSize(),
            'file_extension' => $file->getClientOriginalExtension(),
            'document_number' => $request->document_number ?? null,
            'issue_date' => $request->issue_date ?? null,
            'expiry_date' => $request->expiry_date ?? null,
            'status' => TruckDocument::STATUS_PENDING,
            'is_required' => $request->is_required ?? true,
        ]);

        return response()->json([
            'status' => 'success',
            'message' => 'Document uploaded successfully',
            'data' => $document,
        ], 201);
    }

    /**
     * Delete truck document
     */
    public function deleteDocument($truckId, $documentId)
    {
        $document = TruckDocument::where('truck_id', $truckId)->findOrFail($documentId);

        if ($document->user_id !== Auth::id() && !Auth::user()->isAdmin()) {
            return response()->json([
                'status' => 'error',
                'message' => 'You do not have permission to delete this document',
            ], 403);
        }

        // Delete file (public/assets or legacy storage).
        PublicAssetUploader::delete($document->file_path);

        $document->delete();

        return response()->json([
            'status' => 'success',
            'message' => 'Document deleted successfully',
        ]);
    }

    /**
     * Get truck insurance
     */
    public function insurance($truckId)
    {
        $truck = Truck::findOrFail($truckId);
        $insurance = $truck->insurance;

        return response()->json([
            'status' => 'success',
            'data' => $insurance,
        ]);
    }

    /**
     * Add insurance to truck
     */
    public function addInsurance(Request $request, $truckId)
    {
        $truck = Truck::findOrFail($truckId);

        if ($truck->user_id !== Auth::id() && !Auth::user()->isAdmin()) {
            return response()->json([
                'status' => 'error',
                'message' => 'You do not have permission to add insurance',
            ], 403);
        }

        $request->validate([
            'policy_number' => 'required|string|unique:truck_insurance',
            'insurance_company' => 'required|string|max:255',
            'type' => 'required|in:comprehensive,third_party,motor_accident,fire_theft,public_liability,goods_transit,other',
            'coverage_start_date' => 'required|date',
            'coverage_end_date' => 'required|date|after:coverage_start_date',
            'premium_amount' => 'required|numeric|min:0',
            'premium_currency' => 'nullable|string|max:3|default:GHS',
            'payment_frequency' => 'nullable|in:monthly,quarterly,biannually,annually',
        ]);

        $insurance = TruckInsurance::create(array_merge(
            $request->all(),
            ['truck_id' => $truck->id]
        ));

        return response()->json([
            'status' => 'success',
            'message' => 'Insurance added successfully',
            'data' => $insurance,
        ], 201);
    }

    /**
     * Update truck insurance
     */
    public function updateInsurance(Request $request, $truckId, $insuranceId)
    {
        $insurance = TruckInsurance::where('truck_id', $truckId)->findOrFail($insuranceId);

        if ($insurance->truck->user_id !== Auth::id() && !Auth::user()->isAdmin()) {
            return response()->json([
                'status' => 'error',
                'message' => 'You do not have permission to update insurance',
            ], 403);
        }

        $request->validate([
            'policy_number' => 'sometimes|string|unique:truck_insurance,policy_number,' . $insurance->id,
            'insurance_company' => 'sometimes|string|max:255',
            'type' => 'sometimes|in:comprehensive,third_party,motor_accident,fire_theft,public_liability,goods_transit,other',
            'coverage_start_date' => 'sometimes|date',
            'coverage_end_date' => 'sometimes|date|after:coverage_start_date',
            'premium_amount' => 'sometimes|numeric|min:0',
            'status' => 'sometimes|in:active,expired,cancelled,pending,suspended',
        ]);

        $insurance->update($request->all());

        return response()->json([
            'status' => 'success',
            'message' => 'Insurance updated successfully',
            'data' => $insurance->fresh(),
        ]);
    }

    /**
     * Get truck maintenance records
     */
    public function maintenance($truckId)
    {
        $truck = Truck::findOrFail($truckId);
        $maintenance = $truck->maintenanceRecords()->orderBy('performed_at', 'desc')->get();

        return response()->json([
            'status' => 'success',
            'data' => $maintenance,
        ]);
    }

    /**
     * Add maintenance record to truck
     */
    public function addMaintenance(Request $request, $truckId)
    {
        $truck = Truck::findOrFail($truckId);

        if ($truck->user_id !== Auth::id() && !Auth::user()->isAdmin()) {
            return response()->json([
                'status' => 'error',
                'message' => 'You do not have permission to add maintenance records',
            ], 403);
        }

        $request->validate([
            'maintenance_type' => 'required|in:routine,repair,emergency',
            'description' => 'required|string|max:500',
            'cost' => 'nullable|numeric|min:0',
            'performed_at' => 'required|date',
            'mileage_at_service' => 'nullable|numeric|min:0',
            'notes' => 'nullable|string|max:500',
        ]);

        $maintenance = TruckMaintenance::create(array_merge(
            $request->all(),
            ['truck_id' => $truck->id]
        ));

        // Log maintenance
        TruckLog::logMaintenance(
            $truck->id,
            $request->maintenance_type,
            $request->description,
            ['cost' => $request->cost, 'mileage' => $request->mileage_at_service]
        );

        return response()->json([
            'status' => 'success',
            'message' => 'Maintenance record added successfully',
            'data' => $maintenance,
        ], 201);
    }

    /**
     * Update maintenance record
     */
    public function updateMaintenance(Request $request, $truckId, $maintenanceId)
    {
        $maintenance = TruckMaintenance::where('truck_id', $truckId)->findOrFail($maintenanceId);

        if ($maintenance->truck->user_id !== Auth::id() && !Auth::user()->isAdmin()) {
            return response()->json([
                'status' => 'error',
                'message' => 'You do not have permission to update maintenance records',
            ], 403);
        }

        $request->validate([
            'maintenance_type' => 'sometimes|in:routine,repair,emergency',
            'description' => 'sometimes|string|max:500',
            'cost' => 'nullable|numeric|min:0',
            'performed_at' => 'sometimes|date',
            'mileage_at_service' => 'nullable|numeric|min:0',
            'notes' => 'nullable|string|max:500',
            'status' => 'sometimes|in:scheduled,in_progress,completed,cancelled',
        ]);

        $maintenance->update($request->all());

        return response()->json([
            'status' => 'success',
            'message' => 'Maintenance record updated successfully',
            'data' => $maintenance->fresh(),
        ]);
    }

    /**
     * Activity history for a truck (owner or admin only).
     */
    public function truckLogs(Request $request, $truckId)
    {
        $truck = Truck::findOrFail($truckId);

        if ($truck->user_id !== Auth::id() && !Auth::user()->isAdmin()) {
            return response()->json([
                'status' => 'error',
                'message' => 'You do not have permission to view these logs',
            ], 403);
        }

        $logs = $truck->logs()
            ->with('user:id,name')
            ->when($request->filled('action'), fn ($q) => $q->where('action', $request->action))
            ->orderByDesc('created_at')
            ->paginate($request->get('per_page', 20));

        return response()->json([
            'status' => 'success',
            'data' => [
                'logs' => $logs->items(),
                'pagination' => [
                    'current_page' => $logs->currentPage(),
                    'last_page' => $logs->lastPage(),
                    'per_page' => $logs->perPage(),
                    'total' => $logs->total(),
                ],
            ],
        ]);
    }
}
