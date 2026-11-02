<?php
// database/migrations/2026_01_01_000022_create_truck_documents_table.php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('truck_documents', function (Blueprint $table) {
            $table->id();
            $table->foreignId('truck_id')->constrained()->onDelete('cascade');
            $table->foreignId('user_id')->constrained()->onDelete('cascade');

            // Document Info
            $table->enum('document_type', ['insurance', 'registration', 'road_worthy', 'permit', 'inspection', 'license', 'other']);
            $table->string('title');
            $table->text('description')->nullable();
            $table->string('document_number')->nullable();

            // File
            $table->string('file_path');
            $table->string('file_name');
            $table->integer('file_size')->nullable();
            $table->string('file_extension')->nullable();

            // Dates
            $table->timestamp('issue_date')->nullable();
            $table->timestamp('expiry_date')->nullable();

            // Status
            $table->enum('status', ['pending', 'active', 'expired', 'rejected'])->default('pending');
            $table->boolean('is_required')->default(true);

            // Verification
            $table->foreignId('verified_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('verified_at')->nullable();

            // Notes
            $table->text('notes')->nullable();

            $table->timestamps();

            $table->index(['truck_id', 'status']);
            $table->index(['document_type', 'expiry_date']);
            $table->index('verified_at');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('truck_documents');
    }
};
