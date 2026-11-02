<?php

namespace App\Enums;

enum TripLogStatus: string
{
    use EnumHelpers;

    case Scheduled = 'scheduled';
    case InProgress = 'in_progress';
    case Completed = 'completed';
    case Cancelled = 'cancelled';
    case Delayed = 'delayed';
}
