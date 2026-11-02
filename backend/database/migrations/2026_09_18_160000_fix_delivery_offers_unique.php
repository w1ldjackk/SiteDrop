<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Fix delivery_offers unique key.
 *
 * unique(delivery_id, driver_id, status) breaks the multi-round offer
 * lifecycle: when a driver is re-offered (round 2) after round 1 went to
 * `expired`/`declined`, resolving round 2 to the same terminal status
 * violates the key (e.g. duplicate '11-6-expired' on the lazy-expiry
 * bulk update). Offers are append-only history — first-accept-wins is
 * enforced in DeliveryService (live-offer check + row locks), so the
 * unique key is replaced with a plain composite index.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('delivery_offers', function (Blueprint $table) {
            $table->dropUnique('delivery_driver_status_unique');
        });

        Schema::table('delivery_offers', function (Blueprint $table) {
            $table->index(
                ['delivery_id', 'driver_id', 'status'],
                'delivery_offers_delivery_driver_status_index'
            );
        });
    }

    public function down(): void
    {
        Schema::table('delivery_offers', function (Blueprint $table) {
            $table->dropIndex('delivery_offers_delivery_driver_status_index');
        });

        Schema::table('delivery_offers', function (Blueprint $table) {
            // Best-effort: fails if multi-round history rows exist.
            $table->unique(
                ['delivery_id', 'driver_id', 'status'],
                'delivery_driver_status_unique'
            );
        });
    }
};
