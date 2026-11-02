<?php
// database/migrations/2026_01_01_000019_create_site_staff_table.php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('site_staff', function (Blueprint $table) {
            $table->id();
            $table->foreignId('site_id')->constrained()->onDelete('cascade');
            $table->foreignId('user_id')->constrained()->onDelete('cascade');

            // Staff Info
            $table->enum('role', ['site_manager', 'supervisor', 'foreman', 'safety_officer', 'quality_control', 'operator', 'laborer', 'other']);
            $table->string('department')->nullable();
            $table->string('position');

            // Schedule
            $table->timestamp('start_date');
            $table->timestamp('end_date')->nullable();
            $table->boolean('is_active')->default(true);
            $table->json('shift_schedule')->nullable();

            // Contact
            $table->json('contact_emergency')->nullable();

            // Qualifications
            $table->json('certifications')->nullable();
            $table->json('skills')->nullable();

            // Performance
            $table->decimal('performance_rating', 3, 2)->nullable();
            $table->timestamp('last_performance_review')->nullable();

            // Notes
            $table->text('notes')->nullable();

            $table->timestamps();

            $table->index(['site_id', 'is_active']);
            $table->index(['user_id', 'role']);
            $table->index('performance_rating');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('site_staff');
    }
};
