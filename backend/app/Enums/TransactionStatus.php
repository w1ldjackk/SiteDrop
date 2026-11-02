<?php

namespace App\Enums;

enum TransactionStatus: string
{
    use EnumHelpers;

    case Pending = 'pending';
    case Processing = 'processing';
    case Completed = 'completed';
    case Failed = 'failed';
    case Cancelled = 'cancelled';
}
