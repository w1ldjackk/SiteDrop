<?php

namespace App\Enums;

enum SiteVisitType: string
{
    use EnumHelpers;

    case Scheduled = 'scheduled';
    case WalkIn = 'walk-in';
    case Emergency = 'emergency';
}
