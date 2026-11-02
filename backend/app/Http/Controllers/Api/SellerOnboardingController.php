<?php
// app/Http/Controllers/Api/SellerOnboardingController.php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\SellerOnboardingRequest;
use App\Models\SellerProfile;
use App\Services\Activity\ActivityActions;
use App\Services\Activity\ActivityLogger;
use App\Support\PublicAssetUploader;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Foundation\Auth\Access\AuthorizesRequests;

class SellerOnboardingController extends Controller
{
    use AuthorizesRequests;

    /**
     * Get seller profile
     */
    public function show(Request $request): JsonResponse
    {
        $user = $request->user();

        $sellerProfile = $user->sellerProfile;

        if (!$sellerProfile) {
            return response()->json([
                'status' => 'success',
                'data' => [
                    'seller_profile' => null,
                    'is_complete' => false,
                    'missing_fields' => $this->getMissingFields(null),
                ]
            ]);
        }

        return response()->json([
            'status' => 'success',
            'data' => [
                'seller_profile' => $sellerProfile,
                'is_complete' => $this->checkOnboardingComplete($sellerProfile),
                'missing_fields' => $this->getMissingFields($sellerProfile),
            ]
        ]);
    }

    /**
     * Lightweight seller verification status for the apps.
     * GET /api/v1/seller/status
     */
    public function status(Request $request): JsonResponse
    {
        $user = $request->user();
        $sellerProfile = $user->sellerProfile;

        if (!$sellerProfile) {
            return response()->json([
                'status' => 'success',
                'data' => [
                    'has_profile' => false,
                    'seller_status' => null,
                    'is_complete' => false,
                    'missing_fields' => $this->getMissingFields(null),
                    'can_sell' => false,
                ]
            ]);
        }

        return response()->json([
            'status' => 'success',
            'data' => [
                'has_profile' => true,
                'seller_status' => $sellerProfile->status,
                'is_complete' => $this->checkOnboardingComplete($sellerProfile),
                'missing_fields' => $this->getMissingFields($sellerProfile),
                'can_sell' => $sellerProfile->status === 'approved',
                'approved_at' => $sellerProfile->approved_at,
                'rejected_reason' => $sellerProfile->rejected_reason,
            ]
        ]);
    }

    /**
     * Sellers that can serve a point — for truck/delivery matching.
     * GET /api/v1/seller/nearby?lat=&lng=[&radius_km=][&business_type=]
     * Only approved sellers with pinned coverage areas are considered.
     * Never exposes banking or contact internals.
     */
    public function nearby(Request $request): JsonResponse
    {
        $request->validate([
            'lat' => 'required|numeric|between:-90,90',
            'lng' => 'required|numeric|between:-180,180',
            'radius_km' => 'sometimes|nullable|numeric|min:0|max:2000',
            'business_type' => 'sometimes|nullable|string|max:50',
        ]);

        $lat = (float) $request->lat;
        $lng = (float) $request->lng;
        $cutoff = $request->filled('radius_km') ? (float) $request->radius_km : null;

        $query = SellerProfile::where('status', 'approved');
        if ($request->filled('business_type')) {
            $query->where('business_type', $request->business_type);
        }

        $out = [];
        foreach ($query->get() as $seller) {
            $areas = $seller->service_areas ?? [];
            if (is_string($areas)) {
                $areas = json_decode($areas, true) ?? [];
            }
            if (! is_array($areas) || empty($areas)) {
                continue;
            }
            $best = null;
            $bestArea = null;
            foreach ($areas as $area) {
                if (! is_array($area)) {
                    continue;
                }
                $aLat = $area['lat'] ?? $area['latitude'] ?? null;
                $aLng = $area['lng'] ?? $area['longitude'] ?? $area['lon'] ?? null;
                if (! is_numeric($aLat) || ! is_numeric($aLng)) {
                    continue;
                }
                $radius = isset($area['radius_km']) && is_numeric($area['radius_km'])
                    ? (float) $area['radius_km']
                    : (isset($area['radius']) && is_numeric($area['radius']) ? (float) $area['radius'] : 25.0);
                $dist = $this->haversineKm($lat, $lng, (float) $aLat, (float) $aLng);
                if ($best === null || $dist < $best) {
                    $best = $dist;
                    $bestArea = [
                        'lat' => (float) $aLat,
                        'lng' => (float) $aLng,
                        'label' => $area['label'] ?? '',
                        'radius_km' => $radius,
                    ];
                }
            }
            if ($best === null) {
                continue;
            }
            if ($cutoff !== null && $best > $cutoff) {
                continue;
            }
            $out[] = [
                'id' => $seller->id,
                'seller_code' => $seller->seller_code,
                'business_name' => $seller->business_name,
                'business_type' => $seller->business_type,
                'business_phone' => $seller->business_phone,
                'service_areas' => $this->normalizeAreas($seller->service_areas),
                'delivery_radius_km' => $seller->delivery_radius_km,
                'minimum_order_amount' => $seller->minimum_order_amount,
                'distance_km' => round($best, 2),
                'covers' => $best <= ($bestArea['radius_km'] ?? 25.0),
                'nearest_area' => $bestArea,
            ];
        }

        usort($out, function ($a, $b) {
            if ($a['covers'] !== $b['covers']) {
                return $a['covers'] ? -1 : 1;
            }

            return $a['distance_km'] <=> $b['distance_km'];
        });

        return response()->json([
            'status' => 'success',
            'data' => ['sellers' => $out],
        ]);
    }

    private function haversineKm(float $lat1, float $lng1, float $lat2, float $lng2): float
    {
        $earth = 6371.0;
        $dLat = deg2rad($lat2 - $lat1);
        $dLng = deg2rad($lng2 - $lng1);
        $a = sin($dLat / 2) ** 2
            + cos(deg2rad($lat1)) * cos(deg2rad($lat2)) * sin($dLng / 2) ** 2;

        return 2 * $earth * asin(min(1, sqrt($a)));
    }

    /**
     * Submit profile for admin review (pending).
     * POST /api/v1/seller/submit-for-review
     */
    public function submitForReview(Request $request): JsonResponse
    {
        $user = $request->user();
        $sellerProfile = $user->sellerProfile;

        if (!$sellerProfile) {
            return response()->json([
                'status' => 'error',
                'message' => 'Complete your business profile first'
            ], 422);
        }

        $missing = $this->getMissingFields($sellerProfile);
        if (!empty($missing)) {
            return response()->json([
                'status' => 'error',
                'message' => 'Complete required fields before submitting',
                'data' => ['missing_fields' => $missing],
            ], 422);
        }

        if ($sellerProfile->status !== 'approved') {
            $sellerProfile->update(['status' => 'pending', 'rejected_reason' => null]);

            ActivityLogger::log(
                ActivityActions::SELLER_ONBOARDED,
                "Seller submitted for review: {$sellerProfile->business_name}",
                $sellerProfile,
                ['business_name' => $sellerProfile->business_name, 'status' => 'pending'],
                module: 'seller',
                userId: $user->id,
            );
        }

        return response()->json([
            'status' => 'success',
            'message' => 'Submitted for review. You will be notified once approved.',
            'data' => ['seller_profile' => $sellerProfile->fresh()]
        ]);
    }

    /**
     * Complete seller onboarding
     */
    public function onboard(SellerOnboardingRequest $request): JsonResponse
    {
        $user = $request->user();

        // Ensure user has seller role
        if (!$user->isSeller()) {
            $user->assignRole('seller');
            $user->update(['role' => 'seller']);
        }

        $sellerData = $request->only([
            'business_name',
            'business_type',
            'business_registration_number',
            'tax_id',
            'business_phone',
            'business_email',
            'website',
            'description',
            'service_areas',
            'commission_rate',
            'minimum_order_amount',
            'delivery_radius_km',
            'bank_account_name',
            'bank_account_number',
            'bank_name',
            'bank_branch',
            'business_hours',
            'social_links',
        ]);

        // Create or update seller profile.
        // Preserve an approved/suspended status on plain edits so saving
        // business details does not bounce the seller back to pending.
        // Use submit-for-review to request (re)approval explicitly.
        $existing = SellerProfile::where('user_id', $user->id)->first();
        $status = $existing && in_array($existing->status, ['approved', 'suspended'], true)
            ? $existing->status
            : 'pending';

        // Create or update seller profile
        $sellerProfile = SellerProfile::updateOrCreate(
            ['user_id' => $user->id],
            array_merge($sellerData, [
                'status' => $status,
            ])
        );

        // Handle logo upload if provided (public/assets).
        if ($request->hasFile('logo')) {
            $logoUrl = PublicAssetUploader::put($request->file('logo'), 'img/seller-logos');
            $sellerProfile->update(['logo_url' => $logoUrl]);
        }

        // Handle cover image if provided (public/assets).
        if ($request->hasFile('cover_image')) {
            $coverUrl = PublicAssetUploader::put($request->file('cover_image'), 'img/seller-covers');
            $sellerProfile->update(['cover_image_url' => $coverUrl]);
        }

        // Handle verification documents (append, keep a consistent shape)
        if ($request->hasFile('documents')) {
            $documents = $this->normalizeDocuments($sellerProfile->verification_documents);
            foreach ((array) $request->file('documents') as $doc) {
                if (!$doc) {
                    continue;
                }
                $documents[] = [
                    'type' => 'other',
                    'url' => PublicAssetUploader::put($doc, 'docs/seller-documents'),
                    'uploaded_at' => now()->toIso8601String(),
                ];
            }
            $sellerProfile->update(['verification_documents' => $documents]);
        }

        ActivityLogger::log(
            ActivityActions::SELLER_ONBOARDED,
            "Seller onboarding submitted: {$sellerProfile->business_name}",
            $sellerProfile,
            [
                'business_name' => $sellerProfile->business_name,
                'status' => 'pending',
            ],
            module: 'seller',
            userId: $user->id,
        );

        return response()->json([
            'status' => 'success',
            'message' => 'Seller profile submitted for approval',
            'data' => [
                'seller_profile' => $sellerProfile->fresh(),
                'status' => 'pending_approval',
                'next_steps' => 'Your application is being reviewed. You will be notified once approved.',
            ]
        ]);
    }

    /**
     * Upload seller document
     */
    public function uploadDocument(Request $request): JsonResponse
    {
        $request->validate([
            'document' => 'required|file|max:5120|mimes:pdf,jpg,jpeg,png',
            'document_type' => 'required|string|in:registration,license,insurance,identification,other',
        ]);

        $user = $request->user();
        $sellerProfile = $user->sellerProfile;

        if (!$sellerProfile) {
            return response()->json([
                'status' => 'error',
                'message' => 'Seller profile not found'
            ], 404);
        }

        $documents = $this->normalizeDocuments($sellerProfile->verification_documents);
        $documents[] = [
            'type' => $request->document_type,
            'url' => PublicAssetUploader::put($request->file('document'), 'docs/seller-documents'),
            'uploaded_at' => now()->toIso8601String(),
        ];

        $sellerProfile->update(['verification_documents' => $documents]);

        ActivityLogger::log(
            ActivityActions::SELLER_DOCUMENT,
            "Seller document uploaded ({$request->document_type})",
            $sellerProfile,
            ['document_type' => $request->document_type],
            module: 'seller',
            userId: $user->id,
        );

        return response()->json([
            'status' => 'success',
            'message' => 'Document uploaded successfully',
            'data' => ['documents' => $documents]
        ]);
    }

    /**
     * Check if onboarding is complete
     */
    private function checkOnboardingComplete($sellerProfile): bool
    {
        if (!$sellerProfile) return false;

        $required = [
            $sellerProfile->business_name,
            $sellerProfile->business_type,
            $sellerProfile->business_phone,
            $sellerProfile->business_email,
            $sellerProfile->bank_account_name,
            $sellerProfile->bank_account_number,
            $sellerProfile->bank_name,
        ];

        foreach ($required as $field) {
            if (empty($field)) return false;
        }

        return $sellerProfile->status === 'approved';
    }

    /**
     * Normalize service_areas to [{lat, lng, label, radius_km}].
     * Accepts full entries, legacy {lat,lng}/{latitude,longitude} maps and
     * [lat,lng] pairs.
     */
    private function normalizeAreas($areas): array
    {
        if (is_string($areas)) {
            $areas = json_decode($areas, true) ?? [];
        }
        if (! is_array($areas)) {
            return [];
        }
        $out = [];
        foreach ($areas as $area) {
            if (is_array($area) && array_is_list($area) && count($area) >= 2) {
                $area = ['lat' => $area[0], 'lng' => $area[1]];
            }
            if (! is_array($area)) {
                continue;
            }
            $lat = $area['lat'] ?? $area['latitude'] ?? null;
            $lng = $area['lng'] ?? $area['longitude'] ?? $area['lon'] ?? null;
            if (! is_numeric($lat) || ! is_numeric($lng)) {
                continue;
            }
            $out[] = [
                'lat' => (float) $lat,
                'lng' => (float) $lng,
                'label' => $area['label'] ?? '',
                'radius_km' => isset($area['radius_km']) && is_numeric($area['radius_km'])
                    ? (float) $area['radius_km']
                    : (isset($area['radius']) && is_numeric($area['radius']) ? (float) $area['radius'] : 25.0),
            ];
        }

        return $out;
    }

    /**
     * Normalize verification_documents to a list of
     * {type, url, uploaded_at} maps. Older rows may hold plain URL strings.
     */
    private function normalizeDocuments($documents): array
    {
        if (is_string($documents)) {
            $decoded = json_decode($documents, true);
            $documents = is_array($decoded) ? $decoded : [$documents];
        }
        if (!is_array($documents)) {
            return [];
        }

        $out = [];
        foreach ($documents as $doc) {
            if (is_string($doc) && $doc !== '') {
                $out[] = ['type' => 'other', 'url' => $doc, 'uploaded_at' => null];
            } elseif (is_array($doc) && !empty($doc['url'])) {
                $out[] = [
                    'type' => $doc['type'] ?? 'other',
                    'url' => $doc['url'],
                    'uploaded_at' => $doc['uploaded_at'] ?? null,
                ];
            }
        }

        return $out;
    }

    /**
     * Get missing fields for onboarding
     */
    private function getMissingFields($sellerProfile): array
    {
        $missing = [];
        $fields = [
            'business_name' => 'Business Name',
            'business_type' => 'Business Type',
            'business_phone' => 'Business Phone',
            'business_email' => 'Business Email',
            'bank_account_name' => 'Bank Account Name',
            'bank_account_number' => 'Bank Account Number',
            'bank_name' => 'Bank Name',
        ];

        foreach ($fields as $field => $label) {
            if (!$sellerProfile || empty($sellerProfile->$field)) {
                $missing[] = $label;
            }
        }

        return $missing;
    }
}
