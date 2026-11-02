<?php

namespace App\Enums;

enum ReviewType: string
{
    use EnumHelpers;

    case BuyerToSeller = 'buyer_to_seller';
    case BuyerToProduct = 'buyer_to_product';
    case SellerToBuyer = 'seller_to_buyer';
}
