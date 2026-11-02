<?php
// database/migrations/2026_01_01_000026_create_order_timelines_table.php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('order_timelines', function (Blueprint $table) {
            $table->id();
            // NOTE: orders table is created by a later migration, so the FK is
            // added in 2026_09_19_000006_add_missing_order_foreign_keys instead.
            $table->foreignId('order_id')->index();

            // Timeline Entry
            $table->string('status');
            $table->text('description');
            $table->json('metadata')->nullable();
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();

            // Additional tracking
            $table->string('ip_address')->nullable();
            $table->text('user_agent')->nullable();

            // Timestamp (we use created_at as the timeline time)
            $table->timestamp('created_at');

            // Indexes for performance
            $table->index(['order_id', 'created_at']);
            $table->index('status');
            $table->index(['order_id', 'status']);
            $table->index('created_by');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('order_timelines');
    }
};
