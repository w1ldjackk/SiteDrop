<?php

namespace App\Enums;

enum TruckDocumentStatus: string
{
    use EnumHelpers;

    case Pending = 'pending';
    case Active = 'active';
    case Expired = 'expired';
    case Rejected = 'rejected';
}
