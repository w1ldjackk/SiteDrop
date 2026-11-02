<?php
// database/migrations/2026_01_01_000004_create_orders_table.php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('orders', function (Blueprint $table) {
            $table->id();
            $table->foreignId('buyer_id')->constrained('users')->onDelete('cascade');
            $table->foreignId('seller_id')->constrained('users')->onDelete('cascade');
            $table->foreignId('product_id')->constrained()->onDelete('cascade');

            // Order Identification
            $table->string('order_number')->unique();

            // Order Details
            $table->decimal('quantity', 10, 2);
            $table->decimal('unit_price', 12, 2);
            $table->decimal('subtotal', 12, 2);
            $table->decimal('delivery_fee', 12, 2)->default(0);
            $table->decimal('service_fee', 12, 2)->default(0);
            $table->decimal('discount_amount', 12, 2)->default(0);
            $table->decimal('tax_amount', 12, 2)->default(0);
            $table->decimal('total_amount', 12, 2);
            $table->string('currency')->default('GHS');

            // Statuses
            $table->enum('status', [
                'pending',
                'confirmed',
                'processing',
                'ready_for_delivery',
                'dispatched',
                'in_transit',
                'delivered',
                'completed',
                'cancelled',
                'refunded'
            ])->default('pending');

            $table->enum('payment_status', [
                'pending',
                'paid',
                'failed',
                'refunded',
                'partial'
            ])->default('pending');

            $table->enum('payment_method', [
                'mobile_money',
                'bank_transfer',
                'card',
                'cash',
                'cash_on_delivery',
                'wallet'
            ])->nullable();

            // Delivery Information
            $table->text('delivery_address');
            $table->json('delivery_coordinates')->nullable(); // {lat, lng}
            $table->text('special_instructions')->nullable();
            $table->timestamp('delivery_scheduled_at')->nullable();
            $table->timestamp('delivered_at')->nullable();

            // Cancellation
            $table->text('cancellation_reason')->nullable();
            $table->foreignId('cancelled_by')->nullable()->constrained('users')->nullOnDelete();

            $table->softDeletes();
            $table->timestamps();

            // Indexes
            $table->index('order_number');
            $table->index(['buyer_id', 'status']);
            $table->index(['seller_id', 'status']);
            $table->index('payment_status');
            $table->index('delivery_scheduled_at');
            $table->index(['created_at', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('orders');
    }
};
