<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('products') || ! Schema::hasColumn('products', 'unit')) {
            return;
        }

        if (DB::getDriverName() !== 'mysql') {
            return;
        }

        DB::statement(
            "ALTER TABLE products MODIFY COLUMN unit " .
            "ENUM('ton','bag','cubic_meter','truck','trip','piece','block','sheet','meter','bucket') NOT NULL"
        );
    }

    public function down(): void
    {
        if (! Schema::hasTable('products') || ! Schema::hasColumn('products', 'unit')) {
            return;
        }

        if (DB::getDriverName() !== 'mysql') {
            return;
        }

        DB::table('products')->where('unit', 'trip')->update(['unit' => 'truck']);
        DB::statement(
            "ALTER TABLE products MODIFY COLUMN unit " .
            "ENUM('ton','bag','cubic_meter','truck','piece','block','sheet','meter','bucket') NOT NULL"
        );
    }
};
