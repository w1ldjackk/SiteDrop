<?php

namespace App\Enums;

enum ReviewStatus: string
{
    use EnumHelpers;

    case Pending = 'pending';
    case Published = 'published';
    case Hidden = 'hidden';
    case Reported = 'reported';
}
