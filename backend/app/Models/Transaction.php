<?php
// app/Models/Transaction.php

namespace App\Models;

use App\Enums\TransactionStatus;
use App\Enums\TransactionType;
use App\Models\Order;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Transaction extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'order_id',
        'payment_id',
        'type', // payment, refund, withdrawal, deposit, fee
        'amount',
        'currency',
        'status',
        'reference',
        'description',
        'metadata',
        'completed_at',
        'failed_at',
        'failed_reason',
        'initiated_by',
    ];

    protected $casts = [
        'amount' => 'float',
        'metadata' => 'array',
        'completed_at' => 'datetime',
        'failed_at' => 'datetime',
    ];

    // Constants
    const TYPE_PAYMENT = TransactionType::Payment->value;
    const TYPE_REFUND = TransactionType::Refund->value;
    const TYPE_WITHDRAWAL = TransactionType::Withdrawal->value;
    const TYPE_DEPOSIT = TransactionType::Deposit->value;
    const TYPE_FEE = TransactionType::Fee->value;

    const STATUS_PENDING = TransactionStatus::Pending->value;
    const STATUS_PROCESSING = TransactionStatus::Processing->value;
    const STATUS_COMPLETED = TransactionStatus::Completed->value;
    const STATUS_FAILED = TransactionStatus::Failed->value;
    const STATUS_CANCELLED = TransactionStatus::Cancelled->value;

    // Relationships
    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function order()
    {
        return $this->belongsTo(Order::class);
    }

    public function payment()
    {
        return $this->belongsTo(Payment::class);
    }

    public function initiator()
    {
        return $this->belongsTo(User::class, 'initiated_by');
    }

    // Scopes
    public function scopeCompleted($query)
    {
        return $query->where('status', self::STATUS_COMPLETED);
    }

    public function scopePending($query)
    {
        return $query->where('status', self::STATUS_PENDING);
    }

    public function scopeByType($query, $type)
    {
        return $query->where('type', $type);
    }

    // Accessors
    public function getStatusLabelAttribute()
    {
        return ucwords(str_replace('_', ' ', $this->status));
    }

    public function getTypeLabelAttribute()
    {
        return ucwords(str_replace('_', ' ', $this->type));
    }

    public function getFormattedAmountAttribute()
    {
        return $this->currency . ' ' . number_format($this->amount, 2);
    }

    // Methods
    public function complete()
    {
        $this->update([
            'status' => self::STATUS_COMPLETED,
            'completed_at' => now(),
        ]);
    }

    public function fail($reason)
    {
        $this->update([
            'status' => self::STATUS_FAILED,
            'failed_at' => now(),
            'failed_reason' => $reason,
        ]);
    }
}
