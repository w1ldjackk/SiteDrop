<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     *
     * trip_logs + order_timelines are created before the orders table, so
     * their order_id FKs are attached here, once orders exists. Idempotent:
     * skips any constraint that already exists (e.g. databases migrated
     * before the ordering fix).
     */
    public function up(): void
    {
        if (Schema::hasTable('trip_logs')
            && Schema::hasColumn('trip_logs', 'order_id')
            && Schema::hasTable('orders')
            && ! $this->foreignKeyExists('trip_logs', 'trip_logs_order_id_foreign')) {
            Schema::table('trip_logs', function (Blueprint $table) {
                $table->foreign('order_id', 'trip_logs_order_id_foreign')
                    ->references('id')->on('orders')->nullOnDelete();
            });
        }

        if (Schema::hasTable('order_timelines')
            && Schema::hasColumn('order_timelines', 'order_id')
            && Schema::hasTable('orders')
            && ! $this->foreignKeyExists('order_timelines', 'order_timelines_order_id_foreign')) {
            Schema::table('order_timelines', function (Blueprint $table) {
                $table->foreign('order_id', 'order_timelines_order_id_foreign')
                    ->references('id')->on('orders')->cascadeOnDelete();
            });
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        if (Schema::hasTable('trip_logs')
            && $this->foreignKeyExists('trip_logs', 'trip_logs_order_id_foreign')) {
            Schema::table('trip_logs', function (Blueprint $table) {
                $table->dropForeign('trip_logs_order_id_foreign');
            });
        }

        if (Schema::hasTable('order_timelines')
            && $this->foreignKeyExists('order_timelines', 'order_timelines_order_id_foreign')) {
            Schema::table('order_timelines', function (Blueprint $table) {
                $table->dropForeign('order_timelines_order_id_foreign');
            });
        }
    }

    private function foreignKeyExists(string $table, string $constraint): bool
    {
        if (DB::getDriverName() === 'sqlite') {
            // SQLite exposes foreign keys through PRAGMA; constraint names are
            // not preserved, so match on the referenced table + column instead.
            foreach (DB::select("PRAGMA foreign_key_list('{$table}')") as $fk) {
                if (($fk->table ?? null) === 'orders'
                    && ($fk->to ?? null) === 'id') {
                    return true;
                }
            }

            return false;
        }

        return DB::selectOne(
            "SELECT 1 AS ok FROM information_schema.TABLE_CONSTRAINTS
              WHERE CONSTRAINT_SCHEMA = DATABASE()
                AND TABLE_NAME = ? AND CONSTRAINT_NAME = ?
                AND CONSTRAINT_TYPE = 'FOREIGN KEY'",
            [$table, $constraint]
        ) !== null;
    }
};
