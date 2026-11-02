<?php
// app/Models/SiteMaterial.php

namespace App\Models;

use App\Enums\SiteMaterialStatus;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class SiteMaterial extends Model
{
    use HasFactory;

    protected $fillable = [
        'site_id',
        'supplier_id',
        'material_name',
        'quantity_needed',
        'quantity_delivered',
        'unit',
        'estimated_cost',
        'actual_cost',
        'delivery_status',
        'ordered_at',
        'expected_delivery_date',
        'delivered_at',
        'notes',
    ];

    protected $casts = [
        'quantity_needed' => 'float',
        'quantity_delivered' => 'float',
        'estimated_cost' => 'float',
        'actual_cost' => 'float',
        'ordered_at' => 'datetime',
        'expected_delivery_date' => 'datetime',
        'delivered_at' => 'datetime',
    ];

    // Constants
    const STATUS_PENDING = SiteMaterialStatus::Pending->value;
    const STATUS_PARTIAL = SiteMaterialStatus::Partial->value;
    const STATUS_COMPLETED = SiteMaterialStatus::Completed->value;

    // Relationships
    public function site()
    {
        return $this->belongsTo(Site::class);
    }

    public function supplier()
    {
        return $this->belongsTo(User::class, 'supplier_id');
    }

    // Scopes
    public function scopePending($query)
    {
        return $query->where('delivery_status', self::STATUS_PENDING);
    }

    public function scopeCompleted($query)
    {
        return $query->where('delivery_status', self::STATUS_COMPLETED);
    }

    // Accessors
    public function getStatusLabelAttribute()
    {
        return ucwords(str_replace('_', ' ', $this->delivery_status));
    }

    public function getRemainingQuantityAttribute()
    {
        return $this->quantity_needed - $this->quantity_delivered;
    }

    public function getProgressAttribute()
    {
        if ($this->quantity_needed > 0) {
            return min(100, round(($this->quantity_delivered / $this->quantity_needed) * 100));
        }
        return 0;
    }

    // Methods
    public function updateDelivery($quantityDelivered)
    {
        $this->quantity_delivered += $quantityDelivered;

        if ($this->quantity_delivered >= $this->quantity_needed) {
            $this->delivery_status = self::STATUS_COMPLETED;
            $this->delivered_at = now();
        } else {
            $this->delivery_status = self::STATUS_PARTIAL;
        }

        $this->save();
    }

    public function isFullyDelivered(): bool
    {
        return $this->delivery_status === self::STATUS_COMPLETED;
    }
}
