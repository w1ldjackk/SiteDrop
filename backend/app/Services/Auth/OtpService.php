<?php

namespace App\Services\Auth;

use App\Enums\OtpPurpose;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

/**
 * Purpose-scoped, single-use OTP codes.
 *
 * Codes from one purpose cannot verify another. Successful verification
 * consumes the code immediately; consumed codes cannot be reused.
 * Each new issue replaces the previous active code for that purpose+identifier
 * and guarantees a different code value than the one just replaced.
 */
class OtpService
{
    /** @deprecated Use OtpPurpose::Login */
    public const PURPOSE_LOGIN = 'login';

    /** @deprecated Use OtpPurpose::PasswordReset */
    public const PURPOSE_PASSWORD_RESET = 'password_reset';

    /** @deprecated Use OtpPurpose::Verify */
    public const PURPOSE_VERIFY = 'verify';

    /** @deprecated Use OtpPurpose::values() */
    public const PURPOSES = [
        self::PURPOSE_LOGIN,
        self::PURPOSE_PASSWORD_RESET,
        self::PURPOSE_VERIFY,
    ];

    private const ACTIVE_PREFIX = 'otp:active:';
    private const USED_PREFIX = 'otp:used:';
    private const MAX_ATTEMPTS = 5;

    /**
     * Issue a new 6-digit OTP for the given purpose + identifier.
     * Invalidates any previous active OTP for the same purpose+identifier.
     */
    public function issue(
        OtpPurpose|string $purpose,
        string $identifier,
        int $ttlMinutes = 10
    ): string {
        $purpose = OtpPurpose::fromMixed($purpose);
        $identifier = $this->normalizeIdentifier($identifier);
        $ttlMinutes = max(1, $ttlMinutes);

        $activeKey = $this->activeKey($purpose, $identifier);
        $previous = Cache::get($activeKey);
        $previousHash = is_array($previous) ? ($previous['hash'] ?? null) : null;

        $code = $this->generateUniqueCode($purpose, $identifier, $previousHash);
        $hash = $this->hashCode($code);

        Cache::put($activeKey, [
            'hash' => $hash,
            'issued_at' => now()->timestamp,
            'attempts' => 0,
            'purpose' => $purpose->value,
        ], now()->addMinutes($ttlMinutes));

        return $code;
    }

    /**
     * Verify a code for an exact purpose. On success the code is consumed
     * (deleted) and recorded as used so it cannot be reused.
     *
     * @throws ValidationException
     */
    public function verify(
        OtpPurpose|string $purpose,
        string $identifier,
        string $code,
        bool $consume = true
    ): void {
        $purpose = OtpPurpose::fromMixed($purpose);
        $identifier = $this->normalizeIdentifier($identifier);
        $code = trim($code);

        if (! preg_match('/^\d{6}$/', $code)) {
            throw ValidationException::withMessages([
                'otp' => ['Invalid OTP. Please try again.'],
            ]);
        }

        if ($this->wasUsed($purpose, $identifier, $code)) {
            throw ValidationException::withMessages([
                'otp' => ['This code has already been used. Please request a new one.'],
            ]);
        }

        $activeKey = $this->activeKey($purpose, $identifier);
        $payload = Cache::get($activeKey);

        if (! is_array($payload) || empty($payload['hash'])) {
            throw ValidationException::withMessages([
                'otp' => ['OTP has expired. Please request a new one.'],
            ]);
        }

        $attempts = (int) ($payload['attempts'] ?? 0);
        if ($attempts >= self::MAX_ATTEMPTS) {
            Cache::forget($activeKey);
            throw ValidationException::withMessages([
                'otp' => ['Too many invalid attempts. Please request a new code.'],
            ]);
        }

        if (! Hash::check($code, $payload['hash'])) {
            $payload['attempts'] = $attempts + 1;
            Cache::put($activeKey, $payload, now()->addMinutes(10));

            throw ValidationException::withMessages([
                'otp' => ['Invalid OTP. Please try again.'],
            ]);
        }

        if ($consume) {
            $this->markUsed($purpose, $identifier, $code);
            Cache::forget($activeKey);
        }
    }

    /**
     * Try verifying against multiple purposes (e.g. login OR verify endpoints).
     * Never include password_reset here if the endpoint is not reset.
     *
     * @param  list<OtpPurpose|string>  $purposes
     * @return OtpPurpose The purpose that matched
     *
     * @throws ValidationException
     */
    public function verifyAny(
        array $purposes,
        string $identifier,
        string $code,
        bool $consume = true
    ): OtpPurpose {
        $identifier = $this->normalizeIdentifier($identifier);
        $code = trim($code);
        $sawUsed = false;
        $sawActiveMismatch = false;

        foreach ($purposes as $purpose) {
            $purpose = OtpPurpose::fromMixed($purpose);

            try {
                $this->verify($purpose, $identifier, $code, $consume);

                return $purpose;
            } catch (ValidationException $e) {
                $messages = $e->errors()['otp'] ?? [];
                $joined = strtolower(implode(' ', $messages));

                if (str_contains($joined, 'already been used')) {
                    $sawUsed = true;
                    throw $e;
                }

                if (str_contains($joined, 'invalid') || str_contains($joined, 'too many')) {
                    $sawActiveMismatch = true;
                }
            }
        }

        if ($sawUsed) {
            throw ValidationException::withMessages([
                'otp' => ['This code has already been used. Please request a new one.'],
            ]);
        }

        if ($sawActiveMismatch) {
            throw ValidationException::withMessages([
                'otp' => ['Invalid OTP. Please try again.'],
            ]);
        }

        throw ValidationException::withMessages([
            'otp' => ['OTP has expired. Please request a new one.'],
        ]);
    }

    public function invalidate(OtpPurpose|string $purpose, string $identifier): void
    {
        $purpose = OtpPurpose::fromMixed($purpose);
        $identifier = $this->normalizeIdentifier($identifier);
        Cache::forget($this->activeKey($purpose, $identifier));
    }

    public function invalidateAll(string $identifier): void
    {
        $identifier = $this->normalizeIdentifier($identifier);
        foreach (OtpPurpose::cases() as $purpose) {
            Cache::forget($this->activeKey($purpose, $identifier));
        }
    }

    public function hasActive(OtpPurpose|string $purpose, string $identifier): bool
    {
        $purpose = OtpPurpose::fromMixed($purpose);
        $identifier = $this->normalizeIdentifier($identifier);
        $payload = Cache::get($this->activeKey($purpose, $identifier));

        return is_array($payload) && ! empty($payload['hash']);
    }

    private function generateUniqueCode(
        OtpPurpose $purpose,
        string $identifier,
        ?string $previousHash
    ): string {
        for ($i = 0; $i < 25; $i++) {
            $code = (string) random_int(100000, 999999);

            if ($previousHash && Hash::check($code, $previousHash)) {
                continue;
            }

            if ($this->wasUsed($purpose, $identifier, $code)) {
                continue;
            }

            return $code;
        }

        return (string) random_int(100000, 999999);
    }

    private function markUsed(OtpPurpose $purpose, string $identifier, string $code): void
    {
        Cache::put(
            $this->usedKey($purpose, $identifier, $code),
            true,
            now()->addHours(2)
        );
    }

    private function wasUsed(OtpPurpose $purpose, string $identifier, string $code): bool
    {
        return Cache::has($this->usedKey($purpose, $identifier, $code));
    }

    private function usedKey(OtpPurpose $purpose, string $identifier, string $code): string
    {
        return self::USED_PREFIX.$purpose->value.':'.$identifier.':'.hash('sha256', $code);
    }

    private function activeKey(OtpPurpose $purpose, string $identifier): string
    {
        return self::ACTIVE_PREFIX.$purpose->value.':'.$identifier;
    }

    private function hashCode(string $code): string
    {
        return Hash::make($code);
    }

    private function normalizeIdentifier(string $identifier): string
    {
        $identifier = trim(strtolower($identifier));

        if (preg_match('/^\+?\d[\d\s\-]+$/', $identifier) || preg_match('/^\d+$/', $identifier)) {
            $digits = preg_replace('/\D/', '', $identifier) ?? '';
            if (str_starts_with($digits, '0') && strlen($digits) === 10) {
                $digits = '233'.substr($digits, 1);
            }

            return $digits;
        }

        return $identifier;
    }
}
