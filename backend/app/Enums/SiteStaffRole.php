<?php

namespace App\Enums;

enum SiteStaffRole: string
{
    use EnumHelpers;

    case SiteManager = 'site_manager';
    case Supervisor = 'supervisor';
    case Foreman = 'foreman';
    case SafetyOfficer = 'safety_officer';
    case QualityControl = 'quality_control';
    case Operator = 'operator';
    case Laborer = 'laborer';
    case Other = 'other';
}
