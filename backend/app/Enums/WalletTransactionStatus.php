<?php

namespace App\Enums;

enum WalletTransactionStatus: string
{
    use EnumHelpers;

    case Pending = 'pending';
    case Completed = 'completed';
    case Failed = 'failed';
    case Rejected = 'rejected';
    case Cancelled = 'cancelled';

    public function label(): string
    {
        return match ($this) {
            self::Pending => 'Pending',
            self::Completed => 'Completed',
            self::Failed => 'Failed',
            self::Rejected => 'Rejected',
            self::Cancelled => 'Cancelled',
        };
    }
}
