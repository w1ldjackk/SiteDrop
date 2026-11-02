<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     *
     * Live column was enum without 'message', which breaks chat/message notifications.
     * Use VARCHAR so new types (message, etc.) do not require another ALTER.
     */
    public function up(): void
    {
        if (! Schema::hasTable('notifications')) {
            return;
        }

        if (DB::getDriverName() !== 'mysql') {
            return;
        }

        // Raw ALTER avoids doctrine/dbal requirement for ->change().
        DB::statement("ALTER TABLE `notifications` MODIFY `type` VARCHAR(50) NOT NULL DEFAULT 'system'");
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        if (! Schema::hasTable('notifications')) {
            return;
        }

        if (DB::getDriverName() !== 'mysql') {
            return;
        }

        DB::statement("ALTER TABLE `notifications` MODIFY `type` ENUM(
            'order','payment','delivery','system','promotion','site','truck','review','message'
        ) NOT NULL DEFAULT 'system'");
    }
};
