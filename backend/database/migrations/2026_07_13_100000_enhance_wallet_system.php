<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('wallets')) {
            Schema::table('wallets', function (Blueprint $table) {
                if (! Schema::hasColumn('wallets', 'unique_user_id_done')) {
                    // ensure one wallet per user
                }
            });

            // Unique user_id if not already unique
            try {
                Schema::table('wallets', function (Blueprint $table) {
                    $table->unique('user_id');
                });
            } catch (\Throwable) {
                // already unique
            }
        }

        if (Schema::hasTable('wallet_transactions')) {
            Schema::table('wallet_transactions', function (Blueprint $table) {
                if (! Schema::hasColumn('wallet_transactions', 'category')) {
                    $table->string('category', 40)->default('adjustment')->after('type');
                }
                if (! Schema::hasColumn('wallet_transactions', 'reviewed_by')) {
                    $table->foreignId('reviewed_by')->nullable()->after('status')
                        ->constrained('users')->nullOnDelete();
                }
                if (! Schema::hasColumn('wallet_transactions', 'reviewed_at')) {
                    $table->timestamp('reviewed_at')->nullable()->after('reviewed_by');
                }
                if (! Schema::hasColumn('wallet_transactions', 'admin_notes')) {
                    $table->text('admin_notes')->nullable()->after('reviewed_at');
                }
                if (! Schema::hasColumn('wallet_transactions', 'balance_before')) {
                    $table->decimal('balance_before', 15, 2)->nullable()->after('amount');
                }
            });

            // Expand status enum via string column if needed (portable)
            // MySQL enum alteration is brittle; convert status/type to string if still enum.
            try {
                Schema::table('wallet_transactions', function (Blueprint $table) {
                    $table->string('status', 20)->default('completed')->change();
                    $table->string('type', 20)->change();
                });
            } catch (\Throwable) {
                // doctrine/dbal may be missing — skip change()
            }
        }
    }

    public function down(): void
    {
        if (Schema::hasTable('wallet_transactions')) {
            Schema::table('wallet_transactions', function (Blueprint $table) {
                foreach (['category', 'reviewed_by', 'reviewed_at', 'admin_notes', 'balance_before'] as $col) {
                    if (Schema::hasColumn('wallet_transactions', $col)) {
                        if ($col === 'reviewed_by') {
                            $table->dropConstrainedForeignId('reviewed_by');
                        } else {
                            $table->dropColumn($col);
                        }
                    }
                }
            });
        }
    }
};
