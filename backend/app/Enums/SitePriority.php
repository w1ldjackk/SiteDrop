<?php

namespace App\Enums;

enum SitePriority: string
{
    use EnumHelpers;

    case High = 'high';
    case Medium = 'medium';
    case Low = 'low';
}
