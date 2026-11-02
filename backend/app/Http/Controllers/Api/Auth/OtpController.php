<?php

namespace App\Http\Controllers\Api\Auth;

use App\Actions\Domain\Auth\SendPhoneOtpAction;
use App\Actions\Domain\Auth\VerifyPhoneOtpAction;
use App\Enums\OtpPurpose;
use App\Http\Controllers\Controller;
use App\Http\Requests\Api\OtpSendRequest;
use App\Http\Requests\Api\OtpVerifyRequest;
use App\Services\Activity\ActivityActions;
use App\Services\Activity\ActivityLogger;
use Illuminate\Foundation\Auth\Access\AuthorizesRequests;
use Illuminate\Http\JsonResponse;
use Illuminate\Validation\ValidationException;

class OtpController extends Controller
{
    use AuthorizesRequests;

    protected SendPhoneOtpAction $sendOtpAction;
    protected VerifyPhoneOtpAction $verifyOtpAction;

    public function __construct(
        SendPhoneOtpAction $sendOtpAction,
        VerifyPhoneOtpAction $verifyOtpAction
    ) {
        $this->sendOtpAction = $sendOtpAction;
        $this->verifyOtpAction = $verifyOtpAction;
    }

    /**
     * Send OTP for phone verification / registration resend.
     * (Login uses /auth/login-otp; password reset uses /auth/forgot-password.)
     */
    public function sendOtp(OtpSendRequest $request): JsonResponse
    {
        try {
            $this->sendOtpAction->execute(
                $request->phone,
                OtpPurpose::Verify
            );

            ActivityLogger::log(
                ActivityActions::AUTH_OTP_SENT,
                'Verification OTP sent to '.$request->phone,
                null,
                [
                    'phone' => $request->phone,
                    'purpose' => OtpPurpose::Verify->value,
                ],
                module: 'auth',
            );

            return response()->json([
                'status' => 'success',
                'message' => 'OTP sent successfully. Please check your phone.',
            ]);
        } catch (ValidationException $e) {
            return response()->json([
                'status' => 'error',
                'message' => 'Failed to send OTP',
                'errors' => $e->errors(),
            ], 422);
        }
    }

    /**
     * Verify OTP and login user.
     * Accepts login OR verify purpose codes only — never password_reset.
     * Mobile uses this for OTP login and post-register verification.
     */
    public function verifyOtp(OtpVerifyRequest $request): JsonResponse
    {
        try {
            $user = $this->verifyOtpAction->execute(
                $request->phone,
                $request->otp,
                [OtpPurpose::Login, OtpPurpose::Verify]
            );

            $token = $user->createToken('sitedrop-otp-login')->plainTextToken;

            ActivityLogger::log(
                ActivityActions::AUTH_LOGIN,
                "User {$user->name} signed in via OTP",
                $user,
                [
                    'method' => 'otp',
                    'phone' => $request->phone,
                    'endpoint' => 'auth/otp/verify',
                ],
                module: 'auth',
                userId: (int) $user->id,
            );

            return response()->json([
                'status' => 'success',
                'message' => 'Phone verified and logged in successfully',
                'user' => $user->only(['id', 'name', 'email', 'phone', 'role', 'phone_verified']),
                'token' => $token,
                'token_type' => 'Bearer',
            ]);
        } catch (ValidationException $e) {
            ActivityLogger::log(
                'auth.login_failed',
                'OTP login failed for '.$request->phone,
                null,
                [
                    'method' => 'otp',
                    'phone' => $request->phone,
                    'errors' => $e->errors(),
                ],
                level: \App\Models\ActivityLog::LEVEL_WARNING,
                module: 'auth',
            );

            return response()->json([
                'status' => 'error',
                'message' => 'OTP verification failed',
                'errors' => $e->errors(),
            ], 422);
        }
    }
}
