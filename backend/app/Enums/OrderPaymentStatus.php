<?php

namespace App\Enums;

enum OrderPaymentStatus: string
{
    use EnumHelpers;

    case Pending = 'pending';
    case Paid = 'paid';
    case Failed = 'failed';
    case Refunded = 'refunded';
    case Partial = 'partial';
}
