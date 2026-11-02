<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('transactions')) {
            return;
        }

        Schema::create('transactions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->onDelete('cascade');
            $table->foreignId('order_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('payment_id')->nullable()->constrained()->nullOnDelete();
            $table->string('type'); // payment, refund, withdrawal, deposit, fee
            $table->decimal('amount', 15, 2);
            $table->string('currency', 10)->default('GHS');
            $table->string('status'); // pending, processing, completed, failed, cancelled
            $table->string('reference')->nullable();
            $table->string('description')->nullable();
            $table->json('metadata')->nullable();
            $table->foreignId('initiated_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('completed_at')->nullable();
            $table->timestamp('failed_at')->nullable();
            $table->string('failed_reason')->nullable();
            $table->timestamps();

            $table->index(['user_id', 'type']);
            $table->index(['order_id', 'status']);
            $table->index(['payment_id']);
            // Note: reference index skipped if already exists
            if (!Schema::hasIndex('transactions', 'transactions_reference_index')) {
                $table->index('reference');
            }
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('transactions');
    }
};
