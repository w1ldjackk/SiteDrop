<?php

namespace App\Models;

use App\Enums\PaymentMethod;
use App\Enums\PaymentStatus;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Payment extends Model
{
    use HasFactory;

    protected $fillable = [
        'order_id',
        'user_id',
        'payment_reference',
        'transaction_id',
        'amount',
        'currency',
        'payment_method',
        'payment_channel', // mobile_money, bank_transfer, card, wallet
        'status',
        'metadata',
        'paid_at',
        'refunded_at',
        'refund_amount',
        'refund_reason',
        'gateway_response',
        'ip_address',
        'user_agent',
    ];

    protected $casts = [
        'amount' => 'float',
        'refund_amount' => 'float',
        'metadata' => 'array',
        'gateway_response' => 'array',
        'paid_at' => 'datetime',
        'refunded_at' => 'datetime',
    ];

    // Payment status constants
    const STATUS_PENDING = PaymentStatus::Pending->value;
    const STATUS_SUCCESS = PaymentStatus::Success->value;
    const STATUS_FAILED = PaymentStatus::Failed->value;
    const STATUS_REFUNDED = PaymentStatus::Refunded->value;
    const STATUS_CANCELLED = PaymentStatus::Cancelled->value;

    // Payment methods
    const METHOD_MOBILE_MONEY = PaymentMethod::MobileMoney->value;
    const METHOD_BANK_TRANSFER = PaymentMethod::BankTransfer->value;
    const METHOD_CARD = PaymentMethod::Card->value;
    const METHOD_WALLET = PaymentMethod::Wallet->value;
    const METHOD_CASH = PaymentMethod::Cash->value;

    // Relationships
    public function order()
    {
        return $this->belongsTo(Order::class);
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    // Scopes
    public function scopeSuccessful($query)
    {
        return $query->where('status', self::STATUS_SUCCESS);
    }

    public function scopePending($query)
    {
        return $query->where('status', self::STATUS_PENDING);
    }

    // Accessors
    public function getFormattedAmountAttribute()
    {
        return $this->currency . ' ' . number_format($this->amount, 2);
    }

    // Methods
    public function isSuccessful(): bool
    {
        return $this->status === self::STATUS_SUCCESS;
    }

    public function isRefunded(): bool
    {
        return $this->status === self::STATUS_REFUNDED;
    }

    public function markAsSuccess(string $transactionId = null)
    {
        $this->update([
            'status' => self::STATUS_SUCCESS,
            'transaction_id' => $transactionId,
            'paid_at' => now(),
        ]);

        $this->order->update([
            'payment_status' => Order::PAYMENT_STATUS_PAID,
        ]);
    }

    public function markAsFailed(string $reason = null)
    {
        $this->update([
            'status' => self::STATUS_FAILED,
            'metadata' => array_merge($this->metadata ?? [], ['failure_reason' => $reason]),
        ]);

        $this->order->update([
            'payment_status' => Order::PAYMENT_STATUS_FAILED,
        ]);
    }
}
