<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Wallet extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'balance',
        'currency',
        'blocked_balance',
        'total_earned',
        'total_spent',
        'last_transaction_at',
        'is_active',
    ];

    protected $casts = [
        'balance' => 'float',
        'blocked_balance' => 'float',
        'total_earned' => 'float',
        'total_spent' => 'float',
        'last_transaction_at' => 'datetime',
        'is_active' => 'boolean',
    ];

    protected $appends = [
        'available_balance',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function transactions(): HasMany
    {
        return $this->hasMany(WalletTransaction::class)->latest();
    }

    /**
     * Get the available balance (total balance minus blocked balance).
     * 
     * NOTE: This is an accessor, not a database column. When using raw queries or
     * selecting specific columns, you must load the wallet model or manually compute
     * `available_balance = GREATEST(0, balance - blocked_balance)`.
     * 
     * @return float
     */
    public function getAvailableBalanceAttribute(): float
    {
        return max(0, (float) $this->balance - (float) $this->blocked_balance);
    }

    /**
     * Scope to include computed available_balance in query results.
     * Portable across MySQL/PostgreSQL/SQLite using CASE WHEN.
     */
    public function scopeWithAvailableBalance($query)
    {
        return $query->selectRaw('wallets.*, CASE WHEN wallets.balance - wallets.blocked_balance > 0 THEN wallets.balance - wallets.blocked_balance ELSE 0 END as available_balance');
    }

    /**
     * Ensure the user has a wallet row.
     */
    public static function forUser(User|int $user): self
    {
        $userId = $user instanceof User ? (int) $user->id : (int) $user;

        return static::query()->firstOrCreate(
            ['user_id' => $userId],
            [
                'balance' => 0,
                'blocked_balance' => 0,
                'total_earned' => 0,
                'total_spent' => 0,
                'currency' => 'GHS',
                'is_active' => true,
            ]
        );
    }
}
