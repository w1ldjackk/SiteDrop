<?php
// database/migrations/2026_01_01_000003_create_products_table.php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('products', function (Blueprint $table) {
            $table->id();
            $table->foreignId('seller_id')->constrained('users')->onDelete('cascade');

            // Basic Information
            $table->string('name');
            $table->string('category');
            $table->string('sub_category')->nullable();
            $table->text('description')->nullable();
            $table->string('sku')->nullable()->unique();

            // Pricing & Units
            $table->decimal('price_per_unit', 12, 2);
            $table->enum('unit', ['ton', 'bag', 'cubic_meter', 'truck', 'piece', 'block']);
            $table->integer('minimum_order_quantity')->default(1);
            $table->integer('maximum_order_quantity')->nullable();

            // Availability & Stock
            $table->boolean('is_available')->default(true);
            $table->boolean('is_featured')->default(false);
            $table->integer('stock_quantity')->default(0);
            $table->decimal('weight_kg', 10, 2)->nullable();

            // Media & Specs
            $table->json('images')->nullable();
            $table->json('specifications')->nullable(); // {size, color, grade, etc.}

            // Delivery & Preparation
            $table->decimal('delivery_fee_per_km', 8, 2)->nullable();
            $table->integer('preparation_time_minutes')->default(30);
            $table->boolean('is_cod_available')->default(true);
            $table->boolean('is_delivery_available')->default(true);

            // Analytics
            $table->integer('views_count')->default(0);
            $table->integer('orders_count')->default(0);
            $table->decimal('avg_rating', 3, 2)->default(0);

            $table->softDeletes();
            $table->timestamps();

            // Indexes
            $table->index(['seller_id', 'is_available']);
            $table->index('category');
            $table->index('sub_category');
            $table->index('is_featured');
            $table->index('avg_rating');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('products');
    }
};
