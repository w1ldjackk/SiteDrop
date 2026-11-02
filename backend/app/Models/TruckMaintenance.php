<?php
// app/Models/TruckMaintenance.php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class TruckMaintenance extends Model
{
    protected $fillable = [
        'truck_id',
        'maintenance_type',
        'description',
        'cost',
        'performed_at',
        'performed_by',
        'notes',
        'mileage_at_service',
        'next_service_mileage',
        'status',
    ];

    protected $casts = [
        'cost' => 'float',
        'performed_at' => 'datetime',
        'mileage_at_service' => 'float',
        'next_service_mileage' => 'float',
    ];

    public function truck()
    {
        return $this->belongsTo(Truck::class);
    }

    public function performedBy()
    {
        return $this->belongsTo(User::class, 'performed_by');
    }
}
