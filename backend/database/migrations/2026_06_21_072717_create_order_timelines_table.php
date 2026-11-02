<?php
// database/migrations/2026_01_01_000011_create_order_timelines_table.php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Canonical schema: 2026_01_01_000026_create_order_timelines_table
        if (Schema::hasTable('order_timelines')) {
            return;
        }

        Schema::create('order_timelines', function (Blueprint $table) {
            $table->id();
            $table->foreignId('order_id')->constrained()->onDelete('cascade');

            // Timeline Entry
            $table->string('status');
            $table->text('description');
            $table->json('metadata')->nullable();
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();

            // Timestamp
            $table->timestamp('created_at');

            // Indexes
            $table->index(['order_id', 'created_at']);
            $table->index('status');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('order_timelines');
    }
};
