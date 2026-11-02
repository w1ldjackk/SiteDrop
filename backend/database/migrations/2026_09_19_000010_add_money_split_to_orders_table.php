<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     *
     * App\Models\Order (fillable/casts/boot) + OrderAndPaymentSeeder expect
     * the marketplace money-split columns, but the create_orders migration
     * never included them.
     */
    public function up(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            if (! Schema::hasColumn('orders', 'commission_amount')) {
                $table->decimal('commission_amount', 12, 2)->nullable()->after('service_fee');
            }
            if (! Schema::hasColumn('orders', 'seller_earnings')) {
                $table->decimal('seller_earnings', 12, 2)->nullable()->after('commission_amount');
            }
            if (! Schema::hasColumn('orders', 'platform_fee')) {
                $table->decimal('platform_fee', 12, 2)->nullable()->after('seller_earnings');
            }
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            foreach (['commission_amount', 'seller_earnings', 'platform_fee'] as $column) {
                if (Schema::hasColumn('orders', $column)) {
                    $table->dropColumn($column);
                }
            }
        });
    }
};
