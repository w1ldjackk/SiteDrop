<?php

namespace App\Enums;

enum VehicleType: string
{
    use EnumHelpers;

    case Tipper = 'tipper';
    case Flatbed = 'flatbed';
    case Tanker = 'tanker';
    case DumpTruck = 'dump_truck';
    case ConcreteMixer = 'concrete_mixer';
    case Carrier = 'carrier';
}
