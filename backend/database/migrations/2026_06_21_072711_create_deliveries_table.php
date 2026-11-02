<?php
// database/migrations/2026_01_01_000005_create_deliveries_table.php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('deliveries', function (Blueprint $table) {
            $table->id();
            $table->foreignId('order_id')->constrained()->onDelete('cascade');
            $table->foreignId('driver_id')->nullable()->constrained('users')->nullOnDelete();

            // Tracking
            $table->string('tracking_number')->unique();

            // Status
            $table->enum('status', [
                'assigned',
                'picked_up',
                'in_transit',
                'arrived',
                'completed',
                'failed',
                'returned'
            ])->default('assigned');

            // Location Tracking
            $table->json('current_location')->nullable(); // {lat, lng, timestamp}
            $table->json('route_path')->nullable(); // Array of coordinates for route

            // Times
            $table->timestamp('picked_up_at')->nullable();
            $table->timestamp('estimated_arrival')->nullable();
            $table->timestamp('actual_arrival')->nullable();

            // Delivery Details
            $table->text('delivery_notes')->nullable();
            $table->json('proof_images')->nullable(); // Receipts, photos

            // Metrics
            $table->decimal('distance_km', 8, 2)->nullable();
            $table->integer('estimated_duration')->nullable(); // In minutes
            $table->decimal('delivery_fee', 12, 2)->default(0);

            $table->timestamps();

            // Indexes
            $table->index('tracking_number');
            $table->index(['order_id', 'status']);
            $table->index(['driver_id', 'status']);
            $table->index('estimated_arrival');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('deliveries');
    }
};
