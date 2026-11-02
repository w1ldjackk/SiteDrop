<?php

namespace App\Actions\Domain\Auth;

use App\Enums\OtpPurpose;
use App\Models\User;
use App\Services\Auth\OtpService;
use App\Traits\NormalizesGhanaPhone;
use Illuminate\Validation\ValidationException;

class VerifyPhoneOtpAction
{
    use NormalizesGhanaPhone;

    public function __construct(
        protected OtpService $otpService
    ) {}

    /**
     * Verify a purpose-scoped OTP and return the matching user.
     *
     * @param  OtpPurpose|string|list<OtpPurpose|string>  $purpose  Single purpose or list (e.g. login|verify)
     */
    public function execute(
        string $phone,
        string $otp,
        OtpPurpose|string|array $purpose = OtpPurpose::Login,
        bool $markVerified = true
    ): User {
        $normalizedPhone = $this->normalizeGhanaPhone($phone);

        if (is_array($purpose)) {
            $this->otpService->verifyAny($purpose, $normalizedPhone, $otp, consume: true);
        } else {
            $this->otpService->verify($purpose, $normalizedPhone, $otp, consume: true);
        }

        $user = $this->findUser($normalizedPhone);

        if (!$user) {
            throw ValidationException::withMessages([
                'user' => 'User not found for this phone number.',
            ]);
        }

        if ($markVerified && method_exists($user, 'markPhoneAsVerified')) {
            $user->markPhoneAsVerified();
        }

        return $user;
    }

    private function findUser(string $normalizedPhone): ?User
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

}
