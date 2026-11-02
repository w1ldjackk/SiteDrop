<?php
// database/migrations/2026_09_19_000001_add_site_id_to_products_table.php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('products')) {
            return;
        }

        Schema::table('products', function (Blueprint $table) {
            if (! Schema::hasColumn('products', 'site_id')) {
                $table->foreignId('site_id')->nullable()->after('seller_id')->constrained('sites')->nullOnDelete();
                $table->index(['seller_id', 'site_id']);
            }
        });
    }

    public function down(): void
    {
        if (! Schema::hasTable('products')) {
            return;
        }

        Schema::table('products', function (Blueprint $table) {
            if (Schema::hasColumn('products', 'site_id')) {
                $table->dropConstrainedForeignId('site_id');
            }
        });
    }
};
