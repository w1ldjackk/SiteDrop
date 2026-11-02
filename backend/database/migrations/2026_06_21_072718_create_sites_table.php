<?php
// database/migrations/2026_01_01_000012_create_sites_table.php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Canonical schema: 2026_01_01_000015_create_sites_table
        if (Schema::hasTable('sites')) {
            return;
        }

        Schema::create('sites', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->onDelete('cascade');

            // Site Information
            $table->string('name');
            $table->text('address');
            $table->json('coordinates')->nullable(); // {lat, lng}
            $table->string('contact_person')->nullable();
            $table->string('contact_phone')->nullable();

            // Site Details
            $table->json('site_photos')->nullable();
            $table->text('description')->nullable();

            // Status
            $table->enum('status', ['active', 'inactive', 'completed'])->default('active');

            $table->softDeletes();
            $table->timestamps();

            // Indexes
            $table->index(['user_id', 'status']);
            $table->index('name');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('sites');
    }
};
