<?php

namespace App\Models;

use App\Enums\WalletTransactionCategory;
use App\Enums\WalletTransactionStatus;
use App\Enums\WalletTransactionType;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class WalletTransaction extends Model
{
    use HasFactory;

    protected $fillable = [
        'wallet_id',
        'user_id',
        'type',
        'category',
        'amount',
        'balance_before',
        'balance_after',
        'description',
        'reference',
        'metadata',
        'status',
        'reviewed_by',
        'reviewed_at',
        'admin_notes',
    ];

    protected $casts = [
        'amount' => 'float',
        'balance_before' => 'float',
        'balance_after' => 'float',
        'metadata' => 'array',
        'type' => WalletTransactionType::class,
        'category' => WalletTransactionCategory::class,
        'status' => WalletTransactionStatus::class,
        'reviewed_at' => 'datetime',
    ];

    const TYPE_CREDIT = WalletTransactionType::Credit->value;
    const TYPE_DEBIT = WalletTransactionType::Debit->value;
    const TYPE_BLOCKED = WalletTransactionType::Blocked->value;
    const TYPE_UNBLOCKED = WalletTransactionType::Unblocked->value;

    const STATUS_PENDING = WalletTransactionStatus::Pending->value;
    const STATUS_COMPLETED = WalletTransactionStatus::Completed->value;
    const STATUS_FAILED = WalletTransactionStatus::Failed->value;
    const STATUS_REJECTED = WalletTransactionStatus::Rejected->value;
    const STATUS_CANCELLED = WalletTransactionStatus::Cancelled->value;

    public function wallet(): BelongsTo
    {
        return $this->belongsTo(Wallet::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function reviewer(): BelongsTo
    {
        return $this->belongsTo(User::class, 'reviewed_by');
    }

    public function scopeCompleted($query)
    {
        return $query->where('status', self::STATUS_COMPLETED);
    }

    public function scopePending($query)
    {
        return $query->where('status', self::STATUS_PENDING);
    }

    public function scopeForUser($query, int $userId)
    {
        return $query->where('user_id', $userId);
    }

    public function getFormattedAmountAttribute(): string
    {
        $type = $this->type instanceof WalletTransactionType
            ? $this->type->value
            : (string) $this->type;
        $sign = in_array($type, [self::TYPE_CREDIT, self::TYPE_UNBLOCKED], true) ? '+' : '-';

        return $sign.'GH₵ '.number_format((float) $this->amount, 2);
    }

    public function getIsPendingAttribute(): bool
    {
        return ($this->status instanceof WalletTransactionStatus
            ? $this->status
            : WalletTransactionStatus::tryFrom((string) $this->status)
        ) === WalletTransactionStatus::Pending;
    }
}
