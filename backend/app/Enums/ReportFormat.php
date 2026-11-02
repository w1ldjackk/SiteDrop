<?php

namespace App\Enums;

enum ReportFormat: string
{
    use EnumHelpers;

    case Pdf = 'pdf';
    case Excel = 'excel';
    case Csv = 'csv';
}
