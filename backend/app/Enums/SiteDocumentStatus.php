<?php

namespace App\Enums;

enum SiteDocumentStatus: string
{
    use EnumHelpers;

    case Draft = 'draft';
    case Active = 'active';
    case Archived = 'archived';
    case Expired = 'expired';
    case Rejected = 'rejected';
}
