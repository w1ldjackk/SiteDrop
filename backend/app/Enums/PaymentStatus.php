<?php

namespace App\Enums;

enum PaymentStatus: string
{
    use EnumHelpers;

    case Pending = 'pending';
    case Success = 'success';
    case Failed = 'failed';
    case Refunded = 'refunded';
    case Cancelled = 'cancelled';
}
