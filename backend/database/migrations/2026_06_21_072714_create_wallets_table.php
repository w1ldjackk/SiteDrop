<?php
// database/migrations/2026_01_01_000008_create_wallets_table.php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('wallets')) {
            return;
        }

        Schema::create('wallets', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->onDelete('cascade');

            // Balances
            $table->decimal('balance', 15, 2)->default(0);
            $table->decimal('blocked_balance', 15, 2)->default(0);
            $table->decimal('total_earned', 15, 2)->default(0);
            $table->decimal('total_spent', 15, 2)->default(0);

            // Currency
            $table->string('currency')->default('GHS');

            // Status
            $table->boolean('is_active')->default(true);
            $table->timestamp('last_transaction_at')->nullable();

            $table->timestamps();

            // Indexes
            $table->index('user_id');
            $table->index('is_active');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('wallets');
    }
};
