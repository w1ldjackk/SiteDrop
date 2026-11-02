<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     *
     * Truck verification workflow: admin approves or rejects with a comment.
     */
    public function up(): void
    {
        Schema::table('trucks', function (Blueprint $table) {
            if (! Schema::hasColumn('trucks', 'rejected_reason')) {
                $table->text('rejected_reason')->nullable()->after('is_verified');
            }
            if (! Schema::hasColumn('trucks', 'verified_at')) {
                $table->timestamp('verified_at')->nullable()->after('rejected_reason');
            }
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('trucks', function (Blueprint $table) {
            foreach (['rejected_reason', 'verified_at'] as $column) {
                if (Schema::hasColumn('trucks', $column)) {
                    $table->dropColumn($column);
                }
            }
        });
    }
};
