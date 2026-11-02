<?php

namespace App\Enums;

/**
 * Primary application roles (legacy users.role + Spatie role names).
 */
enum UserRole: string
{
    use EnumHelpers;

    case SuperAdmin = 'super-admin';
    case Admin = 'admin';
    case Buyer = 'buyer';
    case Seller = 'seller';
    case Driver = 'driver';
    case OpsManager = 'ops-manager';

    public function homePath(): string
    {
        return match ($this) {
            // ops-manager shares the admin web area
            self::SuperAdmin, self::Admin, self::OpsManager => '/admin',
            default => '/'.$this->value,
        };
    }

    /**
     * Route file / URL area for this role (admin, buyer, seller, driver).
     */
    public function routeFile(): string
    {
        return match ($this) {
            self::SuperAdmin, self::OpsManager => 'admin',
            default => $this->value,
        };
    }

    /**
     * Roles that have a dedicated web route file/area.
     *
     * @return list<self>
     */
    public static function webAreas(): array
    {
        return [
            self::Admin,
            self::Buyer,
            self::Seller,
            self::Driver,
        ];
    }

    /** Admin panel roles (admin.php), including ops. */
    public function isAdminArea(): bool
    {
        return match ($this) {
            self::SuperAdmin, self::Admin, self::OpsManager => true,
            default => false,
        };
    }

    public function isAdmin(): bool
    {
        return $this->isAdminArea();
    }

    public static function fromMixed(self|string $role): self
    {
        if ($role instanceof self) {
            return $role;
        }

        $normalized = strtolower(str_replace([' ', '_'], '-', $role));

        return self::tryFrom($normalized) ?? self::Buyer;
    }
}
