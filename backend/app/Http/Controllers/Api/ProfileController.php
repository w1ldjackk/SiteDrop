<?php
// app/Http/Controllers/Api/ProfileController.php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\ProfileUpdateRequest;
use App\Http\Requests\Api\VerifyIdentityRequest;
use App\Models\Profile;
use App\Models\Setting;
use App\Services\Activity\ActivityActions;
use App\Services\Activity\ActivityLogger;
use App\Support\PublicAssetUploader;
use Illuminate\Foundation\Auth\Access\AuthorizesRequests;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ProfileController extends Controller
{
    use AuthorizesRequests;

    /**
     * Get user profile
     */
    public function show(Request $request): JsonResponse
    {
        $user = $request->user();
        $profile = $user->getProfile();

        return response()->json([
            'status' => 'success',
            'data' => [
                'user' => $user->only(['id', 'name', 'email', 'phone', 'role', 'phone_verified']),
                'profile' => $profile,
                'seller_profile' => $user->sellerProfile,
                'wallet' => $user->wallet,
                'stats' => $this->buildStats($user),
            ]
        ]);
    }

    /**
     * Lightweight account stats for profile cards.
     */
    public function stats(Request $request): JsonResponse
    {
        $user = $request->user();

        return response()->json([
            'status' => 'success',
            'data' => $this->buildStats($user),
        ]);
    }

    /**
     * @return array<string, int|float|string|null>
     */
    private function buildStats($user): array
    {
        $ordersCount = $user->buyerOrders()->count();
        $reviewsCount = $user->reviewsGiven()->count();
        $wishlistCount = method_exists($user, 'wishlists')
            ? $user->wishlists()->count()
            : 0;

        // Driver-oriented stats (safe zeros for non-drivers)
        $deliveriesCount = $user->deliveries()->count();
        $avgRating = (float) ($user->reviewsReceived()->avg('rating') ?? 0);

        return [
            'orders_count' => $ordersCount,
            'reviews_count' => $reviewsCount,
            'wishlist_count' => $wishlistCount,
            'deliveries_count' => $deliveriesCount,
            'rating' => round($avgRating, 1),
        ];
    }

    /**
     * Update user profile
     */
    public function update(ProfileUpdateRequest $request): JsonResponse
    {
        $user = $request->user();
        $profile = $user->getProfile();

        // Update user basic info
        if ($request->has('name')) {
            $user->update(['name' => $request->name]);
        }

        // Update profile
        $profileData = $request->only([
            'first_name',
            'last_name',
            'date_of_birth',
            'gender',
            'alternate_phone',
            'address',
            'coordinates',
            'bio',
            'nationality',
            'occupation',
            'company',
            'emergency_contact_name',
            'emergency_contact_phone',
            'emergency_contact_relationship',
        ]);

        $profile->update($profileData);

        ActivityLogger::log(
            ActivityActions::PROFILE_UPDATED,
            "Profile updated for {$user->name}",
            $user,
            ['fields' => array_keys(array_filter($profileData))],
            module: 'profile',
            userId: $user->id,
        );

        return response()->json([
            'status' => 'success',
            'message' => 'Profile updated successfully',
            'data' => [
                'user' => $user->fresh()->only(['id', 'name', 'email', 'phone', 'role']),
                'profile' => $profile->fresh(),
            ]
        ]);
    }

    /**
     * Upload profile avatar
     */
    public function uploadAvatar(Request $request): JsonResponse
    {
        $request->validate([
            'avatar' => 'required|image|max:2048|mimes:jpg,jpeg,png,webp',
        ]);

        $user = $request->user();
        $profile = $user->getProfile();

        // Delete old avatar if exists (public/assets or legacy storage).
        PublicAssetUploader::delete($profile->avatar_url);

        // Upload new avatar to public/assets.
        $avatarUrl = PublicAssetUploader::put($request->file('avatar'), 'img/avatars');
        $profile->update(['avatar_url' => $avatarUrl]);

        ActivityLogger::log(
            ActivityActions::PROFILE_AVATAR,
            "Avatar updated for {$user->name}",
            $user,
            module: 'profile',
            userId: $user->id,
        );

        return response()->json([
            'status' => 'success',
            'message' => 'Avatar uploaded successfully',
            'data' => ['avatar_url' => $profile->avatar_url]
        ]);
    }

    /**
     * Delete profile avatar
     */
    public function deleteAvatar(Request $request): JsonResponse
    {
        $user = $request->user();
        $profile = $user->getProfile();

        if ($profile->avatar_url) {
            PublicAssetUploader::delete($profile->avatar_url);
            $profile->update(['avatar_url' => null]);
        }

        return response()->json([
            'status' => 'success',
            'message' => 'Avatar deleted successfully'
        ]);
    }

    /**
     * Verify user identity
     */
    public function verifyIdentity(VerifyIdentityRequest $request): JsonResponse
    {
        $user = $request->user();
        $profile = $user->getProfile();

        // Handle identity document upload (public/assets).
        if ($request->hasFile('document')) {
            $docUrl = PublicAssetUploader::put($request->file('document'), 'docs/identity-documents');
            $profile->update([
                'identity_document' => $docUrl,
                'identity_verified_at' => now(),
            ]);
        }

        return response()->json([
            'status' => 'success',
            'message' => 'Identity verification submitted',
            'data' => [
                'identity_verified_at' => $profile->identity_verified_at,
                'is_verified' => $profile->is_identity_verified,
            ]
        ]);
    }

    /**
     * Get user preferences
     */
    public function getPreferences(Request $request): JsonResponse
    {
        $user = $request->user();
        $profile = $user->getProfile();

        $preferences = array_merge([
            'notifications' => true,
            'email_updates' => true,
            'sms_updates' => true,
            'language' => 'en',
            'currency' => 'GHS',
            // Granular notification matrix defaults (partner = opt-in).
            'notif_products_email' => true,
            'notif_products_push' => true,
            'notif_products_sms' => true,
            'notif_promos_email' => true,
            'notif_promos_push' => true,
            'notif_promos_sms' => false,
            'notif_partner_email' => false,
            'notif_partner_push' => false,
            'notif_partner_sms' => false,
        ], $profile->preferences ?? []);

        $preferences['theme_mode'] = Setting::getForUser(
            $user->id,
            \App\Models\Setting::KEY_THEME_MODE,
            'system'
        );

        return response()->json([
            'status' => 'success',
            'data' => [
                'preferences' => $preferences,
            ],
        ]);
    }

    /**
     * Update user preferences
     */
    public function updatePreferences(Request $request): JsonResponse
    {
        $request->validate([
            'notifications' => 'sometimes|boolean',
            'email_updates' => 'sometimes|boolean',
            'sms_updates' => 'sometimes|boolean',
            'language' => 'sometimes|string|in:en,fr,es,pt,tw,ha,ee,ga',
            'currency' => 'sometimes|string|in:GHS,NGN,KES,USD',
            'theme_mode' => 'sometimes|string|in:system,light,dark',
            // Granular notification matrix (Settings → Notifications).
            'notif_products_email' => 'sometimes|boolean',
            'notif_products_push' => 'sometimes|boolean',
            'notif_products_sms' => 'sometimes|boolean',
            'notif_promos_email' => 'sometimes|boolean',
            'notif_promos_push' => 'sometimes|boolean',
            'notif_promos_sms' => 'sometimes|boolean',
            'notif_partner_email' => 'sometimes|boolean',
            'notif_partner_push' => 'sometimes|boolean',
            'notif_partner_sms' => 'sometimes|boolean',
            'default_payment_method' => 'sometimes|string|max:50',
        ]);

        $user = $request->user();
        $profile = $user->getProfile();
        $data = $request->all();

        // Keep theme_mode in settings table (source of truth for appearance)
        if ($request->has('theme_mode')) {
            Setting::setForUser(
                $user->id,
                Setting::KEY_THEME_MODE,
                $request->input('theme_mode'),
                'string'
            );
            unset($data['theme_mode']);
        }

        if (!empty($data)) {
            $profile->updatePreferences($data);
        }

        $preferences = $profile->fresh()->preferences ?? [];
        $preferences['theme_mode'] = Setting::getForUser(
            $user->id,
            Setting::KEY_THEME_MODE,
            'system'
        );

        return response()->json([
            'status' => 'success',
            'message' => 'Preferences updated successfully',
            'data' => ['preferences' => $preferences],
        ]);
    }
}
