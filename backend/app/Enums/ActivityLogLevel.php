<?php

namespace App\Enums;

enum ActivityLogLevel: string
{
    use EnumHelpers;

    case Info = 'info';
    case Warning = 'warning';
    case Critical = 'critical';
}
