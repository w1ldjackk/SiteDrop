<?php
// database/migrations/2026_01_01_000013_create_trucks_table.php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Canonical schema: 2026_01_01_000016_create_trucks_table
        if (Schema::hasTable('trucks')) {
            return;
        }

        Schema::create('trucks', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->onDelete('cascade');

            // Vehicle Information
            $table->string('registration_number')->unique();
            $table->string('make');
            $table->string('model');
            $table->integer('year');
            $table->string('color')->nullable();

            // Capacity
            $table->decimal('capacity_tons', 8, 2);
            $table->decimal('capacity_cubic_meters', 8, 2)->nullable();

            // Features
            $table->string('vehicle_type'); // tipper, flatbed, tanker, etc.
            $table->json('features')->nullable(); // GPS, tracking, etc.

            // Documents
            $table->json('documents')->nullable(); // Insurance, registration, etc.
            $table->timestamp('insurance_expiry')->nullable();
            $table->timestamp('registration_expiry')->nullable();

            // Status
            $table->enum('status', ['available', 'in_transit', 'maintenance', 'inactive'])->default('available');
            $table->boolean('is_verified')->default(false);

            // Location
            $table->json('current_location')->nullable(); // {lat, lng}

            $table->softDeletes();
            $table->timestamps();

            // Indexes
            $table->index('registration_number');
            $table->index(['user_id', 'status']);
            $table->index('vehicle_type');
            $table->index('is_verified');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('trucks');
    }
};
