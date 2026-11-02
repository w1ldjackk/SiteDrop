<?php

namespace App\Enums;

enum NotificationType: string
{
    use EnumHelpers;

    case Order = 'order';
    case Payment = 'payment';
    case Delivery = 'delivery';
    case System = 'system';
    case Promotion = 'promotion';
    case Site = 'site';
    case Truck = 'truck';
    case Review = 'review';
    case Message = 'message';

    public static function fromMixed(self|string $type): self
    {
        if ($type instanceof self) {
            return $type;
        }

        return self::tryFrom($type) ?? self::System;
    }
}
