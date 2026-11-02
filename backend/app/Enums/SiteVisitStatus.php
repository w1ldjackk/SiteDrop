<?php

namespace App\Enums;

enum SiteVisitStatus: string
{
    use EnumHelpers;

    case Scheduled = 'scheduled';
    case CheckedIn = 'checked_in';
    case InProgress = 'in_progress';
    case Completed = 'completed';
    case Cancelled = 'cancelled';
    case Rejected = 'rejected';
}
