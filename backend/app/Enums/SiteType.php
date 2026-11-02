<?php

namespace App\Enums;

enum SiteType: string
{
    use EnumHelpers;

    case Construction = 'construction';
    case Quarry = 'quarry';
    case Warehouse = 'warehouse';
    case Supplier = 'supplier';
    case Other = 'other';
}
