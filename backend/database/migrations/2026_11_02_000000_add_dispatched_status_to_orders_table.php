<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * DeliveryService::acceptOffer() moves orders to "dispatched", but the
 * original orders.status enum never included it. Widen the enum so MySQL
 * deployments (already migrated before the create migration was corrected)
 * accept the value too.
 */
return new class extends Migration
{
    private const STATUSES = [
        'pending',
        'confirmed',
        'processing',
        'ready_for_delivery',
        'dispatched',
        'in_transit',
        'delivered',
        'completed',
        'cancelled',
        'refunded',
    ];

    public function up(): void
    {
        if (! Schema::hasTable('orders') || DB::getDriverName() !== 'mysql') {
            return;
        }

        $values = implode(',', array_map(fn (string $status) => "'{$status}'", self::STATUSES));

        DB::statement(
            "ALTER TABLE `orders` MODIFY `status` ENUM({$values}) NOT NULL DEFAULT 'pending'"
        );
    }

    public function down(): void
    {
        if (! Schema::hasTable('orders') || DB::getDriverName() !== 'mysql') {
            return;
        }

        DB::table('orders')
            ->where('status', 'dispatched')
            ->update(['status' => 'in_transit']);

        $values = implode(',', array_map(
            fn (string $status) => "'{$status}'",
            array_values(array_diff(self::STATUSES, ['dispatched']))
        ));

        DB::statement(
            "ALTER TABLE `orders` MODIFY `status` ENUM({$values}) NOT NULL DEFAULT 'pending'"
        );
    }
};
