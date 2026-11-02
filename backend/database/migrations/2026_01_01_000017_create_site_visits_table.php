<?php
// database/migrations/2026_01_01_000017_create_site_visits_table.php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('site_visits', function (Blueprint $table) {
            $table->id();
            $table->foreignId('site_id')->constrained()->onDelete('cascade');
            $table->foreignId('user_id')->constrained()->onDelete('cascade');

            // Visitor Info
            $table->string('visitor_name');
            $table->string('visitor_phone');
            $table->string('visitor_email')->nullable();
            $table->string('visitor_signature')->nullable();
            $table->string('host_signature')->nullable();

            // Visit Details
            $table->enum('visit_type', ['scheduled', 'walk-in', 'emergency'])->default('scheduled');
            $table->timestamp('visit_date');
            $table->timestamp('check_in_time')->nullable();
            $table->timestamp('check_out_time')->nullable();
            $table->text('purpose');
            $table->text('notes')->nullable();

            // Status & Approval
            $table->enum('status', ['scheduled', 'checked_in', 'in_progress', 'completed', 'cancelled', 'rejected'])->default('scheduled');
            $table->foreignId('approved_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('approved_at')->nullable();

            // Safety & Compliance
            $table->boolean('safety_briefing_completed')->default(false);
            $table->boolean('ppe_provided')->default(false);
            $table->decimal('temperature', 4, 1)->nullable();

            // Vehicle Info
            $table->string('vehicle_registration')->nullable();

            $table->timestamps();

            $table->index(['site_id', 'status']);
            $table->index(['user_id', 'visit_date']);
            $table->index('check_in_time');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('site_visits');
    }
};
