<?php
// app/Models/Order.php

namespace App\Models;

use App\Enums\PaymentMethod;
use App\Enums\OrderPaymentStatus;
use App\Enums\OrderStatus;
use App\Events\OrderStatusChanged;
use App\Jobs\Notification\SendOrderStatusNotification;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Support\Str;

class Order extends Model
{
    use HasFactory, SoftDeletes;

    protected $fillable = [
        'buyer_id',
        'seller_id',
        'product_id',
        'order_number',
        'quantity',
        'unit_price',
        'subtotal',
        'delivery_fee',
        'service_fee',
        'total_amount',
        'status',
        'payment_status',
        'payment_method',
        'delivery_address',
        'delivery_phone',
        'delivery_coordinates',
        'special_instructions',
        'delivery_scheduled_at',
        'delivered_at',
        'cancellation_reason',
        'cancelled_by',
        'discount_amount',
        'tax_amount',
        'currency',
        'commission_amount',
        'seller_earnings',
        'platform_fee',
        'processed_at',
    ];

    protected $casts = [
        'unit_price' => 'float',
        'subtotal' => 'float',
        'delivery_fee' => 'float',
        'service_fee' => 'float',
        'total_amount' => 'float',
        'discount_amount' => 'float',
        'tax_amount' => 'float',
        'commission_amount' => 'float',
        'seller_earnings' => 'float',
        'platform_fee' => 'float',
        'quantity' => 'float',
        'delivery_coordinates' => 'array',
        'delivery_scheduled_at' => 'datetime',
        'delivered_at' => 'datetime',
        'processed_at' => 'datetime',
    ];

    // Order status constants
    const STATUS_PENDING = OrderStatus::Pending->value;
    const STATUS_CONFIRMED = OrderStatus::Confirmed->value;
    const STATUS_PROCESSING = OrderStatus::Processing->value;
    const STATUS_READY_FOR_DELIVERY = OrderStatus::ReadyForDelivery->value;
    const STATUS_DISPATCHED = OrderStatus::Dispatched->value;
    const STATUS_IN_TRANSIT = OrderStatus::InTransit->value;
    const STATUS_DELIVERED = OrderStatus::Delivered->value;
    const STATUS_COMPLETED = OrderStatus::Completed->value;
    const STATUS_CANCELLED = OrderStatus::Cancelled->value;
    const STATUS_REFUNDED = OrderStatus::Refunded->value;

    const PAYMENT_STATUS_PENDING = OrderPaymentStatus::Pending->value;
    const PAYMENT_STATUS_PAID = OrderPaymentStatus::Paid->value;
    const PAYMENT_STATUS_FAILED = OrderPaymentStatus::Failed->value;
    const PAYMENT_STATUS_REFUNDED = OrderPaymentStatus::Refunded->value;
    const PAYMENT_STATUS_PARTIAL = OrderPaymentStatus::Partial->value;

    const PAYMENT_METHOD_MOBILE_MONEY = PaymentMethod::MobileMoney->value;
    const PAYMENT_METHOD_BANK_TRANSFER = PaymentMethod::BankTransfer->value;
    const PAYMENT_METHOD_CARD = PaymentMethod::Card->value;
    const PAYMENT_METHOD_WALLET = PaymentMethod::Wallet->value;
    const PAYMENT_METHOD_CASH = PaymentMethod::Cash->value;

    // Relationships
    public function buyer()
    {
        return $this->belongsTo(User::class, 'buyer_id');
    }

    public function seller()
    {
        return $this->belongsTo(User::class, 'seller_id');
    }

    public function items()
    {
        return $this->hasMany(OrderItem::class);
    }

    public function orderItems()
    {
        return $this->hasMany(OrderItem::class);
    }

    public function product()
    {
        return $this->belongsTo(Product::class);
    }

    public function delivery()
    {
        return $this->hasOne(Delivery::class);
    }

    public function payment()
    {
        return $this->hasOne(Payment::class);
    }

    public function review()
    {
        return $this->hasOne(Review::class);
    }

    public function timeline()
    {
        return $this->hasMany(OrderTimeline::class);
    }

    public function cancelledBy()
    {
        return $this->belongsTo(User::class, 'cancelled_by');
    }

    // Scopes
    public function scopePending($query)
    {
        return $query->where('status', self::STATUS_PENDING);
    }

    public function scopeActive($query)
    {
        return $query->whereNotIn('status', [
            self::STATUS_COMPLETED,
            self::STATUS_CANCELLED,
            self::STATUS_REFUNDED
        ]);
    }

    public function scopeCompleted($query)
    {
        return $query->where('status', self::STATUS_COMPLETED);
    }

    public function scopePaid($query)
    {
        return $query->where('payment_status', self::PAYMENT_STATUS_PAID);
    }

    public function scopeByBuyer($query, $buyerId)
    {
        return $query->where('buyer_id', $buyerId);
    }

    public function scopeBySeller($query, $sellerId)
    {
        return $query->where('seller_id', $sellerId);
    }

    public function scopeToday($query)
    {
        return $query->whereDate('created_at', today());
    }

    public function scopeThisMonth($query)
    {
        return $query->whereMonth('created_at', now()->month)
            ->whereYear('created_at', now()->year);
    }

    // Accessors
    public function getStatusLabelAttribute()
    {
        $labels = [
            self::STATUS_PENDING => 'Pending',
            self::STATUS_CONFIRMED => 'Confirmed',
            self::STATUS_PROCESSING => 'Processing',
            self::STATUS_READY_FOR_DELIVERY => 'Ready for Delivery',
            self::STATUS_DISPATCHED => 'Dispatched',
            self::STATUS_IN_TRANSIT => 'In Transit',
            self::STATUS_DELIVERED => 'Delivered',
            self::STATUS_COMPLETED => 'Completed',
            self::STATUS_CANCELLED => 'Cancelled',
            self::STATUS_REFUNDED => 'Refunded',
        ];
        return $labels[$this->status] ?? ucwords(str_replace('_', ' ', $this->status));
    }

    public function getStatusColorAttribute()
    {
        $colors = [
            self::STATUS_PENDING => 'warning',
            self::STATUS_CONFIRMED => 'info',
            self::STATUS_PROCESSING => 'info',
            self::STATUS_READY_FOR_DELIVERY => 'primary',
            self::STATUS_DISPATCHED => 'primary',
            self::STATUS_IN_TRANSIT => 'primary',
            self::STATUS_DELIVERED => 'success',
            self::STATUS_COMPLETED => 'success',
            self::STATUS_CANCELLED => 'danger',
            self::STATUS_REFUNDED => 'secondary',
        ];
        return $colors[$this->status] ?? 'secondary';
    }

    public function getPaymentStatusLabelAttribute()
    {
        $labels = [
            self::PAYMENT_STATUS_PENDING => 'Pending',
            self::PAYMENT_STATUS_PAID => 'Paid',
            self::PAYMENT_STATUS_FAILED => 'Failed',
            self::PAYMENT_STATUS_REFUNDED => 'Refunded',
            self::PAYMENT_STATUS_PARTIAL => 'Partial',
        ];
        return $labels[$this->payment_status] ?? ucwords(str_replace('_', ' ', $this->payment_status));
    }

    public function getPaymentMethodLabelAttribute()
    {
        return ucwords(str_replace('_', ' ', $this->payment_method));
    }

    public function getFormattedTotalAttribute()
    {
        return $this->currency . ' ' . number_format($this->total_amount, 2);
    }

    public function getFormattedSubtotalAttribute()
    {
        return $this->currency . ' ' . number_format($this->subtotal, 2);
    }

    public function getFormattedDeliveryFeeAttribute()
    {
        return $this->currency . ' ' . number_format($this->delivery_fee, 2);
    }

    public function getItemsSummaryAttribute()
    {
        if ($this->relationLoaded('orderItems') && $this->orderItems->count() > 0) {
            return $this->orderItems->map(function ($item) {
                return $item->product->name . ' x ' . $item->quantity;
            })->implode(', ');
        }

        // Fallback for backward compatibility
        if ($this->product) {
            return $this->product->name . ' x ' . $this->quantity;
        }

        return 'N/A';
    }

    public function getDeliveryAddressDisplayAttribute()
    {
        return $this->delivery_address;
    }

    public function getEstimatedDeliveryAttribute()
    {
        if ($this->delivery_scheduled_at) {
            return $this->delivery_scheduled_at->format('M d, Y H:i');
        }
        return 'Not scheduled';
    }

    public function getCanCancelAttribute()
    {
        return $this->canCancel();
    }

    public function getApiResponseAttribute(): array
    {
        $orderItems = $this->orderItems->map(function ($item) {
            $product = $item->product;
            $images = $product ? $product->images : null;
            $productImage = '';

            if (is_array($images) && count($images) > 0) {
                $productImage = $images[0];
            } elseif (is_string($images)) {
                $decoded = json_decode($images, true);
                if (is_array($decoded) && count($decoded) > 0) {
                    $productImage = $decoded[0];
                } else {
                    $productImage = $images;
                }
            }

            return [
                'id' => $item->id,
                'product_id' => $item->product_id,
                'product_name' => $product ? $product->name : 'Unknown Product',
                'product_image' => $productImage,
                'quantity' => $item->quantity,
                'price' => $item->price,
                'subtotal' => $item->subtotal,
                'unit' => $item->unit ?? ($product ? $product->unit : null),
            ];
        });

        return [
            'id' => $this->id,
            'order_number' => $this->order_number,
            'total_amount' => (float) $this->total_amount,
            'status' => $this->status,
            'status_label' => $this->status_label,
            'payment_status' => $this->payment_status,
            'payment_method' => $this->payment_method,
            'delivery_address' => $this->delivery_address,
            'delivery_phone' => $this->delivery_phone ?? $this->buyer->phone ?? '',
            'created_at' => $this->created_at->toIso8601String(),
            'subtotal' => (float) $this->subtotal,
            'delivery_fee' => (float) $this->delivery_fee,
            'service_fee' => (float) $this->service_fee,
            'items' => $orderItems,
            'is_paid' => $this->payment_status === self::PAYMENT_STATUS_PAID,
            'eta' => $this->delivery_scheduled_at ? $this->delivery_scheduled_at->toIso8601String() : null,
            'special_instructions' => $this->special_instructions,
            'delivered_at' => $this->delivered_at ? $this->delivered_at->toIso8601String() : null,
            'can_cancel' => $this->canCancel(),
            // Buyer live tracker (additive): destination pin for OSM map.
            'delivery_coordinates' => $this->delivery_coordinates,
        ];
    }

    // Methods
    /**
     * Canonical order number: SD-YEAR-RANDOM6ALPHANUM (e.g. SD-2026-X7K9P2).
     * Single source of truth — checkout, services, admin and seeders use this.
     */
    public static function generateNumber(): string
    {
        do {
            $number = 'SD-' . date('Y') . '-' . strtoupper(Str::random(6));
        } while (self::withTrashed()->where('order_number', $number)->exists());

        return $number;
    }

    public function canCancel(): bool
    {
        return in_array($this->status, [
            self::STATUS_PENDING,
            self::STATUS_CONFIRMED,
            self::STATUS_PROCESSING
        ]);
    }

    public function canUpdateStatus(): bool
    {
        return !in_array($this->status, [
            self::STATUS_COMPLETED,
            self::STATUS_CANCELLED,
            self::STATUS_REFUNDED
        ]);
    }

    public function isPending(): bool
    {
        return $this->status === self::STATUS_PENDING;
    }

    public function isPaid(): bool
    {
        return $this->payment_status === self::PAYMENT_STATUS_PAID;
    }

    public function isCancelled(): bool
    {
        return $this->status === self::STATUS_CANCELLED;
    }

    public function isCompleted(): bool
    {
        return $this->status === self::STATUS_COMPLETED;
    }

    public function isDeliveryReady(): bool
    {
        return $this->status === self::STATUS_READY_FOR_DELIVERY;
    }

    public function markAsConfirmed()
    {
        $old = $this->status;
        $this->update([
            'status' => self::STATUS_CONFIRMED,
            'processed_at' => now(),
        ]);
        if ($old !== self::STATUS_CONFIRMED) {
            $fresh = $this->fresh() ?? $this;
            event(new OrderStatusChanged($fresh, $old, self::STATUS_CONFIRMED));
            dispatch(new SendOrderStatusNotification($fresh, $old, self::STATUS_CONFIRMED));
        }
    }

    public function markAsProcessing()
    {
        $old = $this->status;
        $this->update(['status' => self::STATUS_PROCESSING]);
        if ($old !== self::STATUS_PROCESSING) {
            $fresh = $this->fresh() ?? $this;
            event(new OrderStatusChanged($fresh, $old, self::STATUS_PROCESSING));
            dispatch(new SendOrderStatusNotification($fresh, $old, self::STATUS_PROCESSING));
        }
    }

    public function markAsReadyForDelivery()
    {
        $old = $this->status;
        $this->update(['status' => self::STATUS_READY_FOR_DELIVERY]);
        if ($old !== self::STATUS_READY_FOR_DELIVERY) {
            $fresh = $this->fresh() ?? $this;
            event(new OrderStatusChanged($fresh, $old, self::STATUS_READY_FOR_DELIVERY));
            dispatch(new SendOrderStatusNotification($fresh, $old, self::STATUS_READY_FOR_DELIVERY));
        }
    }

    public function markAsInTransit()
    {
        $old = $this->status;
        $this->update(['status' => self::STATUS_IN_TRANSIT]);
        if ($old !== self::STATUS_IN_TRANSIT) {
            $fresh = $this->fresh() ?? $this;
            event(new OrderStatusChanged($fresh, $old, self::STATUS_IN_TRANSIT));
            dispatch(new SendOrderStatusNotification($fresh, $old, self::STATUS_IN_TRANSIT));
        }
    }

    public function markAsDelivered()
    {
        $old = $this->status;
        $this->update([
            'status' => self::STATUS_DELIVERED,
            'delivered_at' => now(),
        ]);
        if ($old !== self::STATUS_DELIVERED) {
            $fresh = $this->fresh() ?? $this;
            event(new OrderStatusChanged($fresh, $old, self::STATUS_DELIVERED));
            dispatch(new SendOrderStatusNotification($fresh, $old, self::STATUS_DELIVERED));
        }
    }

    public function markAsCompleted()
    {
        $old = $this->status;
        $this->update([
            'status' => self::STATUS_COMPLETED,
            'processed_at' => now(),
        ]);
        if ($old !== self::STATUS_COMPLETED) {
            $fresh = $this->fresh() ?? $this;
            event(new OrderStatusChanged($fresh, $old, self::STATUS_COMPLETED));
            dispatch(new SendOrderStatusNotification($fresh, $old, self::STATUS_COMPLETED));
        }
    }

    public function markAsPaid()
    {
        $this->update([
            'payment_status' => self::PAYMENT_STATUS_PAID,
        ]);
    }

    public function getTimeline()
    {
        return $this->timeline()->orderBy('created_at', 'asc')->get();
    }

    public function getStatusHistory()
    {
        return $this->timeline()
            ->select('status', 'description', 'created_at')
            ->orderBy('created_at', 'asc')
            ->get();
    }

    // Boot
    protected static function boot()
    {
        parent::boot();

        static::creating(function (Order $order) {
            if (empty($order->currency)) {
                $order->currency = 'GHS';
            }

            // Fill missing settlement fields from SUBTOTAL (never from total_amount).
            // Callers that already set these (checkout / admin) are left alone.
            $subtotal = (float) ($order->subtotal ?? 0);
            if ($subtotal <= 0) {
                return;
            }

            if ($order->commission_amount === null) {
                $rate = \App\Services\Order\OrderFeeCalculator::commissionRateForSeller(
                    $order->seller_id ? (int) $order->seller_id : null
                );
                $order->commission_amount = round($subtotal * ($rate / 100), 2);
            }

            if ($order->seller_earnings === null) {
                $order->seller_earnings = max(
                    0,
                    round($subtotal - (float) $order->commission_amount, 2)
                );
            }

            if ($order->platform_fee === null) {
                // Platform keeps seller commission + buyer service fee
                $order->platform_fee = round(
                    (float) $order->commission_amount + (float) ($order->service_fee ?? 0),
                    2
                );
            }
        });

        static::created(function (Order $order) {
            // Avoid duplicate timeline if caller already logged (e.g. checkout / admin)
            if ($order->timeline()->exists()) {
                return;
            }

            OrderTimeline::log(
                $order,
                $order->status ?: self::STATUS_PENDING,
                'Order created successfully',
                ['total_amount' => $order->total_amount]
            );
        });

        // Order confirmed → push trip request to ONLINE drivers only.
        // Central hook so every confirm path (API, admin panel, wallet
        // checkout, payment jobs) dispatches without each caller
        // remembering to do it. Best-effort: never breaks the update.
        static::updated(function (Order $order) {
            try {
                if (!$order->wasChanged('status')) {
                    return;
                }
                if ($order->status !== self::STATUS_CONFIRMED) {
                    return;
                }
                app(\App\Services\Delivery\DeliveryService::class)
                    ->dispatchOnConfirmed($order->fresh() ?? $order);
            } catch (\Throwable $e) {
                \Illuminate\Support\Facades\Log::warning('Auto-dispatch on confirmed failed', [
                    'order_id' => $order->id,
                    'error' => $e->getMessage(),
                ]);
            }
        });
    }
}
