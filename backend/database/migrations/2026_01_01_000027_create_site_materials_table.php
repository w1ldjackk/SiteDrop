<?php
// database/migrations/2026_01_01_000027_create_site_materials_table.php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('site_materials', function (Blueprint $table) {
            $table->id();
            $table->foreignId('site_id')->constrained()->onDelete('cascade');
            $table->foreignId('supplier_id')->nullable()->constrained('users')->nullOnDelete();

            // Material Details
            $table->string('material_name');
            $table->decimal('quantity_needed', 10, 2);
            $table->decimal('quantity_delivered', 10, 2)->default(0);
            $table->string('unit');

            // Costs
            $table->decimal('estimated_cost', 15, 2)->nullable();
            $table->decimal('actual_cost', 15, 2)->nullable();

            // Status & Dates
            $table->enum('delivery_status', ['pending', 'partial', 'completed'])->default('pending');
            $table->timestamp('ordered_at')->nullable();
            $table->timestamp('expected_delivery_date')->nullable();
            $table->timestamp('delivered_at')->nullable();

            // Notes
            $table->text('notes')->nullable();

            $table->timestamps();

            // Indexes
            $table->index(['site_id', 'delivery_status']);
            $table->index('supplier_id');
            $table->index('expected_delivery_date');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('site_materials');
    }
};
