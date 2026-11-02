<?php
// database/migrations/2026_01_01_000016_create_trucks_table.php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('trucks', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->onDelete('cascade');
            $table->foreignId('driver_id')->nullable()->constrained('users')->nullOnDelete();

            // Vehicle Identification
            $table->string('registration_number')->unique();
            $table->string('make');
            $table->string('model');
            $table->integer('year');
            $table->string('color')->nullable();

            // License Plates
            $table->string('license_plate_front')->nullable();
            $table->string('license_plate_back')->nullable();

            // Capacity
            $table->decimal('capacity_tons', 8, 2);
            $table->decimal('capacity_cubic_meters', 8, 2)->nullable();

            // Vehicle Specifications
            $table->enum('vehicle_type', [
                'tipper',
                'flatbed',
                'tanker',
                'dump_truck',
                'concrete_mixer',
                'carrier',
                'other'
            ])->default('tipper');

            // Features
            $table->json('features')->nullable();
            $table->json('documents')->nullable();

            // Fuel & Efficiency
            $table->enum('fuel_type', ['diesel', 'petrol', 'electric', 'hybrid'])->default('diesel');
            $table->decimal('fuel_efficiency_km_per_liter', 5, 2)->nullable();

            // Mileage Tracking
            $table->decimal('current_mileage', 10, 2)->default(0);
            $table->decimal('last_service_mileage', 10, 2)->nullable();
            $table->decimal('next_service_mileage', 10, 2)->nullable();

            // Maintenance
            $table->timestamp('last_maintenance_date')->nullable();
            $table->timestamp('next_maintenance_date')->nullable();

            // Insurance & Registration
            $table->timestamp('insurance_expiry')->nullable();
            $table->timestamp('registration_expiry')->nullable();

            // Ownership
            $table->enum('owner_type', ['personal', 'company'])->default('personal');
            $table->string('company_name')->nullable();

            // Status
            $table->enum('status', [
                'available',
                'in_transit',
                'maintenance',
                'inactive',
                'out_of_service'
            ])->default('available');

            // Verification
            $table->boolean('is_verified')->default(false);

            // Location
            $table->json('current_location')->nullable();

            // Driver Assignment
            $table->timestamp('driver_assigned_at')->nullable();

            // Notes
            $table->text('notes')->nullable();

            $table->softDeletes();
            $table->timestamps();

            // Indexes
            $table->index('registration_number');
            $table->index(['user_id', 'status']);
            $table->index(['driver_id', 'status']);
            $table->index('vehicle_type');
            $table->index('is_verified');
            $table->index('insurance_expiry');
            $table->index('next_maintenance_date');
            $table->index('fuel_type');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('trucks');
    }
};
