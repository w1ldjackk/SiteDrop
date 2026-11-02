<?php

namespace App\Enums;

enum TruckStatus: string
{
    use EnumHelpers;

    case Available = 'available';
    case InTransit = 'in_transit';
    case Maintenance = 'maintenance';
    case Inactive = 'inactive';
    case OutOfService = 'out_of_service';
}
