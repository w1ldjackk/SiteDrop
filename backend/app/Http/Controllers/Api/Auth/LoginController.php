<?php

namespace App\Http\Controllers\Api\Auth;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\LoginRequest;
use App\Http\Requests\Api\OtpSendRequest;
use App\Http\Requests\Api\OtpVerifyRequest;
use App\Actions\Domain\Auth\SendPhoneOtpAction;
use App\Actions\Domain\Auth\VerifyPhoneOtpAction;
use App\Enums\OtpPurpose;
use App\Models\User;
use App\Services\Activity\ActivityActions;
use App\Services\Activity\ActivityLogger;
use App\Traits\NormalizesGhanaPhone;
use Illuminate\Foundation\Auth\Access\AuthorizesRequests;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

class LoginController extends Controller
{
    use AuthorizesRequests;
    use NormalizesGhanaPhone;

    public function __construct(
        protected SendPhoneOtpAction $sendPhoneOtpAction,
        protected VerifyPhoneOtpAction $verifyOtpAction
    ) {}

    /**
     * Handle API Login (Phone or Email)
     */
    public function login(LoginRequest $request): JsonResponse
    {
        $login = $request->login;

        // === Smart phone normalization for Ghana (handles 0, missing 233, +233, etc.) ===
        $normalizedPhone = $this->normalizeGhanaPhone($login);

        $user = User::where('email', $login)
            ->orWhere('phone', $login)
            ->orWhere('phone', $normalizedPhone)
            ->first();

        if (!$user || !Hash::check($request->password, $user->password)) {
            ActivityLogger::log(
                'auth.login_failed',
                'Failed password login attempt for '.$login,
                null,
                [
                    'method' => 'password',
                    'login' => $login,
                ],
                level: \App\Models\ActivityLog::LEVEL_WARNING,
                module: 'auth',
            );

            throw ValidationException::withMessages([
                'login' => ['The provided credentials are incorrect.'],
            ]);
        }

        // Enforce phone verification (except for admins)
        if (!$user->hasVerifiedPhone() && !$user->isAdmin()) {
            ActivityLogger::log(
                'auth.login_blocked',
                "Login blocked — phone not verified for {$user->name}",
                $user,
                ['method' => 'password'],
                level: \App\Models\ActivityLog::LEVEL_WARNING,
                module: 'auth',
                userId: (int) $user->id,
            );

            return $this->error(
                'Please verify your phone number first.',
                403,
                ['requires_verification' => true],
            );
        }

        // Create Sanctum Token
        $token = $user->createToken(
            'sitedrop-auth-token',
            ['*'],
            $request->boolean('remember') ? now()->addDays(30) : now()->addDays(7)
        )->plainTextToken;

        ActivityLogger::log(
            ActivityActions::AUTH_LOGIN,
            "User {$user->name} signed in",
            $user,
            [
                'method' => 'password',
                'remember' => $request->boolean('remember'),
                'endpoint' => 'auth/login',
            ],
            module: 'auth',
            userId: (int) $user->id,
        );

        return $this->success(
            extra: [
                'user' => $user->only(['id', 'name', 'email', 'phone', 'role', 'phone_verified']),
                'token' => $token,
                'token_type' => 'Bearer',
            ],
        );
    }

    /**
     * Login with OTP only (phone required)
     * Sends OTP if user exists, then verifies
     */
    public function loginOtp(OtpSendRequest $request): JsonResponse
    {
        $phone = $request->phone;

        $normalizedPhone = $this->normalizeGhanaPhone($phone);

        $user = User::where('phone', $normalizedPhone)->first();

        if (!$user) {
            throw ValidationException::withMessages([
                'phone' => 'No account exists with this phone number. Please register first.',
            ]);
        }

        // Login-scoped OTP (cannot be used for password reset)
        $this->sendPhoneOtpAction->execute(
            $phone,
            OtpPurpose::Login
        );

        ActivityLogger::log(
            ActivityActions::AUTH_OTP_SENT,
            "Login OTP sent to {$normalizedPhone}",
            $user,
            [
                'method' => 'otp',
                'phone' => $normalizedPhone,
                'endpoint' => 'auth/login-otp',
            ],
            module: 'auth',
            userId: (int) $user->id,
        );

        return $this->success(
            message: 'OTP sent successfully. Please check your phone.',
            extra: [
                'requires_verification' => true,
                'next_step' => 'otp',
            ],
        );
    }

    /**
     * Verify OTP and login user (new method)
     */
    public function verifyOtp(OtpVerifyRequest $request): JsonResponse
    {
        try {
            $user = $this->verifyOtpAction->execute(
                $request->phone,
                $request->otp,
                OtpPurpose::Login
            );

            $token = $user->createToken('sitedrop-otp-login')->plainTextToken;

            ActivityLogger::log(
                ActivityActions::AUTH_LOGIN,
                "User {$user->name} signed in via OTP",
                $user,
                [
                    'method' => 'otp',
                    'endpoint' => 'auth/login/verifyOtp',
                ],
                module: 'auth',
                userId: (int) $user->id,
            );

            return $this->success(
                message: 'Phone verified and logged in successfully',
                extra: [
                    'user' => $user->only(['id', 'name', 'email', 'phone', 'role', 'phone_verified']),
                    'token' => $token,
                    'token_type' => 'Bearer',
                ],
            );
        } catch (ValidationException $e) {
            return $this->error(
                'OTP verification failed',
                422,
                ['errors' => $e->errors()],
            );
        }
    }

    /**
     * Logout - Revoke current token
     */
    public function logout(Request $request): JsonResponse
    {
        $user = $request->user();

        ActivityLogger::log(
            ActivityActions::AUTH_LOGOUT,
            "User {$user->name} signed out",
            $user,
            ['endpoint' => 'auth/logout'],
            module: 'auth',
            userId: (int) $user->id,
        );

        $user->currentAccessToken()->delete();

        return $this->success(message: 'Logged out successfully');
    }
}
