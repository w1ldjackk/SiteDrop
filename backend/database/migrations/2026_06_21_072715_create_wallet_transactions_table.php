<?php
// database/migrations/2026_01_01_000009_create_wallet_transactions_table.php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('wallet_transactions')) {
            return;
        }

        Schema::create('wallet_transactions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('wallet_id')->constrained()->onDelete('cascade');
            $table->foreignId('user_id')->constrained()->onDelete('cascade');

            // Transaction Details
            $table->enum('type', ['credit', 'debit', 'blocked']);
            $table->decimal('amount', 15, 2);
            $table->string('description');
            $table->string('reference')->nullable()->index();
            $table->decimal('balance_after', 15, 2);

            // Additional Data
            $table->json('metadata')->nullable();

            // Status
            $table->enum('status', ['pending', 'completed', 'failed'])->default('completed');

            $table->timestamps();

            // Indexes
            $table->index(['wallet_id', 'type']);
            $table->index(['user_id', 'created_at']);
            $table->index('status');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('wallet_transactions');
    }
};
