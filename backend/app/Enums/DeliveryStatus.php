<?php

namespace App\Enums;

enum DeliveryStatus: string
{
    use EnumHelpers;

    case Pending = 'pending';
    case Assigned = 'assigned';
    case Accepted = 'accepted';
    case PickedUp = 'picked_up';
    case InTransit = 'in_transit';
    case Arrived = 'arrived';
    case Completed = 'completed';
    case Failed = 'failed';
    case Returned = 'returned';
}
