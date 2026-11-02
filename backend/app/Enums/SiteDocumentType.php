<?php

namespace App\Enums;

enum SiteDocumentType: string
{
    use EnumHelpers;

    case Permit = 'permit';
    case Contract = 'contract';
    case Blueprint = 'blueprint';
    case Report = 'report';
    case Invoice = 'invoice';
    case Insurance = 'insurance';
    case Certificate = 'certificate';
    case Other = 'other';
}
