<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('seller_profiles', function (Blueprint $table) {
            $table->string('seller_code', 32)->nullable()->unique()->after('id');
        });

        // Backfill existing rows: SLR-000001
        $rows = DB::table('seller_profiles')->orderBy('id')->get(['id']);
        foreach ($rows as $row) {
            DB::table('seller_profiles')->where('id', $row->id)->update([
                'seller_code' => 'SLR-'.str_pad((string) $row->id, 6, '0', STR_PAD_LEFT),
            ]);
        }
    }

    public function down(): void
    {
        Schema::table('seller_profiles', function (Blueprint $table) {
            $table->dropUnique(['seller_code']);
            $table->dropColumn('seller_code');
        });
    }
};
