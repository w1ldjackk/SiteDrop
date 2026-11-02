<?php

namespace App\Enums;

enum SiteDocumentAccess: string
{
    use EnumHelpers;

    case Public = 'public';
    case Private = 'private';
    case Restricted = 'restricted';
}
