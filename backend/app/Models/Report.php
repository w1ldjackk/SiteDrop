<?php
// app/Models/Report.php

namespace App\Models;

use App\Enums\ReportFormat;
use App\Enums\ReportStatus;
use App\Enums\ReportType;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Report extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'title',
        'type', // sales, orders, deliveries, revenue, performance
        'period', // daily, weekly, monthly, quarterly, yearly
        'date_range_start',
        'date_range_end',
        'filters',
        'data',
        'file_path',
        'status', // generating, ready, failed
        'format', // pdf, excel, csv
        'schedule',
        'last_generated_at',
        'generation_time_seconds',
        'error_message',
    ];

    protected $casts = [
        'filters' => 'array',
        'data' => 'array',
        'schedule' => 'array',
        'date_range_start' => 'datetime',
        'date_range_end' => 'datetime',
        'last_generated_at' => 'datetime',
        'generation_time_seconds' => 'integer',
    ];

    // Constants
    const TYPE_SALES = ReportType::Sales->value;
    const TYPE_ORDERS = ReportType::Orders->value;
    const TYPE_DELIVERIES = ReportType::Deliveries->value;
    const TYPE_REVENUE = ReportType::Revenue->value;
    const TYPE_PERFORMANCE = ReportType::Performance->value;

    const STATUS_GENERATING = ReportStatus::Generating->value;
    const STATUS_READY = ReportStatus::Ready->value;
    const STATUS_FAILED = ReportStatus::Failed->value;

    const FORMAT_PDF = ReportFormat::Pdf->value;
    const FORMAT_EXCEL = ReportFormat::Excel->value;
    const FORMAT_CSV = ReportFormat::Csv->value;

    // Relationships
    public function user()
    {
        return $this->belongsTo(User::class);
    }

    // Scopes
    public function scopeReady($query)
    {
        return $query->where('status', self::STATUS_READY);
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

    public function getPeriodLabelAttribute()
    {
        return ucwords(str_replace('_', ' ', $this->period));
    }

    // Methods
    public function markAsReady()
    {
        $this->update([
            'status' => self::STATUS_READY,
            'last_generated_at' => now(),
        ]);
    }

    public function markAsFailed($error)
    {
        $this->update([
            'status' => self::STATUS_FAILED,
            'error_message' => $error,
        ]);
    }
}
