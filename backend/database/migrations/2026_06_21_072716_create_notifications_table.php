<?php
// database/migrations/2026_01_01_000010_create_notifications_table.php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Table may already exist from 2026_01_01_000025_create_notifications_table.
        if (Schema::hasTable('notifications')) {
            return;
        }

        Schema::create('notifications', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->onDelete('cascade');

            // Notification Content
            $table->enum('type', [
                'order',
                'payment',
                'delivery',
                'system',
                'promotion'
            ]);
            $table->string('title');
            $table->text('body');
            $table->json('data')->nullable();
            $table->string('action_url')->nullable();
            $table->string('image_url')->nullable();

            // Delivery Status
            $table->enum('delivery_status', [
                'pending',
                'sent',
                'delivered',
                'failed'
            ])->default('pending');

            $table->enum('channel', [
                'push',
                'email',
                'sms',
                'in_app'
            ])->default('in_app');

            $table->enum('priority', ['high', 'normal', 'low'])->default('normal');

            // Timestamps
            $table->timestamp('read_at')->nullable();
            $table->timestamp('sent_at')->nullable();
            $table->timestamp('expires_at')->nullable();

            $table->timestamps();

            // Indexes
            $table->index(['user_id', 'read_at']);
            $table->index(['user_id', 'type']);
            $table->index('delivery_status');
            $table->index('expires_at');
            $table->index('channel');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('notifications');
    }
};
