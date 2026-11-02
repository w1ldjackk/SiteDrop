<?php
// database/migrations/2026_01_01_000018_create_site_documents_table.php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('site_documents', function (Blueprint $table) {
            $table->id();
            $table->foreignId('site_id')->constrained()->onDelete('cascade');
            $table->foreignId('user_id')->constrained()->onDelete('cascade');

            // Document Info
            $table->string('title');
            $table->text('description')->nullable();
            $table->enum('document_type', ['permit', 'contract', 'blueprint', 'report', 'invoice', 'insurance', 'certificate', 'other']);
            $table->string('file_path');
            $table->string('file_name');
            $table->integer('file_size')->nullable();
            $table->string('file_extension')->nullable();
            $table->string('version')->default('1.0');

            // Status & Approval
            $table->enum('status', ['draft', 'active', 'archived', 'expired', 'rejected'])->default('draft');
            $table->foreignId('uploaded_by')->constrained('users');
            $table->foreignId('approved_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('approved_at')->nullable();
            $table->timestamp('expiry_date')->nullable();

            // Access Control
            $table->boolean('is_confidential')->default(false);
            $table->enum('access_level', ['public', 'private', 'restricted'])->default('public');
            $table->json('tags')->nullable();

            $table->timestamps();

            $table->index(['site_id', 'status']);
            $table->index(['document_type', 'status']);
            $table->index('expiry_date');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('site_documents');
    }
};
