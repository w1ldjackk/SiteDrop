<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     *
     * App\Models\Order fillable + CheckoutService expect delivery_phone and
     * processed_at, but neither the create_orders migration nor any later
     * one added them (live checkout crashed on insert).
     */
    public function up(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            if (! Schema::hasColumn('orders', 'delivery_phone')) {
                $table->string('delivery_phone', 32)->nullable()->after('delivery_address');
            }
            if (! Schema::hasColumn('orders', 'processed_at')) {
                $table->timestamp('processed_at')->nullable()->after('delivered_at');
            }
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            foreach (['delivery_phone', 'processed_at'] as $column) {
                if (Schema::hasColumn('orders', $column)) {
                    $table->dropColumn($column);
                }
            }
        });
    }
};
