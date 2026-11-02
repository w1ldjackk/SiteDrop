<?php
// database/migrations/2026_01_01_000006_create_payments_table.php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('payments', function (Blueprint $table) {
            $table->id();
            $table->foreignId('order_id')->constrained()->onDelete('cascade');
            $table->foreignId('user_id')->constrained()->onDelete('cascade');

            // Payment Reference
            $table->string('payment_reference')->unique();
            $table->string('transaction_id')->nullable()->unique();

            // Amount & Currency
            $table->decimal('amount', 12, 2);
            $table->string('currency')->default('GHS');

            // Payment Method
            $table->enum('payment_method', [
                'mobile_money',
                'bank_transfer',
                'card',
                'wallet',
                'cash',
                'cash_on_delivery'
            ]);
            $table->string('payment_channel')->nullable(); // Specific provider

            // Status
            $table->enum('status', [
                'pending',
                'success',
                'failed',
                'refunded',
                'cancelled'
            ])->default('pending');

            // Refund Information
            $table->decimal('refund_amount', 12, 2)->default(0);
            $table->timestamp('refunded_at')->nullable();
            $table->text('refund_reason')->nullable();

            // Metadata
            $table->json('metadata')->nullable();
            $table->json('gateway_response')->nullable();

            // Client Information
            $table->string('ip_address')->nullable();
            $table->text('user_agent')->nullable();

            // Timestamps
            $table->timestamp('paid_at')->nullable();
            $table->timestamps();

            // Indexes
            $table->index('payment_reference');
            $table->index('transaction_id');
            $table->index(['order_id', 'status']);
            $table->index(['user_id', 'status']);
            $table->index('status');
            $table->index('payment_method');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('payments');
    }
};
