<?php

namespace App\Actions\Domain\Auth;

use App\Enums\OtpPurpose;
use App\Models\User;
use App\Services\Auth\OtpService;
use App\Services\Sms\SmsService;
use App\Traits\NormalizesGhanaPhone;
use Illuminate\Support\Facades\Log;
use Illuminate\Validation\ValidationException;

class SendPhoneOtpAction
{
    use NormalizesGhanaPhone;

    public function __construct(
        protected OtpService $otpService,
        protected SmsService $smsService
    ) {}

    /**
     * Send a purpose-scoped 6-digit OTP (and optional reset link) to a registered phone.
     *
     * @return string The OTP code that was sent
     */
    public function execute(
        string $phone,
        OtpPurpose|string $purpose = OtpPurpose::Verify,
        ?string $resetUrl = null,
        int $ttlMinutes = 10
    ): string {
        $purpose = OtpPurpose::fromMixed($purpose);
        $digits = preg_replace('/\D/', '', $phone) ?? '';

        if (!preg_match('/^(0|233)\d{9}$/', $digits)) {
            throw ValidationException::withMessages([
                'phone' => 'Please enter a valid Ghanaian phone number (e.g. 0202143384 or 233202143384).',
            ]);
        }

        $normalizedPhone = $this->normalizeGhanaPhone($digits);

        if (!$this->userExistsForPhone($normalizedPhone)) {
            throw ValidationException::withMessages([
                'phone' => 'No account exists with this phone number. Please register first.',
            ]);
        }

        // New issue replaces any previous active code for this purpose only.
        // Login / reset / verify codes never share a cache key.
        $otp = $this->otpService->issue($purpose, $normalizedPhone, $ttlMinutes);

        $this->sendSms($normalizedPhone, $otp, $purpose, $resetUrl);

        // Production: never log the code. Local/testing: include it so devs can
        // read OTPs from storage/logs/laravel.log until real SMS is wired.
        $payload = [
            'phone' => $this->maskPhone($normalizedPhone),
            'purpose' => $purpose->value,
            'has_reset_link' => $resetUrl !== null,
            'ttl_minutes' => $ttlMinutes,
        ];

        if ($this->shouldExposeOtpInLogs()) {
            $payload['otp'] = $otp;
            $payload['hint'] = 'SMS not configured — use this otp from laravel.log';
        }

        Log::info('OTP issued', $payload);

        return $otp;
    }

    private function userExistsForPhone(string $normalizedPhone): bool
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
            ->exists();
    }


    private function sendSms(
        string $phone,
        string $otp,
        OtpPurpose $purpose,
        ?string $resetUrl = null
    ): void {
        $label = $purpose->label();

        if ($resetUrl) {
            $message = "SiteDrop {$label} code: {$otp}. Or open this link: {$resetUrl}";
        } else {
            $message = "SiteDrop {$label} code: {$otp}";
        }

        // TODO: replace stub with real SMS provider when credentials are ready.
        // Until then, local/testing logs the full stub message (includes OTP).
        $sent = $this->smsService->send($phone, $message);

        $context = [
            'phone' => $this->maskPhone($phone),
            'purpose' => $purpose->value,
            'has_reset_link' => $resetUrl !== null,
            'message_length' => strlen($message),
            'provider' => $this->smsService->provider(),
            'sent' => $sent,
        ];

        if ($this->shouldExposeOtpInLogs()) {
            $context['otp'] = $otp;
            $context['message'] = $message;
            Log::info('SMS dispatched (dev — OTP in log)', $context);
        } else {
            Log::info('SMS dispatched', $context);
        }
    }

    /**
     * Expose OTP in logs only outside production (local, testing, staging).
     * Toggle via config/logging.php → log_otp_in_dev / LOG_OTP_IN_DEV.
     */
    private function shouldExposeOtpInLogs(): bool
    {
        return (bool) config('logging.log_otp_in_dev', ! app()->environment('production'));
    }

    private function maskPhone(string $phone): string
    {
        $digits = preg_replace('/\D/', '', $phone) ?? '';
        if (strlen($digits) < 6) {
            return '***';
        }

        return substr($digits, 0, 3).str_repeat('*', max(0, strlen($digits) - 6)).substr($digits, -3);
    }
}
