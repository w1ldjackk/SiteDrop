<?php

namespace App\Enums;

enum NotificationChannel: string
{
    use EnumHelpers;

    case Push = 'push';
    case Email = 'email';
    case Sms = 'sms';
    case InApp = 'in_app';

    public static function fromMixed(self|string $channel): self
    {
        if ($channel instanceof self) {
            return $channel;
        }

        return self::tryFrom($channel) ?? self::InApp;
    }
}
