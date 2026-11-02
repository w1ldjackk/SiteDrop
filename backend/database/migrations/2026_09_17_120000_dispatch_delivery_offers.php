<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * SiteDrop-style dispatch: fix deliveries status enum (pending/accepted were
 * missing at DB level), add delivery_offers for broadcast first-accept-wins,
 * and driver presence (is_online + last_location) for offer targeting.
 */
return new class extends Migration
{
    public function up(): void
    {
        // 1) deliveries.status must accept the full DeliveryStatus enum.
        if (DB::getDriverName() === 'mysql') {
            DB::statement(
                "ALTER TABLE `deliveries` MODIFY `status` ENUM(" .
                "'pending','assigned','accepted','picked_up','in_transit'," .
                "'arrived','completed','failed','returned'" .
                ") NOT NULL DEFAULT 'pending'"
            );
        }

        // 2) Broadcast offers: one row per driver, first-accept wins.
        Schema::create('delivery_offers', function (Blueprint $table) {
            $table->id();
            $table->foreignId('delivery_id')->constrained()->onDelete('cascade');
            $table->foreignId('driver_id')->constrained('users')->onDelete('cascade');
            $table->enum('status', ['offered', 'accepted', 'declined', 'expired'])
                ->default('offered');
            $table->timestamp('expires_at');
            $table->timestamp('responded_at')->nullable();
            $table->timestamps();

            $table->unique(['delivery_id', 'driver_id', 'status'], 'delivery_driver_status_unique');
            $table->index(['driver_id', 'status']);
            $table->index(['delivery_id', 'status']);
            $table->index('expires_at');
        });

        // 3) Driver presence for offer targeting.
        Schema::table('users', function (Blueprint $table) {
            $table->boolean('is_online')->default(false)->after('remember_token');
            $table->json('last_location')->nullable()->after('is_online');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('delivery_offers');

        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn(['is_online', 'last_location']);
        });

        if (DB::getDriverName() === 'mysql') {
            DB::statement(
                "ALTER TABLE `deliveries` MODIFY `status` ENUM(" .
                "'assigned','picked_up','in_transit','arrived'," .
                "'completed','failed','returned'" .
                ") NOT NULL DEFAULT 'assigned'"
            );
        }
    }
};
