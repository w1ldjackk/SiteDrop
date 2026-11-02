<?php
// app/Exports/OrdersExport.php

namespace App\Exports;

use App\Models\Order;
use Maatwebsite\Excel\Concerns\FromQuery;
use Maatwebsite\Excel\Concerns\WithHeadings;
use Maatwebsite\Excel\Concerns\WithMapping;
use Maatwebsite\Excel\Concerns\WithStyles;
use PhpOffice\PhpSpreadsheet\Worksheet\Worksheet;

class OrdersExport implements FromQuery, WithHeadings, WithMapping, WithStyles
{
    protected $filters;

    public function __construct($filters = [])
    {
        $this->filters = $filters;
    }

    public function query()
    {
        $query = Order::with(['buyer', 'seller', 'product']);

        if (isset($this->filters['date_from'])) {
            $query->whereDate('created_at', '>=', $this->filters['date_from']);
        }

        if (isset($this->filters['date_to'])) {
            $query->whereDate('created_at', '<=', $this->filters['date_to']);
        }

        if (isset($this->filters['status'])) {
            $query->where('status', $this->filters['status']);
        }

        return $query;
    }

    public function headings(): array
    {
        return [
            'Order #',
            'Buyer',
            'Seller',
            'Product',
            'Quantity',
            'Unit Price',
            'Subtotal',
            'Delivery Fee',
            'Total',
            'Status',
            'Payment Status',
            'Created At',
            'Delivered At',
        ];
    }

    public function map($order): array
    {
        return [
            $order->order_number,
            $order->buyer->name ?? 'N/A',
            $order->seller->name ?? 'N/A',
            $order->product->name ?? 'N/A',
            $order->quantity,
            number_format($order->unit_price, 2),
            number_format($order->subtotal, 2),
            number_format($order->delivery_fee, 2),
            number_format($order->total_amount, 2),
            $order->status_label,
            $order->payment_status_label,
            $order->created_at->format('Y-m-d H:i'),
            $order->delivered_at?->format('Y-m-d H:i') ?? 'N/A',
        ];
    }

    public function styles(Worksheet $sheet)
    {
        return [
            1 => ['font' => ['bold' => true]],
        ];
    }
}
