<?php

namespace App\Enums;

enum ReportType: string
{
    use EnumHelpers;

    case Sales = 'sales';
    case Orders = 'orders';
    case Deliveries = 'deliveries';
    case Revenue = 'revenue';
    case Performance = 'performance';
}
