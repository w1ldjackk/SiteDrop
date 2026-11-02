<?php

namespace App\Enums;

enum ReportStatus: string
{
    use EnumHelpers;

    case Generating = 'generating';
    case Ready = 'ready';
    case Failed = 'failed';
}
