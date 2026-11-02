<?php

namespace App\Enums;

enum WalletTransactionCategory: string
{
    use EnumHelpers;

    case Deposit = 'deposit';
    case Withdrawal = 'withdrawal';
    case Payment = 'payment';
    case Refund = 'refund';
    case Adjustment = 'adjustment';
    case Commission = 'commission';
    case Earning = 'earning';
    case Transfer = 'transfer';
    case Hold = 'hold';
    case Release = 'release';

    public function label(): string
    {
        return match ($this) {
            self::Deposit => 'Deposit',
            self::Withdrawal => 'Withdrawal',
            self::Payment => 'Payment',
            self::Refund => 'Refund',
            self::Adjustment => 'Adjustment',
            self::Commission => 'Commission',
            self::Earning => 'Earning',
            self::Transfer => 'Transfer',
            self::Hold => 'Hold',
            self::Release => 'Release',
        };
    }
}
