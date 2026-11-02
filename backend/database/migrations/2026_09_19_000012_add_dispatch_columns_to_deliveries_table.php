<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     *
     * App\Models\Delivery (fillable/casts/vehicle relation) +
     * OrderAndPaymentSeeder expect these dispatch columns, but the
     * create_deliveries migration never included them.
     */
    public function up(): void
    {
        Schema::table('deliveries', function (Blueprint $table) {
            if (! Schema::hasColumn('deliveries', 'assigned_at')) {
                $table->timestamp('assigned_at')->nullable()->after('actual_arrival');
            }
            if (! Schema::hasColumn('deliveries', 'accepted_at')) {
                $table->timestamp('accepted_at')->nullable()->after('assigned_at');
            }
            if (! Schema::hasColumn('deliveries', 'started_at')) {
                $table->timestamp('started_at')->nullable()->after('accepted_at');
            }
            if (! Schema::hasColumn('deliveries', 'completed_at')) {
                $table->timestamp('completed_at')->nullable()->after('started_at');
            }
            if (! Schema::hasColumn('deliveries', 'customer_signature')) {
                $table->text('customer_signature')->nullable()->after('proof_images');
            }
            if (! Schema::hasColumn('deliveries', 'delivery_rating')) {
                $table->decimal('delivery_rating', 3, 2)->nullable()->after('customer_signature');
            }
            if (! Schema::hasColumn('deliveries', 'delivery_comment')) {
                $table->text('delivery_comment')->nullable()->after('delivery_rating');
            }
            if (! Schema::hasColumn('deliveries', 'vehicle_id')) {
                $table->foreignId('vehicle_id')->nullable()->after('driver_id')
                    ->constrained('trucks')->nullOnDelete();
            }
            if (! Schema::hasColumn('deliveries', 'dispatch_notes')) {
                $table->text('dispatch_notes')->nullable()->after('delivery_notes');
            }
            if (! Schema::hasColumn('deliveries', 'delivery_window_start')) {
                $table->timestamp('delivery_window_start')->nullable()->after('estimated_arrival');
            }
            if (! Schema::hasColumn('deliveries', 'delivery_window_end')) {
                $table->timestamp('delivery_window_end')->nullable()->after('delivery_window_start');
            }
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('deliveries', function (Blueprint $table) {
            if (Schema::hasColumn('deliveries', 'vehicle_id')) {
                $table->dropForeign(['vehicle_id']);
            }
            foreach ([
                'assigned_at',
                'accepted_at',
                'started_at',
                'completed_at',
                'customer_signature',
                'delivery_rating',
                'delivery_comment',
                'vehicle_id',
                'dispatch_notes',
                'delivery_window_start',
                'delivery_window_end',
            ] as $column) {
                if (Schema::hasColumn('deliveries', $column)) {
                    $table->dropColumn($column);
                }
            }
        });
    }
};
