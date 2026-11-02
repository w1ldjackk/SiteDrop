<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     *
     * App\Models\User fillables + PermissionSeederService expect these
     * columns, but no earlier migration ever added them. Required for
     * a clean migrate:fresh --seed.
     */
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            if (! Schema::hasColumn('users', 'phone')) {
                $table->string('phone')->nullable()->after('email');
            }
            if (! Schema::hasColumn('users', 'phone_country')) {
                $table->string('phone_country', 8)->nullable()->after('phone');
            }
            if (! Schema::hasColumn('users', 'phone_verified')) {
                $table->boolean('phone_verified')->default(false)->after('phone_country');
            }
            if (! Schema::hasColumn('users', 'role')) {
                $table->string('role')->nullable()->after('phone_verified');
            }
            if (! Schema::hasColumn('users', 'current_site_id')) {
                $table->unsignedBigInteger('current_site_id')->nullable()->after('role');
            }
            if (! Schema::hasColumn('users', 'referral_code')) {
                $table->string('referral_code')->nullable()->after('current_site_id');
            }
            if (! Schema::hasColumn('users', 'last_active_at')) {
                $table->timestamp('last_active_at')->nullable()->after('referral_code');
            }
            if (! Schema::hasColumn('users', 'preferences')) {
                $table->json('preferences')->nullable()->after('last_active_at');
            }
            if (! Schema::hasColumn('users', 'fcm_token')) {
                $table->string('fcm_token')->nullable()->after('preferences');
            }
            if (! Schema::hasColumn('users', 'device_type')) {
                $table->string('device_type')->nullable()->after('fcm_token');
            }
            if (! Schema::hasColumn('users', 'is_online')) {
                $table->boolean('is_online')->default(false)->after('device_type');
            }
            if (! Schema::hasColumn('users', 'last_location')) {
                $table->json('last_location')->nullable()->after('is_online');
            }
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            foreach ([
                'phone',
                'phone_country',
                'phone_verified',
                'role',
                'current_site_id',
                'referral_code',
                'last_active_at',
                'preferences',
                'fcm_token',
                'device_type',
                'is_online',
                'last_location',
            ] as $column) {
                if (Schema::hasColumn('users', $column)) {
                    $table->dropColumn($column);
                }
            }
        });
    }
};
