<?php
// app/Models/OrderItem.php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class OrderItem extends Model
{
    use HasFactory;

    protected $fillable = [
        'order_id',
        'product_id',
        'quantity',
        'price',
        'subtotal',
        'variations',
        'unit',
    ];

    protected $casts = [
        'variations' => 'array',
        'price' => 'decimal:2',
        'subtotal' => 'decimal:2',
        'quantity' => 'float',
    ];

    public function order(): BelongsTo
    {
        return $this->belongsTo(Order::class);
    }

    public function product(): BelongsTo
    {
        return $this->belongsTo(Product::class);
    }

    // Accessor for formatted price
    public function getFormattedPriceAttribute(): string
    {
        return 'GHS ' . number_format($this->price, 2);
    }

    public function getFormattedSubtotalAttribute(): string
    {
        return 'GHS ' . number_format($this->subtotal, 2);
    }
}
