<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * One seller profile per user — prevents the list showing 2 rows for 1 seller.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('seller_profiles', function (Blueprint $table) {
            // Drop plain FK index name if needed, then unique
            $table->unique('user_id', 'seller_profiles_user_id_unique');
        });
    }

    public function down(): void
    {
        Schema::table('seller_profiles', function (Blueprint $table) {
            $table->dropUnique('seller_profiles_user_id_unique');
        });
    }
};
