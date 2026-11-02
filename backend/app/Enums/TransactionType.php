<?php

namespace App\Enums;

enum TransactionType: string
{
    use EnumHelpers;

    case Payment = 'payment';
    case Refund = 'refund';
    case Withdrawal = 'withdrawal';
    case Deposit = 'deposit';
    case Fee = 'fee';
}
