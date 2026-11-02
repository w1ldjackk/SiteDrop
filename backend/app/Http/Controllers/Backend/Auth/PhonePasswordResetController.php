<?php

namespace App\Http\Controllers\Backend\Auth;

use App\Http\Controllers\Controller;
use App\Http\Controllers\Api\Auth\PasswordController as ApiPasswordController;
use App\Models\User;
use App\Services\Activity\ActivityActions;
use App\Services\Activity\ActivityLogger;
use App\Enums\OtpPurpose;
use App\Services\Auth\OtpService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Hash;
use Inertia\Inertia;
use Inertia\Response;

/**
 * Web UI for the phone SMS reset link (link OR code parity with email).
 */
class PhonePasswordResetController extends Controller
{
    public function show(string $token): Response|RedirectResponse
    {
        $payload = Cache::get(ApiPasswordController::PHONE_LINK_CACHE_PREFIX.$token);

        if (!is_array($payload) || empty($payload['user_id'])) {
            return redirect()
                ->route('login')
                ->withErrors(['email' => 'This password reset link is invalid or has expired.']);
        }

        $phone = $payload['phone'] ?? null;
        $masked = $phone
            ? (str_starts_with($phone, '233')
                ? '0'.substr($phone, 3, 3).'***'.substr($phone, -3)
                : substr($phone, 0, 3).'***'.substr($phone, -3))
            : null;

        return Inertia::render('auth/reset-password-phone', [
            'token' => $token,
            'phone' => $masked,
        ]);
    }

    public function store(Request $request): RedirectResponse
    {
        $request->validate([
            'token' => ['required', 'string'],
            'password' => ['required', 'string', 'min:6', 'confirmed'],
        ]);

        $cacheKey = ApiPasswordController::PHONE_LINK_CACHE_PREFIX.$request->token;
        $payload = Cache::get($cacheKey);

        if (!is_array($payload) || empty($payload['user_id'])) {
            return back()->withErrors([
                'token' => 'This password reset link is invalid or has expired.',
            ]);
        }

        $user = User::find($payload['user_id']);

        if (!$user) {
            return back()->withErrors([
                'token' => 'This password reset link is invalid or has expired.',
            ]);
        }

        $user->update([
            'password' => Hash::make($request->password),
        ]);

        $user->tokens()->delete();
        Cache::forget($cacheKey);

        // Link is single-use; also kill any active password-reset OTP for this phone
        if (!empty($payload['phone'])) {
            app(OtpService::class)->invalidate(
                OtpPurpose::PasswordReset,
                $payload['phone']
            );
        }

        ActivityLogger::log(
            ActivityActions::AUTH_PASSWORD_RESET,
            "Password reset completed via phone link (web) for {$user->name}",
            $user,
            [
                'endpoint' => 'reset-password/phone',
                'method' => 'phone_link',
            ],
            module: 'auth',
            userId: (int) $user->id,
        );

        return redirect()
            ->route('login')
            ->with('status', 'Password reset successfully. Please sign in with your new password.');
    }
}
