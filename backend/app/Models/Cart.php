<?php
// app/Models/Cart.php

namespace App\Models;

use App\Models\CartItem;
use App\Models\Product;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Cart extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'session_id',
        'status', // active, abandoned, converted
        'expires_at',
    ];

    protected $casts = [
        'expires_at' => 'datetime',
    ];

    // Relationships
    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function items()
    {
        return $this->hasMany(CartItem::class);
    }

    // Scopes
    public function scopeActive($query)
    {
        return $query->where('status', 'active');
    }

    // Accessors
    public function getTotalAttribute()
    {
        return $this->items->sum(function ($item) {
            return $item->quantity * $item->price;
        });
    }

    public function getItemCountAttribute()
    {
        return $this->items->sum('quantity');
    }

    // Methods
    public function addItem($productId, $quantity = 1, $variations = null)
    {
        $existingItem = $this->items()->where('product_id', $productId)->first();

        if ($existingItem) {
            $existingItem->update([
                'quantity' => $existingItem->quantity + $quantity,
            ]);
            return $existingItem;
        }

        $product = Product::find($productId);
        return $this->items()->create([
            'product_id' => $productId,
            'quantity' => $quantity,
            'price' => $product->price_per_unit,
            'variations' => $variations,
        ]);
    }

    public function removeItem($itemId)
    {
        return $this->items()->where('id', $itemId)->delete();
    }

    public function clear()
    {
        return $this->items()->delete();
    }

    public function convertToOrder()
    {
        $this->update(['status' => 'converted']);
        // Trigger order creation logic
    }
}
