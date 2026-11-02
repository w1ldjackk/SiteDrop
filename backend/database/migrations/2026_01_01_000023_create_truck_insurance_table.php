<?php
// database/migrations/2026_01_01_000023_create_truck_insurance_table.php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('truck_insurance', function (Blueprint $table) {
            $table->id();
            $table->foreignId('truck_id')->constrained()->onDelete('cascade');

            // Policy Details
            $table->string('policy_number')->unique();
            $table->string('insurance_company');
            $table->enum('type', ['comprehensive', 'third_party', 'motor_accident', 'fire_theft', 'public_liability', 'goods_transit', 'other']);

            // Coverage Dates
            $table->timestamp('coverage_start_date');
            $table->timestamp('coverage_end_date');

            // Premium
            $table->decimal('premium_amount', 12, 2);
            $table->string('premium_currency')->default('GHS');
            $table->enum('payment_frequency', ['monthly', 'quarterly', 'biannually', 'annually'])->default('annually');

            // Status
            $table->enum('status', ['active', 'expired', 'cancelled', 'pending', 'suspended'])->default('pending');

            // Coverage Details
            $table->json('coverage_details')->nullable();
            $table->json('exclusions')->nullable();

            // Beneficiary
            $table->string('beneficiary_name')->nullable();
            $table->string('beneficiary_relationship')->nullable();

            // Documents
            $table->string('document_path')->nullable();

            // Agent/Contact
            $table->string('agent_name')->nullable();
            $table->string('agent_phone')->nullable();
            $table->string('agent_email')->nullable();
            $table->string('claim_contact')->nullable();

            // Claims History
            $table->timestamp('last_claim_date')->nullable();
            $table->integer('claim_count')->default(0);

            // Notes
            $table->text('notes')->nullable();

            $table->timestamps();

            $table->index(['truck_id', 'status']);
            $table->index('policy_number');
            $table->index('coverage_end_date');
            $table->index(['insurance_company', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('truck_insurance');
    }
};
