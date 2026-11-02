<?php

namespace App\Traits;

/**
 * Normalize Ghana mobile numbers to local storage form: 233XXXXXXXXX
 * (handles +, 0-prefix, bare 9-digit, and already-normalized 233…).
 */
trait NormalizesGhanaPhone
{
    protected function normalizeGhanaPhone(string $phone): string
    {
        $phone = trim($phone);

        if (str_starts_with($phone, '+')) {
            $phone = substr($phone, 1);
        }

        $phone = preg_replace('/\D/', '', $phone) ?? '';

        if (str_starts_with($phone, '233')) {
            return $phone;
        }

        // 0XXXXXXXXX (10 digits)
        if (strlen($phone) === 10 && str_starts_with($phone, '0')) {
            return '233'.substr($phone, 1);
        }

        // XXXXXXXXX (9 digits, no leading 0)
        if (strlen($phone) === 9) {
            return '233'.$phone;
        }

        // 10 digits without leading 0 → treat as national without 0
        if (strlen($phone) === 10 && ! str_starts_with($phone, '0')) {
            return '233'.$phone;
        }

        return $phone;
    }
}
