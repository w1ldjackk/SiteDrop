<?php

namespace App\Enums;

enum SiteStatus: string
{
    use EnumHelpers;

    case Active = 'active';
    case Inactive = 'inactive';
    case Completed = 'completed';
    case Planning = 'planning';
    case OnHold = 'on_hold';
    case Cancelled = 'cancelled';
}
