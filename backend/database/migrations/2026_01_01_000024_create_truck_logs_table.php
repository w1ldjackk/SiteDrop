<?php
// database/migrations/2026_01_01_000024_create_truck_logs_table.php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('truck_logs', function (Blueprint $table) {
            $table->id();
            $table->foreignId('truck_id')->constrained()->onDelete('cascade');
            $table->foreignId('user_id')->nullable()->constrained()->nullOnDelete();

            // Log Details
            $table->enum('action', [
                'created',
                'updated',
                'status_changed',
                'maintenance',
                'insurance',
                'document',
                'accepted',
                'trip_started',
                'trip_ended',
                'location_updated',
                'deleted'
            ]);
            $table->text('description')->nullable();
            $table->json('metadata')->nullable();

            // Client Info
            $table->string('ip_address')->nullable();
            $table->text('user_agent')->nullable();

            $table->timestamps();

            $table->index(['truck_id', 'action']);
            $table->index(['user_id', 'created_at']);
            $table->index('action');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('truck_logs');
    }
};
