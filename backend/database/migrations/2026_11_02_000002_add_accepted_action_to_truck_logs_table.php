<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Delivery::acceptByDriver() writes a "accepted" fleet-history row, but the
 * original truck_logs.action enum never included it. MySQL truncated the
 * value and the surrounding delivery update rolled back with a 500.
 *
 * Widen the enum for already-migrated MySQL databases. ("started" is not
 * added: Delivery::markAsInTransit() now uses the existing "trip_started"
 * value instead.)
 */
return new class extends Migration
{
    private const ACTIONS = [
        'created',
        'updated',
        'status_changed',
        'maintenance',
        'insurance',
        'document',
        'accepted',
        'trip_started',
        'trip_ended',
        'location_updated',
        'deleted',
    ];

    public function up(): void
    {
        if (! Schema::hasTable('truck_logs') || DB::getDriverName() !== 'mysql') {
            return;
        }

        $values = implode(',', array_map(fn (string $action) => "'{$action}'", self::ACTIONS));

        DB::statement(
            "ALTER TABLE `truck_logs` MODIFY `action` ENUM({$values}) NOT NULL"
        );
    }

    public function down(): void
    {
        if (! Schema::hasTable('truck_logs') || DB::getDriverName() !== 'mysql') {
            return;
        }

        DB::table('truck_logs')
            ->where('action', 'accepted')
            ->update(['action' => 'updated']);

        $values = implode(',', array_map(
            fn (string $action) => "'{$action}'",
            array_values(array_diff(self::ACTIONS, ['accepted']))
        ));

        DB::statement(
            "ALTER TABLE `truck_logs` MODIFY `action` ENUM({$values}) NOT NULL"
        );
    }
};
