<?php

namespace App\Enums;

enum NotificationDeliveryStatus: string
{
    use EnumHelpers;

    case Pending = 'pending';
    case Sent = 'sent';
    case Delivered = 'delivered';
    case Failed = 'failed';

    public static function fromMixed(self|string $status): self
    {
        if ($status instanceof self) {
            return $status;
        }

        return self::tryFrom($status) ?? self::Pending;
    }
}
