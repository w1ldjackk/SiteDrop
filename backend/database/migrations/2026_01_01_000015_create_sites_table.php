<?php
// database/migrations/2026_01_01_000015_create_sites_table.php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('sites', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->onDelete('cascade');

            // Basic Information
            $table->string('name');
            $table->text('address');
            $table->json('coordinates')->nullable();
            $table->string('contact_person')->nullable();
            $table->string('contact_phone')->nullable();

            // Site Details
            $table->json('site_photos')->nullable();
            $table->text('description')->nullable();
            $table->enum('site_type', [
                'construction',
                'quarry',
                'warehouse',
                'supplier',
                'other'
            ])->default('construction');

            // Site Status
            $table->enum('status', [
                'planning',
                'active',
                'on_hold',
                'completed',
                'cancelled'
            ])->default('planning');

            // Site Metrics
            $table->decimal('size_sq_meters', 10, 2)->nullable();
            $table->decimal('budget', 15, 2)->nullable();
            $table->json('materials_needed')->nullable();

            // Priority & Timeline
            $table->enum('priority_level', ['high', 'medium', 'low'])->default('medium');
            $table->timestamp('project_start_date')->nullable();
            $table->timestamp('estimated_completion_date')->nullable();

            // Site Management
            $table->foreignId('site_manager_id')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('supervisor_id')->nullable()->constrained('users')->nullOnDelete();

            // Additional Information
            $table->text('access_notes')->nullable();
            $table->text('security_requirements')->nullable();

            // Tracking
            $table->string('site_code')->unique();
            $table->string('status_update_reason')->nullable();
            $table->timestamp('status_updated_at')->nullable();

            $table->softDeletes();
            $table->timestamps();

            // Indexes
            $table->index(['user_id', 'status']);
            $table->index('site_code');
            $table->index('site_type');
            $table->index('priority_level');
            $table->index('estimated_completion_date');
            $table->index('status_updated_at');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('sites');
    }
};
