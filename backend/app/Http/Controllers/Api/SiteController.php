<?php
// app/Http/Controllers/Api/SiteController.php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Site;
use App\Models\SiteVisit;
use App\Models\SiteStaff;
use App\Models\SiteDocument;
use App\Models\User;
use App\Support\PublicAssetUploader;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Foundation\Auth\Access\AuthorizesRequests;

class SiteController extends Controller
{
    use AuthorizesRequests;

    /**
     * Get all sites with filters
     */
    public function index(Request $request)
    {
        $query = Site::with(['user', 'siteManager', 'supervisor']);

        // Filter by status
        if ($request->has('status')) {
            $query->where('status', $request->status);
        }

        // Filter by site type
        if ($request->has('site_type')) {
            $query->where('site_type', $request->site_type);
        }

        // Filter by priority
        if ($request->has('priority')) {
            $query->where('priority_level', $request->priority);
        }

        // Search
        if ($request->has('search')) {
            $search = $request->search;
            $query->where(function ($q) use ($search) {
                $q->where('name', 'like', "%{$search}%")
                    ->orWhere('address', 'like', "%{$search}%")
                    ->orWhere('contact_person', 'like', "%{$search}%");
            });
        }

        // Filter by user (buyer's sites)
        if ($request->has('user_id')) {
            $query->where('user_id', $request->user_id);
        }

        $sites = $query->orderBy('created_at', 'desc')
            ->paginate($request->get('per_page', 20));

        return response()->json([
            'status' => 'success',
            'data' => [
                'sites' => $sites->items(),
                'pagination' => [
                    'current_page' => $sites->currentPage(),
                    'last_page' => $sites->lastPage(),
                    'per_page' => $sites->perPage(),
                    'total' => $sites->total(),
                ],
            ],
        ]);
    }

    /**
     * Get nearby sites based on coordinates
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

        $sites = Site::nearby($lat, $lng, $radius)
            ->with(['user', 'siteManager'])
            ->where('status', Site::STATUS_ACTIVE)
            ->get();

        return response()->json([
            'status' => 'success',
            'data' => $sites,
        ]);
    }

    /**
     * Get single site details
     */
    public function show($id)
    {
        $site = Site::with([
            'user',
            'siteManager',
            'supervisor',
            'materials',
            'staff',
            'documents',
            'visits',
            'orders',
            'stockedProducts',
        ])->findOrFail($id);

        // Get statistics
        $stats = [
            'total_materials' => $site->materials->count(),
            'materials_progress' => $site->progress,
            'total_staff' => $site->staff->count(),
            'total_visits' => $site->visits->count(),
            'total_orders' => $site->orders->count(),
            'total_spent' => $site->total_spent,
            'stocked_products' => $site->stockedProducts->count(),
        ];

        return response()->json([
            'status' => 'success',
            'data' => [
                'site' => $site,
                'statistics' => $stats,
            ],
        ]);
    }

    /**
     * Create a new site
     */
    public function store(Request $request)
    {
        $request->validate([
            'name' => 'required|string|max:255',
            'address' => 'required|string|max:500',
            'coordinates' => 'nullable|array',
            'coordinates.lat' => 'required_with:coordinates|numeric|between:-90,90',
            'coordinates.lng' => 'required_with:coordinates|numeric|between:-180,180',
            'contact_person' => 'nullable|string|max:100',
            'contact_phone' => 'nullable|string|max:20',
            'site_type' => 'required|in:construction,quarry,warehouse,supplier,other',
            'status' => 'nullable|in:planning,active,on_hold,completed,cancelled',
            'priority_level' => 'nullable|in:high,medium,low',
            'size_sq_meters' => 'nullable|numeric|min:0',
            'budget' => 'nullable|numeric|min:0',
            'project_start_date' => 'nullable|date',
            'estimated_completion_date' => 'nullable|date|after:project_start_date',
            'description' => 'nullable|string|max:2000',
            'site_photos' => 'nullable|array',
            'site_photos.*' => 'file|max:5120|mimes:jpg,jpeg,png,webp',
        ]);

        $siteData = $request->except(['site_photos', 'site_photos.*']);
        $siteData['user_id'] = Auth::id();

        // Generate site code if not provided
        if (empty($siteData['site_code'])) {
            $siteData['site_code'] = $this->generateSiteCode();
        }

        // Set default status if not provided
        if (empty($siteData['status'])) {
            $siteData['status'] = Site::STATUS_PLANNING;
        }

        // Handle site photos (multipart: site_photos[] or site_photos)
        $photoUrls = [];
        if ($request->hasFile('site_photos')) {
            $files = $request->file('site_photos');
            $files = is_array($files) ? $files : [$files];
            foreach ($files as $file) {
                if (!$file || !$file->isValid()) continue;
                $photoUrls[] = PublicAssetUploader::put($file, 'img/site-photos');
            }
        }
        if (!empty($photoUrls)) {
            $siteData['site_photos'] = $photoUrls;
        }

        $site = Site::create($siteData);

        return response()->json([
            'status' => 'success',
            'message' => 'Site created successfully',
            'data' => $site,
        ], 201);
    }

    /**
     * Update a site
     */
    public function update(Request $request, $id)
    {
        $site = Site::findOrFail($id);

        // Check if user owns this site or is admin
        if ($site->user_id !== Auth::id() && !Auth::user()->isAdmin()) {
            return response()->json([
                'status' => 'error',
                'message' => 'You do not have permission to update this site',
            ], 403);
        }

        $request->validate([
            'name' => 'sometimes|string|max:255',
            'address' => 'sometimes|string|max:500',
            'coordinates' => 'nullable|array',
            'contact_person' => 'nullable|string|max:100',
            'contact_phone' => 'nullable|string|max:20',
            'site_type' => 'sometimes|in:construction,quarry,warehouse,supplier,other',
            'status' => 'sometimes|in:planning,active,on_hold,completed,cancelled',
            'priority_level' => 'sometimes|in:high,medium,low',
            'size_sq_meters' => 'nullable|numeric|min:0',
            'budget' => 'nullable|numeric|min:0',
            'project_start_date' => 'nullable|date',
            'estimated_completion_date' => 'nullable|date|after:project_start_date',
            'description' => 'nullable|string|max:2000',
            'site_photos' => 'nullable|array',
            'site_photos.*' => 'file|max:5120|mimes:jpg,jpeg,png,webp',
            'existing_photos' => 'nullable|array',
            'existing_photos.*' => 'nullable|string|max:500',
        ]);

        // NOTE: multipart updates arrive as POST + _method=PUT (PHP never
        // parses multipart bodies on real PUT), so uploaded files live in
        // site_photos[] and the kept list in existing_photos[].
        $data = $request->except(['site_photos', 'site_photos.*', 'existing_photos', '_method']);

        // New uploads
        $newUrls = [];
        if ($request->hasFile('site_photos')) {
            $files = $request->file('site_photos');
            $files = is_array($files) ? $files : [$files];
            foreach ($files as $file) {
                if (!$file || !$file->isValid()) continue;
                $newUrls[] = PublicAssetUploader::put($file, 'img/site-photos');
            }
        }

        // Merge kept + new. When the app sends existing_photos it is the
        // source of truth (supports photo removal); otherwise append.
        if ($request->has('existing_photos')) {
            $kept = array_values(array_filter((array) $request->input('existing_photos')));
            $data['site_photos'] = array_values(array_merge($kept, $newUrls));
        } elseif (!empty($newUrls)) {
            $current = $site->site_photos ?? [];
            if (is_string($current)) {
                $current = json_decode($current, true) ?? [];
            }
            $data['site_photos'] = array_values(array_merge((array) $current, $newUrls));
        }

        $site->update($data);

        return response()->json([
            'status' => 'success',
            'message' => 'Site updated successfully',
            'data' => $site->fresh(),
        ]);
    }

    /**
     * Delete a site
     */
    public function destroy($id)
    {
        $site = Site::findOrFail($id);

        if ($site->user_id !== Auth::id() && !Auth::user()->isAdmin()) {
            return response()->json([
                'status' => 'error',
                'message' => 'You do not have permission to delete this site',
            ], 403);
        }

        $site->delete();

        return response()->json([
            'status' => 'success',
            'message' => 'Site deleted successfully',
        ]);
    }

    /**
     * Update site status
     */
    public function updateStatus(Request $request, $id)
    {
        $site = Site::findOrFail($id);

        if ($site->user_id !== Auth::id() && !Auth::user()->isAdmin()) {
            return response()->json([
                'status' => 'error',
                'message' => 'You do not have permission to update this site',
            ], 403);
        }

        $request->validate([
            'status' => 'required|in:planning,active,on_hold,completed,cancelled',
            'reason' => 'nullable|string|max:500',
        ]);

        $oldStatus = $site->status;
        $site->updateStatus($request->status, $request->reason);

        return response()->json([
            'status' => 'success',
            'message' => 'Site status updated successfully',
            'data' => [
                'site' => $site->fresh(),
                'old_status' => $oldStatus,
                'new_status' => $site->status,
            ],
        ]);
    }

    /**
     * Get site status history
     */
    public function statusLogs($id)
    {
        $site = Site::findOrFail($id);
        $logs = $site->statusLogs()->with('user')->orderBy('created_at', 'desc')->get();

        return response()->json([
            'status' => 'success',
            'data' => $logs,
        ]);
    }

    /**
     * Get site materials
     */
    public function materials($id)
    {
        $site = Site::findOrFail($id);
        $materials = $site->materials()->with('supplier')->get();

        return response()->json([
            'status' => 'success',
            'data' => $materials,
        ]);
    }

    /**
     * Add material to site
     */
    public function addMaterial(Request $request, $id)
    {
        $site = Site::findOrFail($id);

        if ($site->user_id !== Auth::id() && !Auth::user()->isAdmin()) {
            return response()->json([
                'status' => 'error',
                'message' => 'You do not have permission to modify this site',
            ], 403);
        }

        $request->validate([
            'material_name' => 'required|string|max:255',
            'quantity_needed' => 'required|numeric|min:0',
            'unit' => 'required|string|max:50',
            'estimated_cost' => 'nullable|numeric|min:0',
            'expected_delivery_date' => 'nullable|date',
            'supplier_id' => 'nullable|exists:users,id',
        ]);

        $material = $site->addMaterial($request->all());

        return response()->json([
            'status' => 'success',
            'message' => 'Material added successfully',
            'data' => $material,
        ], 201);
    }

    /**
     * Get site staff
     */
    public function staff($id)
    {
        $site = Site::findOrFail($id);
        $staff = $site->staff()->with('user')->get();

        return response()->json([
            'status' => 'success',
            'data' => $staff,
        ]);
    }

    /**
     * Add staff to site
     */
    public function addStaff(Request $request, $id)
    {
        $site = Site::findOrFail($id);

        if ($site->user_id !== Auth::id() && !Auth::user()->isAdmin()) {
            return response()->json([
                'status' => 'error',
                'message' => 'You do not have permission to modify this site',
            ], 403);
        }

        $request->validate([
            'user_id' => 'required|exists:users,id',
            'role' => 'required|in:site_manager,supervisor,foreman,safety_officer,quality_control,operator,laborer,other',
            'position' => 'required|string|max:255',
            'start_date' => 'required|date',
            'is_active' => 'sometimes|boolean',
        ]);

        $staff = SiteStaff::create(array_merge($request->all(), ['site_id' => $site->id]));

        return response()->json([
            'status' => 'success',
            'message' => 'Staff added successfully',
            'data' => $staff,
        ], 201);
    }

    /**
     * Get site documents
     */
    public function documents($id)
    {
        $site = Site::findOrFail($id);
        $documents = $site->documents()->with('uploader')->get();

        return response()->json([
            'status' => 'success',
            'data' => $documents,
        ]);
    }

    /**
     * Upload document to site
     */
    public function uploadDocument(Request $request, $id)
    {
        $site = Site::findOrFail($id);

        if ($site->user_id !== Auth::id() && !Auth::user()->isAdmin()) {
            return response()->json([
                'status' => 'error',
                'message' => 'You do not have permission to upload documents to this site',
            ], 403);
        }

        $request->validate([
            'document' => 'required|file|max:10240|mimes:pdf,doc,docx,jpg,jpeg,png',
            'title' => 'required|string|max:255',
            'description' => 'nullable|string|max:500',
            'document_type' => 'required|in:permit,contract,blueprint,report,invoice,insurance,certificate,other',
            'is_confidential' => 'sometimes|boolean',
            'access_level' => 'sometimes|in:public,private,restricted',
        ]);

        $file = $request->file('document');
        // Store under public/assets so the apps can load it directly.
        $path = PublicAssetUploader::put($file, 'docs/site-documents/'.$site->id);

        $document = SiteDocument::create([
            'site_id' => $site->id,
            'user_id' => Auth::id(),
            'title' => $request->title,
            'description' => $request->description,
            'document_type' => $request->document_type,
            'file_path' => $path,
            'file_name' => $file->getClientOriginalName(),
            'file_size' => $file->getSize(),
            'file_extension' => $file->getClientOriginalExtension(),
            'uploaded_by' => Auth::id(),
            'is_confidential' => $request->is_confidential ?? false,
            'access_level' => $request->access_level ?? 'private',
            'status' => SiteDocument::STATUS_DRAFT,
        ]);

        return response()->json([
            'status' => 'success',
            'message' => 'Document uploaded successfully',
            'data' => $document,
        ], 201);
    }

    /**
     * Get site visits
     */
    public function visits($siteId)
    {
        $site = Site::findOrFail($siteId);
        $visits = $site->visits()->with(['user', 'approver'])->get();

        return response()->json([
            'status' => 'success',
            'data' => $visits,
        ]);
    }

    /**
     * Create site visit
     */
    public function createVisit(Request $request, $siteId)
    {
        $site = Site::findOrFail($siteId);

        $request->validate([
            'visitor_name' => 'required|string|max:255',
            'visitor_phone' => 'required|string|max:20',
            'visitor_email' => 'nullable|email|max:255',
            'visit_date' => 'required|date',
            'purpose' => 'required|string|max:500',
            'visit_type' => 'sometimes|in:scheduled,walk-in,emergency',
            'vehicle_registration' => 'nullable|string|max:20',
        ]);

        $visit = SiteVisit::create([
            'site_id' => $site->id,
            'user_id' => Auth::id(),
            'visitor_name' => $request->visitor_name,
            'visitor_phone' => $request->visitor_phone,
            'visitor_email' => $request->visitor_email,
            'visit_date' => $request->visit_date,
            'purpose' => $request->purpose,
            'visit_type' => $request->visit_type ?? SiteVisit::VISIT_TYPE_SCHEDULED,
            'vehicle_registration' => $request->vehicle_registration,
            'status' => SiteVisit::STATUS_SCHEDULED,
        ]);

        return response()->json([
            'status' => 'success',
            'message' => 'Site visit created successfully',
            'data' => $visit,
        ], 201);
    }

    /**
     * Update site visit
     */
    public function updateVisit(Request $request, $siteId, $visitId)
    {
        $visit = SiteVisit::where('site_id', $siteId)->findOrFail($visitId);

        if ($visit->user_id !== Auth::id() && !Auth::user()->isAdmin()) {
            return response()->json([
                'status' => 'error',
                'message' => 'You do not have permission to update this visit',
            ], 403);
        }

        $request->validate([
            'status' => 'sometimes|in:scheduled,checked_in,in_progress,completed,cancelled,rejected',
            'notes' => 'nullable|string|max:500',
        ]);

        $visit->update($request->only(['status', 'notes']));

        return response()->json([
            'status' => 'success',
            'message' => 'Site visit updated successfully',
            'data' => $visit->fresh(),
        ]);
    }

    /**
     * Check in for site visit
     */
    public function checkIn($siteId, $visitId)
    {
        $visit = SiteVisit::where('site_id', $siteId)->findOrFail($visitId);

        if ($visit->user_id !== Auth::id() && !Auth::user()->isAdmin()) {
            return response()->json([
                'status' => 'error',
                'message' => 'You do not have permission to check in',
            ], 403);
        }

        $visit->checkIn();

        return response()->json([
            'status' => 'success',
            'message' => 'Checked in successfully',
            'data' => $visit->fresh(),
        ]);
    }

    /**
     * Check out from site visit
     */
    public function checkOut($siteId, $visitId)
    {
        $visit = SiteVisit::where('site_id', $siteId)->findOrFail($visitId);

        if ($visit->user_id !== Auth::id() && !Auth::user()->isAdmin()) {
            return response()->json([
                'status' => 'error',
                'message' => 'You do not have permission to check out',
            ], 403);
        }

        $visit->checkOut();

        return response()->json([
            'status' => 'success',
            'message' => 'Checked out successfully',
            'data' => $visit->fresh(),
        ]);
    }

    /**
     * Products stocked at this source site (seller quarry / warehouse).
     */
    public function products(Request $request, $id)
    {
        $site = Site::findOrFail($id);

        $products = $site->stockedProducts()
            ->with(['seller', 'sourceSite'])
            ->when($request->filled('available_only'), fn ($q) => $q->where('is_available', true))
            ->orderBy('created_at', 'desc')
            ->paginate($request->get('per_page', 20));

        return response()->json([
            'status' => 'success',
            'data' => [
                'site' => $site->only(['id', 'name', 'site_type', 'address', 'coordinates']),
                'products' => $products->items(),
                'pagination' => [
                    'current_page' => $products->currentPage(),
                    'last_page' => $products->lastPage(),
                    'per_page' => $products->perPage(),
                    'total' => $products->total(),
                ],
            ],
        ]);
    }

    /**
     * Generate site code
     */
    private function generateSiteCode(): string
    {
        $prefix = 'SITE';
        $year = date('Y');
        $random = strtoupper(substr(uniqid(), -6));
        return $prefix . $year . $random;
    }
}
