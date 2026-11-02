<?php
// app/Http/Controllers/Api/Auth/PasswordController.php

namespace App\Http\Controllers\Api\Auth;

use App\Actions\Domain\Auth\SendPhoneOtpAction;
use App\Actions\Domain\Auth\VerifyPhoneOtpAction;
use App\Enums\OtpPurpose;
use App\Http\Controllers\Controller;
use App\Models\User;
use App\Services\Notification\PasswordResetWithCode;
use App\Traits\NormalizesGhanaPhone;
use App\Services\Activity\ActivityActions;
use App\Services\Activity\ActivityLogger;
use App\Services\Auth\OtpService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Password;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class PasswordController extends Controller
{
    use NormalizesGhanaPhone;

    public const PHONE_LINK_CACHE_PREFIX = 'password_reset_phone_link:';

    public function __construct(
        protected SendPhoneOtpAction $sendPhoneOtpAction,
        protected VerifyPhoneOtpAction $verifyOtpAction,
        protected OtpService $otpService,
    ) {}

    /**
     * Forgot password via email (link + code) OR phone (link + code).
     */
    public function forgotPassword(Request $request): JsonResponse
    {
        $hasEmail = $request->filled('email');
        $hasPhone = $request->filled('phone');

        if (!$hasEmail && !$hasPhone) {
            throw ValidationException::withMessages([
                'email' => ['Provide either an email address or a phone number.'],
                'phone' => ['Provide either an email address or a phone number.'],
            ]);
        }

        if ($hasEmail && $hasPhone) {
            throw ValidationException::withMessages([
                'email' => ['Provide either email or phone, not both.'],
            ]);
        }

        if ($hasEmail) {
            return $this->forgotViaEmail($request);
        }

        return $this->forgotViaPhone($request);
    }

    /**
     * Email: web reset link + purpose-scoped 6-digit code (enter in app).
     */
    private function forgotViaEmail(Request $request): JsonResponse
    {
        $request->validate([
            'email' => ['required', 'email', 'max:255'],
        ]);

        $email = strtolower(trim((string) $request->email));
        $user = User::whereRaw('LOWER(email) = ?', [$email])->first();

        if (!$user) {
            throw ValidationException::withMessages([
                'email' => ['No account found with this email address.'],
            ]);
        }

        $expireMinutes = $this->expireMinutes();

        $token = Password::broker()->createToken($user);

        // Purpose-scoped, single-use, unique-per-issue code
        $code = $this->otpService->issue(
            OtpPurpose::PasswordReset,
            $email,
            $expireMinutes
        );

        $user->notify(new PasswordResetWithCode($token, $code));

        Log::info('Password reset email dispatched', [
            'email' => $email,
            'purpose' => OtpPurpose::PasswordReset->value,
            'code' => $code,
            'expires_minutes' => $expireMinutes,
        ]);

        ActivityLogger::log(
            ActivityActions::AUTH_PASSWORD_FORGOT,
            "Password reset link+code requested for {$user->email}",
            $user,
            [
                'email' => $user->email,
                'method' => 'email',
                'purpose' => OtpPurpose::PasswordReset->value,
                'endpoint' => 'auth/forgot-password',
            ],
            module: 'auth',
            userId: (int) $user->id,
        );

        return response()->json([
            'status' => 'success',
            'message' => 'We sent a reset link and a 6-digit code to your email. Use either one.',
            'next_step' => 'code',
            'method' => 'email',
        ]);
    }

    /**
     * Phone: SMS with password_reset purpose code + reset link.
     */
    private function forgotViaPhone(Request $request): JsonResponse
    {
        $request->validate([
            'phone' => ['required', 'string', 'regex:/^(\+?233|0)?[0-9]{9,10}$/'],
        ]);

        $phone = $request->phone;
        $normalizedPhone = $this->normalizeGhanaPhone($phone);
        $user = $this->findUserByPhone($normalizedPhone);

        if (!$user) {
            throw ValidationException::withMessages([
                'phone' => ['No account found with this phone number.'],
            ]);
        }

        $expireMinutes = $this->expireMinutes();

        $linkToken = Str::random(64);
        Cache::put(
            self::PHONE_LINK_CACHE_PREFIX.$linkToken,
            [
                'user_id' => (int) $user->id,
                'phone' => $normalizedPhone,
            ],
            now()->addMinutes($expireMinutes)
        );

        $resetUrl = url('/reset-password/phone/'.$linkToken);

        // Password-reset purpose only — not valid for login
        $this->sendPhoneOtpAction->execute(
            $phone,
            OtpPurpose::PasswordReset,
            $resetUrl,
            $expireMinutes
        );

        ActivityLogger::log(
            ActivityActions::AUTH_PASSWORD_FORGOT,
            "Password reset link+code requested for {$normalizedPhone}",
            $user,
            [
                'phone' => $normalizedPhone,
                'method' => 'phone',
                'purpose' => OtpPurpose::PasswordReset->value,
                'endpoint' => 'auth/forgot-password',
            ],
            module: 'auth',
            userId: (int) $user->id,
        );

        return response()->json([
            'status' => 'success',
            'message' => 'We sent a reset link and a 6-digit code to your phone. Use either one.',
            'next_step' => 'code',
            'method' => 'phone',
        ]);
    }

    /**
     * Reset password.
     *
     * Modes:
     *  - email + otp + password   (email password_reset code)
     *  - phone + otp + password   (phone password_reset code)
     *  - token + password         (phone SMS link token)
     */
    public function resetPassword(Request $request): JsonResponse
    {
        if (!$request->filled('otp') && $request->filled('code')) {
            $request->merge(['otp' => $request->input('code')]);
        }

        if ($request->filled('token') && !$request->filled('email') && !$request->filled('phone')) {
            return $this->resetViaPhoneLinkToken($request);
        }

        $hasEmail = $request->filled('email');
        $hasPhone = $request->filled('phone');

        if (!$hasEmail && !$hasPhone) {
            throw ValidationException::withMessages([
                'email' => ['Provide email, phone, or a reset token.'],
                'phone' => ['Provide email, phone, or a reset token.'],
            ]);
        }

        if ($hasEmail && $hasPhone) {
            throw ValidationException::withMessages([
                'email' => ['Provide either email or phone, not both.'],
            ]);
        }

        if ($hasEmail) {
            return $this->resetViaEmailCode($request);
        }

        return $this->resetViaPhoneOtp($request);
    }

    private function resetViaEmailCode(Request $request): JsonResponse
    {
        $request->validate([
            'email' => ['required', 'email', 'max:255'],
            'otp' => ['required', 'string', 'size:6'],
            'password' => ['required', 'string', 'min:6', 'confirmed'],
            'password_confirmation' => ['required', 'string', 'min:6'],
        ]);

        $email = strtolower(trim((string) $request->email));

        // Consumes code (single-use); wrong purpose / login codes fail here
        $this->otpService->verify(
            OtpPurpose::PasswordReset,
            $email,
            $request->otp,
            consume: true
        );

        $user = User::whereRaw('LOWER(email) = ?', [$email])->first();

        if (!$user) {
            throw ValidationException::withMessages([
                'email' => ['No account found with this email address.'],
            ]);
        }

        $this->applyNewPassword($user, $request->password);
        Password::broker()->deleteToken($user);

        ActivityLogger::log(
            ActivityActions::AUTH_PASSWORD_RESET,
            "Password reset completed via email code for {$user->name}",
            $user,
            [
                'endpoint' => 'auth/reset-password',
                'method' => 'email',
                'email' => $email,
            ],
            module: 'auth',
            userId: (int) $user->id,
        );

        return response()->json([
            'status' => 'success',
            'message' => 'Password reset successfully. Please login with your new password.',
        ]);
    }

    private function resetViaPhoneOtp(Request $request): JsonResponse
    {
        $request->validate([
            'phone' => ['required', 'string', 'regex:/^(\+?233|0)?[0-9]{9,10}$/'],
            'otp' => ['required', 'string', 'size:6'],
            'password' => ['required', 'string', 'min:6', 'confirmed'],
            'password_confirmation' => ['required', 'string', 'min:6'],
        ]);

        try {
            $phone = $request->phone;
            $normalizedPhone = $this->normalizeGhanaPhone($phone);

            // Only password_reset purpose — login OTP will not work here
            $user = $this->verifyOtpAction->execute(
                $phone,
                $request->otp,
                OtpPurpose::PasswordReset,
                markVerified: false
            );

            $this->applyNewPassword($user, $request->password);

            ActivityLogger::log(
                ActivityActions::AUTH_PASSWORD_RESET,
                "Password reset completed via phone code for {$user->name}",
                $user,
                [
                    'endpoint' => 'auth/reset-password',
                    'method' => 'phone',
                    'phone' => $normalizedPhone,
                ],
                module: 'auth',
                userId: (int) $user->id,
            );

            return response()->json([
                'status' => 'success',
                'message' => 'Password reset successfully. Please login with your new password.',
            ]);
        } catch (ValidationException $e) {
            return response()->json([
                'status' => 'error',
                'message' => 'OTP verification failed',
                'errors' => $e->errors(),
            ], 422);
        }
    }

    private function resetViaPhoneLinkToken(Request $request): JsonResponse
    {
        $request->validate([
            'token' => ['required', 'string'],
            'password' => ['required', 'string', 'min:6', 'confirmed'],
            'password_confirmation' => ['required', 'string', 'min:6'],
        ]);

        $cacheKey = self::PHONE_LINK_CACHE_PREFIX.$request->token;
        $payload = Cache::get($cacheKey);

        if (!is_array($payload) || empty($payload['user_id'])) {
            throw ValidationException::withMessages([
                'token' => ['Invalid or expired reset link. Please request a new one.'],
            ]);
        }

        $user = User::find($payload['user_id']);

        if (!$user) {
            throw ValidationException::withMessages([
                'token' => ['Invalid or expired reset link. Please request a new one.'],
            ]);
        }

        $this->applyNewPassword($user, $request->password);

        // Link is single-use
        Cache::forget($cacheKey);

        // Invalidate matching password-reset OTP so it cannot be reused after link reset
        if (!empty($payload['phone'])) {
            $this->otpService->invalidate(
                OtpPurpose::PasswordReset,
                $payload['phone']
            );
        }

        ActivityLogger::log(
            ActivityActions::AUTH_PASSWORD_RESET,
            "Password reset completed via phone link for {$user->name}",
            $user,
            [
                'endpoint' => 'auth/reset-password',
                'method' => 'phone_link',
            ],
            module: 'auth',
            userId: (int) $user->id,
        );

        return response()->json([
            'status' => 'success',
            'message' => 'Password reset successfully. Please login with your new password.',
        ]);
    }

    private function applyNewPassword(User $user, string $password): void
    {
        $user->update([
            'password' => Hash::make($password),
        ]);

        $user->tokens()->delete();
    }

    private function findUserByPhone(string $normalizedPhone): ?User
    {
        $local = str_starts_with($normalizedPhone, '233')
            ? '0'.substr($normalizedPhone, 3)
            : $normalizedPhone;

        return User::query()
            ->where(function ($q) use ($normalizedPhone, $local) {
                $q->where('phone', $normalizedPhone)
                    ->orWhere('phone', $local)
                    ->orWhere('phone', '+'.$normalizedPhone);
            })
            ->first();
    }

    private function expireMinutes(): int
    {
        return (int) config(
            'auth.passwords.'.config('auth.defaults.passwords').'.expire',
            60
        );
    }

}
