<?php
// database/migrations/2026_01_01_000007_create_reviews_table.php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('reviews', function (Blueprint $table) {
            $table->id();
            $table->foreignId('order_id')->constrained()->onDelete('cascade');
            $table->foreignId('reviewer_id')->constrained('users')->onDelete('cascade');
            $table->foreignId('reviewee_id')->constrained('users')->onDelete('cascade');
            $table->foreignId('product_id')->nullable()->constrained()->nullOnDelete();

            // Review Content
            $table->unsignedTinyInteger('rating'); // 1-5
            $table->text('comment')->nullable();
            $table->json('images')->nullable();

            // Review Type
            $table->enum('type', [
                'buyer_to_seller',
                'buyer_to_product',
                'seller_to_buyer'
            ]);

            // Verification
            $table->boolean('is_verified_purchase')->default(true);

            // Status & Moderation
            $table->enum('status', [
                'pending',
                'published',
                'hidden',
                'reported'
            ])->default('pending');

            // Engagement Metrics
            $table->integer('helpful_count')->default(0);
            $table->integer('reported_count')->default(0);

            $table->timestamps();

            // Indexes
            $table->index(['reviewee_id', 'type', 'status']);
            $table->index(['reviewer_id', 'order_id']);
            $table->index(['product_id', 'status']);
            $table->index('rating');
            $table->index('status');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('reviews');
    }
};
