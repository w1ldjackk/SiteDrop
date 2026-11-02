<?php
// app/Http/Controllers/Api/SecurityController.php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;
use Laravel\Fortify\Actions\ConfirmTwoFactorAuthentication;
use Laravel\Fortify\Actions\DisableTwoFactorAuthentication;
use Laravel\Fortify\Actions\EnableTwoFactorAuthentication;

class SecurityController extends Controller
{
    /**
     * Change password (authenticated).
     * POST /profile/password  { current_password, password, password_confirmation }
     */
    public function changePassword(Request $request): JsonResponse
    {
        $request->validate([
            'current_password' => ['required', 'string'],
            'password' => ['required', 'string', 'min:8', 'confirmed'],
        ]);

        $user = Auth::user();

        if (!Hash::check($request->input('current_password'), $user->password)) {
            return response()->json([
                'status' => 'error',
                'message' => 'Current password is incorrect',
            ], 422);
        }

        $user->forceFill([
            'password' => Hash::make($request->input('password')),
        ])->save();

        return response()->json([
            'status' => 'success',
            'message' => 'Password changed successfully',
        ]);
    }

    /**
     * Two-factor status.
     * GET /profile/2fa/status
     */
    public function twoFactorStatus(Request $request): JsonResponse
    {
        $user = $request->user();

        return response()->json([
            'status' => 'success',
            'data' => [
                'enabled' => $user->hasEnabledTwoFactorAuthentication(),
                'confirmed' => !empty($user->two_factor_confirmed_at),
            ],
        ]);
    }

    /**
     * Start 2FA setup — returns secret + otpauth URL for the authenticator app.
     * POST /profile/2fa/enable
     */
    public function enableTwoFactor(Request $request): JsonResponse
    {
        $user = $request->user();

        if ($user->hasEnabledTwoFactorAuthentication()) {
            return response()->json([
                'status' => 'error',
                'message' => 'Two-factor authentication is already enabled',
            ], 422);
        }

        app(EnableTwoFactorAuthentication::class)($user);
        $user->refresh();

        return response()->json([
            'status' => 'success',
            'message' => 'Scan the code, then confirm with a 6-digit code',
            'data' => [
                'secret' => decrypt($user->two_factor_secret),
                'otpauth_url' => $user->twoFactorQrCodeUrl(),
                'recovery_codes' => json_decode(
                    decrypt($user->two_factor_recovery_codes),
                    true
                ),
            ],
        ]);
    }

    /**
     * Confirm 2FA setup with a 6-digit authenticator code.
     * POST /profile/2fa/confirm  { code }
     */
    public function confirmTwoFactor(Request $request): JsonResponse
    {
        $request->validate(['code' => ['required', 'string']]);

        try {
            app(ConfirmTwoFactorAuthentication::class)(
                $request->user(),
                $request->input('code')
            );
        } catch (ValidationException $e) {
            return response()->json([
                'status' => 'error',
                'message' => 'Invalid authenticator code',
            ], 422);
        }

        return response()->json([
            'status' => 'success',
            'message' => 'Two-factor authentication enabled',
        ]);
    }

    /**
     * Disable 2FA.
     * DELETE /profile/2fa
     */
    public function disableTwoFactor(Request $request): JsonResponse
    {
        app(DisableTwoFactorAuthentication::class)($request->user());

        return response()->json([
            'status' => 'success',
            'message' => 'Two-factor authentication disabled',
        ]);
    }
}
