<?php
// database/migrations/2026_01_01_000021_create_trip_logs_table.php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('trip_logs', function (Blueprint $table) {
            $table->id();
            $table->foreignId('truck_id')->constrained()->onDelete('cascade');
            $table->foreignId('driver_id')->constrained('users')->onDelete('cascade');
            // NOTE: orders table is created by a later migration, so the FK is
            // added in 2026_09_19_000006_add_missing_order_foreign_keys instead.
            $table->foreignId('order_id')->nullable()->index();

            // Location
            $table->json('start_location');
            $table->json('end_location')->nullable();
            $table->json('route_path')->nullable();
            $table->json('waypoints')->nullable();

            // Metrics
            $table->decimal('distance_km', 10, 2);
            $table->integer('duration_minutes')->nullable();
            $table->decimal('fuel_consumed_liters', 10, 2)->nullable();
            $table->decimal('fuel_efficiency_km_per_liter', 8, 2)->nullable();

            // Odometer
            $table->decimal('start_odometer', 10, 2)->nullable();
            $table->decimal('end_odometer', 10, 2)->nullable();

            // Speed
            $table->decimal('average_speed', 6, 2)->nullable();
            $table->decimal('max_speed', 6, 2)->nullable();

            // Conditions
            $table->json('weather_conditions')->nullable();
            $table->json('road_conditions')->nullable();

            // Status
            $table->enum('status', ['scheduled', 'in_progress', 'completed', 'cancelled', 'delayed'])->default('scheduled');

            // Timestamps
            $table->timestamp('started_at')->nullable();
            $table->timestamp('ended_at')->nullable();
            $table->timestamp('completed_at')->nullable();

            // Notes
            $table->text('notes')->nullable();

            $table->timestamps();

            $table->index(['truck_id', 'status']);
            $table->index(['driver_id', 'started_at']);
            $table->index('started_at');
            $table->index('completed_at');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('trip_logs');
    }
};
