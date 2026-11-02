<?php

namespace App\Enums;

/**
 * Purpose-scoped OTP codes. Codes from one purpose cannot verify another.
 */
enum OtpPurpose: string
{
    use EnumHelpers;

    case Login = 'login';
    case PasswordReset = 'password_reset';
    case Verify = 'verify';

    public function label(): string
    {
        return match ($this) {
            self::Login => 'login',
            self::PasswordReset => 'password reset',
            self::Verify => 'verification',
        };
    }
}
