<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Saved payment instruments (SiteDrop-style wallet): MoMo accounts, cards,
 * bank accounts. Sensitive details live in the encrypted `details` JSON —
 * only last4/brand stay readable for display.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('payment_instruments', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->onDelete('cascade');
            $table->enum('type', ['mobile_money', 'card', 'bank']);
            $table->string('label')->nullable(); // "My MTN", "Salary card"
            $table->string('network', 32)->nullable(); // MTN/Vodafone/AirtelTigo, Visa/…
            $table->string('last4', 4)->nullable();
            $table->string('exp', 7)->nullable(); // MM/YY for cards
            $table->string('holder', 120)->nullable();
            $table->json('details')->nullable(); // encrypted cast: full number etc.
            $table->boolean('is_default')->default(false);
            $table->timestamps();

            $table->index(['user_id', 'type']);
            $table->index(['user_id', 'is_default']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('payment_instruments');
    }
};
