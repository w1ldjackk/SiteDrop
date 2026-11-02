<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('seller_profiles', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->onDelete('cascade');

            // Business Information
            $table->string('business_name');
            $table->string('business_type'); // quarry, truck_owner, supplier, distributor
            $table->string('business_registration_number')->nullable();
            $table->string('tax_id')->nullable();
            $table->string('business_phone')->nullable();
            $table->string('business_email')->nullable();
            $table->string('website')->nullable();
            $table->text('description')->nullable();

            // Media
            $table->string('logo_url')->nullable();
            $table->string('cover_image_url')->nullable();

            // Status & Verification
            $table->enum('status', ['pending', 'approved', 'suspended', 'rejected'])->default('pending');
            $table->boolean('email_verified')->default(false);
            $table->timestamp('approved_at')->nullable();
            $table->text('rejected_reason')->nullable();

            // Service Areas & Delivery
            $table->json('service_areas')->nullable(); // Coordinates of service areas
            $table->decimal('commission_rate', 5, 2)->default(10.00);
            $table->decimal('minimum_order_amount', 12, 2)->default(0);
            $table->decimal('delivery_radius_km', 8, 2)->default(50);

            // Banking Details
            $table->string('bank_account_name')->nullable();
            $table->string('bank_account_number')->nullable();
            $table->string('bank_name')->nullable();
            $table->string('bank_branch')->nullable();

            // Verification Documents
            $table->json('verification_documents')->nullable();
            $table->json('social_links')->nullable();
            $table->json('business_hours')->nullable();

            $table->softDeletes();
            $table->timestamps();

            // Indexes
            $table->index(['user_id', 'status']);
            $table->index('business_type');
            $table->index('business_name');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('seller_profiles');
    }
};
