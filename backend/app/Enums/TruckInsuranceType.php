<?php

namespace App\Enums;

enum TruckInsuranceType: string
{
    use EnumHelpers;

    case Comprehensive = 'comprehensive';
    case ThirdParty = 'third_party';
    case MotorAccident = 'motor_accident';
    case FireTheft = 'fire_theft';
    case PublicLiability = 'public_liability';
    case GoodsTransit = 'goods_transit';
    case Other = 'other';
}
