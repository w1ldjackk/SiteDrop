<?php
// database/migrations/2026_01_01_000014_create_profiles_table.php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Canonical schema: 2026_01_01_000014_create_profiles_table
        if (Schema::hasTable('profiles')) {
            return;
        }

        Schema::create('profiles', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->onDelete('cascade');

            // Personal Information
            $table->string('first_name')->nullable();
            $table->string('last_name')->nullable();
            $table->date('date_of_birth')->nullable();
            $table->enum('gender', ['male', 'female', 'other'])->nullable();

            // Contact
            $table->string('alternate_phone')->nullable();
            $table->text('address')->nullable();
            $table->json('coordinates')->nullable(); // {lat, lng}

            // Profile
            $table->string('avatar_url')->nullable();
            $table->text('bio')->nullable();

            // Social Links
            $table->json('social_links')->nullable(); // {facebook, twitter, instagram}

            // Preferences
            $table->json('preferences')->nullable(); // Notification preferences, etc.

            // Verification
            $table->timestamp('identity_verified_at')->nullable();
            $table->string('identity_document')->nullable(); // Path to document

            $table->softDeletes();
            $table->timestamps();

            // Indexes
            $table->index('user_id');
            $table->index(['first_name', 'last_name']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('profiles');
    }
};
