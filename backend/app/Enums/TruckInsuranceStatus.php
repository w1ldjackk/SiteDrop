<?php

namespace App\Enums;

enum TruckInsuranceStatus: string
{
    use EnumHelpers;

    case Active = 'active';
    case Expired = 'expired';
    case Cancelled = 'cancelled';
    case Pending = 'pending';
    case Suspended = 'suspended';
}
