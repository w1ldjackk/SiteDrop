<?php

namespace App\Enums;

enum NotificationPriority: string
{
    use EnumHelpers;

    case High = 'high';
    case Normal = 'normal';
    case Low = 'low';

    public static function fromMixed(self|string $priority): self
    {
        if ($priority instanceof self) {
            return $priority;
        }

        return self::tryFrom($priority) ?? self::Normal;
    }
}
