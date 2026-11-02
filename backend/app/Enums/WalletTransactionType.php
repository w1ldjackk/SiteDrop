<?php

namespace App\Enums;

enum WalletTransactionType: string
{
    use EnumHelpers;

    case Credit = 'credit';
    case Debit = 'debit';
    case Blocked = 'blocked';
    case Unblocked = 'unblocked';

    public function label(): string
    {
        return match ($this) {
            self::Credit => 'Credit',
            self::Debit => 'Debit',
            self::Blocked => 'Blocked',
            self::Unblocked => 'Unblocked',
        };
    }
}
