<?php

namespace App\Enums;

enum SiteMaterialStatus: string
{
    use EnumHelpers;

    case Pending = 'pending';
    case Partial = 'partial';
    case Completed = 'completed';
}
