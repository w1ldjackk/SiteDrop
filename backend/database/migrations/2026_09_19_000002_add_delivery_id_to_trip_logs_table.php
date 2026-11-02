<?php
// database/migrations/2026_09_19_000002_add_delivery_id_to_trip_logs_table.php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('trip_logs')) {
            return;
        }

        Schema::table('trip_logs', function (Blueprint $table) {
            if (! Schema::hasColumn('trip_logs', 'delivery_id')) {
                $table->foreignId('delivery_id')->nullable()->after('order_id')->constrained('deliveries')->nullOnDelete();
                $table->index(['delivery_id', 'status']);
            }
        });
    }

    public function down(): void
    {
        if (! Schema::hasTable('trip_logs')) {
            return;
        }

        Schema::table('trip_logs', function (Blueprint $table) {
            if (Schema::hasColumn('trip_logs', 'delivery_id')) {
                $table->dropConstrainedForeignId('delivery_id');
            }
        });
    }
};
