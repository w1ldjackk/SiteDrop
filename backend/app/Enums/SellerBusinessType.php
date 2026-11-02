<?php

namespace App\Enums;

enum SellerBusinessType: string
{
    use EnumHelpers;

    case Quarry = 'quarry';
    case TruckOwner = 'truck_owner';
    case Supplier = 'supplier';
    case Distributor = 'distributor';
    case Retailer = 'retailer';
    case Manufacturer = 'manufacturer';
}
