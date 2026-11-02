<?php
// database/migrations/2026_01_01_000014_create_profiles_table.php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('profiles', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->onDelete('cascade');

            // Personal Information
            $table->string('first_name')->nullable();
            $table->string('last_name')->nullable();
            $table->date('date_of_birth')->nullable();
            $table->enum('gender', ['male', 'female', 'other', 'prefer_not_to_say'])->nullable();

            // Contact Information
            $table->string('alternate_phone')->nullable();
            $table->text('address')->nullable();
            $table->json('coordinates')->nullable(); // {lat, lng}

            // Profile Media
            $table->string('avatar_url')->nullable();
            $table->text('bio')->nullable();

            // Social Links
            $table->json('social_links')->nullable(); // {facebook, twitter, instagram, linkedin}

            // Preferences
            $table->json('preferences')->nullable(); // Notification preferences, language, etc.

            // Verification
            $table->timestamp('identity_verified_at')->nullable();
            $table->string('identity_document')->nullable(); // Path to document

            // Additional Info
            $table->string('nationality')->nullable();
            $table->string('occupation')->nullable();
            $table->string('company')->nullable();

            // Emergency Contact
            $table->string('emergency_contact_name')->nullable();
            $table->string('emergency_contact_phone')->nullable();
            $table->string('emergency_contact_relationship')->nullable();

            $table->softDeletes();
            $table->timestamps();

            // Indexes
            $table->index('user_id');
            $table->index(['first_name', 'last_name']);
            $table->index('gender');
            $table->index('identity_verified_at');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('profiles');
    }
};
