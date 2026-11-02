<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     *
     * The original products.unit enum is too narrow for a building-materials
     * marketplace (seeders + real catalog need sheet/meter/bucket). Widens it.
     * Uses a raw MODIFY COLUMN so no doctrine/dbal dependency is needed.
     */
    public function up(): void
    {
        if (! Schema::hasTable('products') || ! Schema::hasColumn('products', 'unit')) {
            return;
        }

        if (DB::getDriverName() !== 'mysql') {
            return;
        }

        DB::statement(
            "ALTER TABLE `products` MODIFY COLUMN `unit` " .
            "ENUM('ton','bag','cubic_meter','truck','piece','block','sheet','meter','bucket') NOT NULL"
        );
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        if (! Schema::hasTable('products') || ! Schema::hasColumn('products', 'unit')) {
            return;
        }

        if (DB::getDriverName() !== 'mysql') {
            return;
        }

        // Map widened values back before narrowing, then restore original enum.
        DB::table('products')->whereIn('unit', ['sheet', 'meter', 'bucket'])->update(['unit' => 'piece']);
        DB::statement(
            "ALTER TABLE `products` MODIFY COLUMN `unit` " .
            "ENUM('ton','bag','cubic_meter','truck','piece','block') NOT NULL"
        );
    }
};
