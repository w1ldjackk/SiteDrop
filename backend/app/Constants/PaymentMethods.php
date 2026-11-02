<?php
// app/Constants/PaymentMethods.php

namespace App\Constants;

/**
 * Centralized payment method constants.
 * This is the single source of truth for payment methods.
 * Dart constants in AppConstants should mirror these values.
 */
class PaymentMethods
{
    // Payment method API values (what the backend accepts)
    public const MOBILE_MONEY = 'mobile_money';
    public const CARD = 'card';
    public const BANK_TRANSFER = 'bank_transfer';
    public const WALLET = 'wallet';
    public const CASH_ON_DELIVERY = 'cash_on_delivery';
    public const CASH = 'cash';

    /**
     * All supported payment methods as API values.
     */
    public const ALL = [
        self::MOBILE_MONEY,
        self::CARD,
        self::BANK_TRANSFER,
        self::WALLET,
        self::CASH_ON_DELIVERY,
        self::CASH,
    ];

    /**
     * Display names for each payment method (user-facing).
     * Keys are API values.
     */
    public const DISPLAY_NAMES = [
        self::MOBILE_MONEY => 'Mobile Money',
        self::CARD => 'Paystack',
        self::BANK_TRANSFER => 'Bank Transfer',
        self::WALLET => 'Wallet Balance',
        self::CASH_ON_DELIVERY => 'Cash on Delivery',
        self::CASH => 'Cash',
    ];

    /**
     * Payment methods that require additional fields.
     */
    public const REQUIRES_PHONE_NUMBER = [self::MOBILE_MONEY];
    public const REQUIRES_NETWORK = [self::MOBILE_MONEY];
    public const REQUIRES_CARD_DETAILS = [self::CARD];
    public const REQUIRES_BANK_DETAILS = [self::BANK_TRANSFER];

    /**
     * Mobile Money networks (Ghana).
     */
    public const MOBILE_MONEY_NETWORKS = [
        'MTN' => 'MTN Mobile Money',
        'Vodafone' => 'Vodafone Cash',
        'AirtelTigo' => 'AirtelTigo Money',
    ];

    /**
     * Check if a payment method is valid.
     */
    public static function isValid(string $method): bool
    {
        return in_array($method, self::ALL, true);
    }

    /**
     * Get display name for a payment method.
     */
    public static function displayName(string $method): string
    {
        return self::DISPLAY_NAMES[$method] ?? $method;
    }

    /**
     * Get display names for multiple payment methods.
     */
    public static function displayNames(array $methods): array
    {
        return array_map([self::class, 'displayName'], $methods);
    }

    /**
     * Get all payment methods as array of [api_value => display_name].
     */
    public static function allAsMap(): array
    {
        return self::DISPLAY_NAMES;
    }
}