<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // SQLite refuses to drop a column that is still referenced by an
        // index, so remove the composite index first (portable on MySQL too).
        Schema::table('reviews', function (Blueprint $table) {
            $table->dropIndex(['reviewer_id', 'order_id']);
        });

        Schema::table('reviews', function (Blueprint $table) {
            // Drop and re-add so order is optional (still preferred when available).
            $table->dropConstrainedForeignId('order_id');
        });

        Schema::table('reviews', function (Blueprint $table) {
            $table->foreignId('order_id')
                ->nullable()
                ->after('id')
                ->constrained()
                ->nullOnDelete();

            $table->index(['reviewer_id', 'order_id']);
        });
    }

    public function down(): void
    {
        Schema::table('reviews', function (Blueprint $table) {
            $table->dropIndex(['reviewer_id', 'order_id']);
        });

        Schema::table('reviews', function (Blueprint $table) {
            $table->dropConstrainedForeignId('order_id');
        });

        Schema::table('reviews', function (Blueprint $table) {
            $table->foreignId('order_id')
                ->after('id')
                ->constrained()
                ->cascadeOnDelete();

            $table->index(['reviewer_id', 'order_id']);
        });
    }
};
