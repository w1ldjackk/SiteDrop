<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * The buyer app sends "cash_on_delivery" (see AppConstants.paymentMethodApiMap)
 * and CheckoutRequest/CheckoutService accept it, but the original orders and
 * payments enums only allowed "cash". MySQL silently truncated the value,
 * which surfaced as a generic 422 on POST /checkout/place-order.
 *
 * Widen both enums so Cash on Delivery checkout works on already-migrated
 * MySQL databases.
 */
return new class extends Migration
{
    private const METHODS = [
        'mobile_money',
        'bank_transfer',
        'card',
        'wallet',
        'cash',
        'cash_on_delivery',
    ];

    public function up(): void
    {
        if (DB::getDriverName() !== 'mysql') {
            return;
        }

        $values = implode(',', array_map(fn (string $method) => "'{$method}'", self::METHODS));

        if (Schema::hasTable('orders')) {
            DB::statement(
                "ALTER TABLE `orders` MODIFY `payment_method` ENUM({$values}) NULL"
            );
        }

        if (Schema::hasTable('payments')) {
            DB::statement(
                "ALTER TABLE `payments` MODIFY `payment_method` ENUM({$values}) NOT NULL"
            );
        }
    }

    public function down(): void
    {
        if (DB::getDriverName() !== 'mysql') {
            return;
        }

        $values = implode(',', array_map(
            fn (string $method) => "'{$method}'",
            array_values(array_diff(self::METHODS, ['cash_on_delivery']))
        ));

        if (Schema::hasTable('orders')) {
            DB::table('orders')
                ->where('payment_method', 'cash_on_delivery')
                ->update(['payment_method' => 'cash']);

            DB::statement(
                "ALTER TABLE `orders` MODIFY `payment_method` ENUM({$values}) NULL"
            );
        }

        if (Schema::hasTable('payments')) {
            DB::table('payments')
                ->where('payment_method', 'cash_on_delivery')
                ->update(['payment_method' => 'cash']);

            DB::statement(
                "ALTER TABLE `payments` MODIFY `payment_method` ENUM({$values}) NOT NULL"
            );
        }
    }
};
