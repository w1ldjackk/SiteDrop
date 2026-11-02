<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     *
     * App\Models\TruckMaintenance + TruckSeeder expect this table, but no
     * migration ever created it (fresh seeds failed on truncate).
     * Columns mirror TruckMaintenance::$fillable.
     */
    public function up(): void
    {
        if (Schema::hasTable('truck_maintenances')) {
            return;
        }

        Schema::create('truck_maintenances', function (Blueprint $table) {
            $table->id();
            $table->foreignId('truck_id')->constrained()->onDelete('cascade');
            $table->string('maintenance_type');
            $table->text('description')->nullable();
            $table->decimal('cost', 12, 2)->nullable();
            $table->timestamp('performed_at')->nullable();
            $table->foreignId('performed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->text('notes')->nullable();
            $table->decimal('mileage_at_service', 12, 2)->nullable();
            $table->decimal('next_service_mileage', 12, 2)->nullable();
            $table->string('status')->default('completed');
            $table->timestamps();

            $table->index(['truck_id', 'performed_at']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('truck_maintenances');
    }
};
