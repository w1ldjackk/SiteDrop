<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Mobile/web FCM device token registration.
 */
class DeviceTokenController extends Controller
{
    /**
     * POST /api/v1/notifications/register-token
     */
    public function register(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'token' => ['required', 'string', 'min:20', 'max:4096'],
            'platform' => ['nullable', 'string', 'max:40'],
            'device_type' => ['nullable', 'string', 'max:40'],
        ]);

        $user = $request->user();
        $deviceType = $validated['device_type']
            ?? $validated['platform']
            ?? $user->device_type
            ?? null;

        $user->forceFill([
            'fcm_token' => $validated['token'],
            'device_type' => is_string($deviceType) ? strtolower($deviceType) : $deviceType,
        ])->save();

        return $this->success(
            data: [
                'device_type' => $user->device_type,
                'token_suffix' => substr($validated['token'], -8),
            ],
            message: 'Device token registered',
        );
    }

    /**
     * DELETE /api/v1/notifications/register-token
     */
    public function unregister(Request $request): JsonResponse
    {
        $user = $request->user();
        $user->forceFill([
            'fcm_token' => null,
        ])->save();

        return $this->success(message: 'Device token cleared');
    }
}
