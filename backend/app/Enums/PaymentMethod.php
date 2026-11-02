<?php

namespace App\Enums;

enum PaymentMethod: string
{
    use EnumHelpers;

    case MobileMoney = 'mobile_money';
    case BankTransfer = 'bank_transfer';
    case Card = 'card';
    case Wallet = 'wallet';
    case Cash = 'cash';
}
