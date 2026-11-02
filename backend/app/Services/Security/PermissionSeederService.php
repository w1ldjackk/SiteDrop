<?php

namespace App\Services\Security;

use App\Models\Permission;
use App\Models\Role;
use App\Models\SellerProfile;
use App\Models\User;
use App\Models\UserProfile;
use Illuminate\Database\Seeder;

class PermissionSeederService extends Seeder
{
    /**
     * The console command instance.
     */
    protected $command;

    /**
     * @param \Illuminate\Console\Command $command
     */
    public function setCommand($command): void
    {
        $this->command = $command;
    }

    public function run(): void
    {
        // Reset cached permissions (critical for Spatie v3 + Laravel 12)
        app(\Spatie\Permission\PermissionRegistrar::class)->forgetCachedPermissions();
        $this->command->info('🚀 Seeding roles and permissions (clean architecture)...');

        // ====================== CREATE PERMISSIONS ======================
        $permissions = [
            // Dashboard & Analytics
            'view dashboard' => 'Dashboard & Analytics',
            'view analytics' => 'Dashboard & Analytics',

            // User Management
            'view users' => 'User Management',
            'create users' => 'User Management',
            'edit users' => 'User Management',
            'delete users' => 'User Management',
            'manage users' => 'User Management',

            // Role & Permission Management
            'manage roles' => 'Role & Permission Management',
            'manage permissions' => 'Role & Permission Management',

            // Site Management (construction sites)
            'view sites' => 'Site Management',
            'create sites' => 'Site Management',
            'edit sites' => 'Site Management',
            'delete sites' => 'Site Management',
            'manage sites' => 'Site Management',

            // Truck/Vehicle Management
            'view trucks' => 'Truck & Vehicle Management',
            'create trucks' => 'Truck & Vehicle Management',
            'edit trucks' => 'Truck & Vehicle Management',
            'delete trucks' => 'Truck & Vehicle Management',
            'manage trucks' => 'Truck & Vehicle Management',

            // Product Management
            'view products' => 'Product Management',
            'create products' => 'Product Management',
            'edit products' => 'Product Management',
            'delete products' => 'Product Management',
            'manage products' => 'Product Management',

            // Order Management (admin full CRUD + workflow)
            'view orders' => 'Order Management',
            'create orders' => 'Order Management',
            'edit orders' => 'Order Management',
            'delete orders' => 'Order Management',
            'process orders' => 'Order Management',
            'cancel orders' => 'Order Management',
            'bulk update orders' => 'Order Management',
            'manage orders' => 'Order Management',

            // Payment Management
            'view payments' => 'Payment Management',
            'process payments' => 'Payment Management',
            'refund payments' => 'Payment Management',
            'manage payments' => 'Payment Management',

            // Delivery Management
            'view deliveries' => 'Delivery Management',
            'create deliveries' => 'Delivery Management',
            'assign deliveries' => 'Delivery Management',
            'track deliveries' => 'Delivery Management',
            'complete deliveries' => 'Delivery Management',
            'manage deliveries' => 'Delivery Management',

            // Seller Management (admin full CRUD + moderation)
            'view sellers' => 'Seller Management',
            'create sellers' => 'Seller Management',
            'edit sellers' => 'Seller Management',
            'delete sellers' => 'Seller Management',
            'approve sellers' => 'Seller Management',
            'reject sellers' => 'Seller Management',
            'suspend sellers' => 'Seller Management',
            'activate sellers' => 'Seller Management',
            'view seller documents' => 'Seller Management',
            'manage sellers' => 'Seller Management',

            // Review Management
            'view reviews' => 'Review Management',
            'moderate reviews' => 'Review Management',
            'delete reviews' => 'Review Management',
            'create reviews' => 'Review Management',

            // Reports & Analytics
            'view reports' => 'Reports & Analytics',
            'export reports' => 'Reports & Analytics',
            'view financial reports' => 'Reports & Analytics',

            // Settings
            'manage settings' => 'Settings',
            'manage commission' => 'Settings',
            'manage fees' => 'Settings',

            // Wallet Management
            'view wallets' => 'Wallet Management',
            'manage wallets' => 'Wallet Management',
            'view transactions' => 'Wallet Management',

            // Auth & OTP
            'manage otp' => 'Auth & Security',
            'manage auth' => 'Auth & Security',

            // Cart & Checkout
            'view cart' => 'Cart & Checkout',
            'manage cart' => 'Cart & Checkout',
            'create orders from cart' => 'Cart & Checkout',

            // Profile & Identity
            'manage profile' => 'Profile & Identity',
            'verify identity' => 'Profile & Identity',

            // Seller Onboarding (critical for sellers)
            'manage seller onboarding' => 'Seller Onboarding',
            'upload documents' => 'Seller Onboarding',
            'submit for review' => 'Seller Onboarding',

            // Admin-specific
            'manage admin' => 'Admin',
            'view seller status' => 'Admin',

            // Activity logs (admin audit trail)
            'view activity logs' => 'Activity Logs',
            'delete activity logs' => 'Activity Logs',
        ];

        // Create / refresh all permissions with section (idempotent)
        foreach ($permissions as $name => $section) {
            Permission::updateOrCreate(
                [
                    'name' => $name,
                    'guard_name' => 'web',
                ],
                [
                    'section' => $section,
                ]
            );
        }
        $this->command->info('✅ All permissions created successfully with sections.');

        // ====================== CREATE ROLES ======================
        // 1. Super Admin (full system access - all permissions automatically granted)
        $this->createRole('super-admin', Permission::all());

        // 2. Admin
        $adminPermissions = [
            'view dashboard',
            'view analytics',
            'view users',
            'create users',
            'edit users',
            'delete users',
            'manage users',
            'manage roles',
            'manage permissions',
            'view sites',
            'edit sites',
            'view trucks',
            'edit trucks',
            'view products',
            'view orders',
            'create orders',
            'edit orders',
            'delete orders',
            'process orders',
            'cancel orders',
            'bulk update orders',
            'manage orders',
            'view payments',
            'process payments',
            'refund payments',
            'manage payments',
            'view deliveries',
            'assign deliveries',
            'manage deliveries',
            'view sellers',
            'create sellers',
            'edit sellers',
            'delete sellers',
            'approve sellers',
            'reject sellers',
            'suspend sellers',
            'activate sellers',
            'view seller documents',
            'manage sellers',
            'view reviews',
            'moderate reviews',
            'delete reviews',
            'view reports',
            'export reports',
            'view financial reports',
            'manage settings',
            'view wallets',
            'view transactions',
            'manage admin',
            'view seller status',
            'view activity logs',
            'delete activity logs',
        ];
        $this->createRole('admin', $adminPermissions);

        // 3. Operations Manager
        $opsPermissions = [
            'view dashboard',
            'view analytics',
            'view sites',
            'view trucks',
            'view orders',
            'process orders',
            'cancel orders',
            'view payments',
            'view deliveries',
            'assign deliveries',
            'track deliveries',
            'complete deliveries',
            'view sellers',
            'view seller documents',
            'approve sellers',
            'reject sellers',
            'suspend sellers',
            'activate sellers',
            'view reports',
            'export reports',
            'view activity logs',
        ];
        $this->createRole('ops-manager', $opsPermissions);

        // 4. Seller
        $sellerPermissions = [
            'view dashboard',
            'view sites',
            'view trucks',
            'create trucks',
            'edit trucks',
            'view products',
            'create products',
            'edit products',
            'delete products',
            'view orders',
            'edit orders',
            'view payments',
            'view wallets',
            'view transactions',
            'view reviews',
            'view cart',
            'manage cart',
            'create orders from cart',
            'manage seller onboarding',
            'upload documents',
            'submit for review',
        ];
        $this->createRole('seller', $sellerPermissions);

        // 5. Buyer
        $buyerPermissions = [
            'view dashboard',
            'view sites',
            'create sites',
            'edit sites',
            'view products',
            'view orders',
            'create orders',
            'cancel orders',
            'view payments',
            'view wallets',
            'view transactions',
            'create reviews',
            'view cart',
            'manage cart',
            'create orders from cart',
        ];
        $this->createRole('buyer', $buyerPermissions);

        // 6. Driver
        $driverPermissions = [
            'view dashboard',
            'view trucks',
            'edit trucks',
            'view orders',
            'view deliveries',
            'track deliveries',
            'complete deliveries',
            'view wallets',
            'view transactions',
        ];
        $this->createRole('driver', $driverPermissions);

        // ====================== CREATE DEFAULT USERS ======================
        $this->createDefaultUsers();
        $this->command->info('🎉 Roles, permissions, and default users seeded successfully!');
        $this->command->info(' (Clean Architecture + Laravel 12 + Spatie v3 + Guard "web" + Section column)');
    }

    /**
     * Helper: Create or update a role with its permissions
     */
    private function createRole(string $name, iterable $permissions): void
    {
        $role = Role::firstOrCreate([
            'name' => $name,
            'guard_name' => 'web',
        ]);

        $permCollection = is_array($permissions)
            ? collect($permissions)->map(fn($p) => Permission::firstOrCreate(['name' => $p, 'guard_name' => 'web']))
            : collect($permissions);

        $role->syncPermissions($permCollection);
    }

    /**
     * Create default users with profiles + SellerProfile for sample seller
     */
    private function createDefaultUsers(): void
    {
        // Super Admin
        $this->createUserWithProfileAndDetails(
            'superadmin@sitedrop.gh',
            'Super Admin',
            'superadmin@sitedrop.gh',
            'password',
            '233501234567',
            'super-admin',
            [
                'first_name' => 'Super',
                'last_name' => 'Admin',
                'address' => '123 Admin St, City, Country',
                'phone' => '233501234567',
            ]
        );

        // Admin
        $this->createUserWithProfileAndDetails(
            'admin@sitedrop.gh',
            'Admin User',
            'admin@sitedrop.gh',
            'password',
            '233501234568',
            'admin',
            [
                'first_name' => 'Admin',
                'last_name' => 'User',
                'address' => '456 Admin Rd, City, Country',
                'phone' => '233501234568',
            ]
        );

        // Operations Manager
        $this->createUserWithProfileAndDetails(
            'ops@sitedrop.gh',
            'Operations Manager',
            'ops@sitedrop.gh',
            'password',
            '233501234569',
            'admin',
            [
                'first_name' => 'Operations',
                'last_name' => 'Manager',
                'address' => '789 Ops Ave, City, Country',
                'phone' => '233501234569',
            ]
        );

        // Sample Seller (full SellerProfile)
        $sellerUser = $this->createUserWithProfileAndDetails(
            'seller@sitedrop.gh',
            'Sample Seller',
            'seller@sitedrop.gh',
            'password',
            '233501234570',
            'seller',
            [
                'first_name' => 'Sample',
                'last_name' => 'Seller',
                'address' => '101 Seller Blvd, City, Country',
                'phone' => '233501234570',
            ]
        );
        if ($sellerUser) {
            SellerProfile::create([
                'user_id' => $sellerUser->id,
                'business_name' => 'Sample Business Ltd',
                'business_type' => SellerProfile::BUSINESS_TYPE_SUPPLIER,
                'business_registration_number' => 'REG123456',
                'tax_id' => 'TAX7890',
                'business_phone' => '233501234570',
                'business_email' => 'seller@sitedrop.gh',
                'website' => 'https://samplebusiness.com',
                'description' => 'Leading supplier of quality goods.',
                'logo_url' => 'https://via.placeholder.com/150',
                'cover_image_url' => 'https://via.placeholder.com/600x200',
                'status' => SellerProfile::STATUS_APPROVED,
                'service_areas' => ['Accra', 'Kumasi', 'Takoradi'],
                'commission_rate' => 12.50,
                'minimum_order_amount' => 100.00,
                'delivery_radius_km' => 20.00,
                'bank_account_name' => 'Sample Business Ltd',
                'bank_account_number' => '1234567890',
                'bank_name' => 'Bank of Example',
                'bank_branch' => 'Main Branch',
                'email_verified' => true,
                'approved_at' => now(),
                'rejected_reason' => null,
                'verification_documents' => [],
                'social_links' => [],
                'business_hours' => [],
            ]);
        }

        // Sample Buyer
        $this->createUserWithProfileAndDetails(
            'buyer@sitedrop.gh',
            'Sample Buyer',
            'buyer@sitedrop.gh',
            'password',
            '233501234571',
            'buyer',
            [
                'first_name' => 'Sample',
                'last_name' => 'Buyer',
                'address' => '202 Buyer St, City, Country',
                'phone' => '233501234571',
            ]
        );

        // Sample Driver
        $this->createUserWithProfileAndDetails(
            'driver@sitedrop.gh',
            'Sample Driver',
            'driver@sitedrop.gh',
            'password',
            '233501234572',
            'driver',
            [
                'first_name' => 'Sample',
                'last_name' => 'Driver',
                'address' => '303 Driver Rd, City, Country',
                'phone' => '233501234572',
            ]
        );
    }

    /**
     * Helper: Create user + profile + assign role
     */
    private function createUserWithProfileAndDetails(
        string $email,
        string $name,
        string $userEmail,
        string $password,
        string $phone,
        string $role,
        array $profileData
    ): ?User {
        $user = User::firstOrCreate(
            ['email' => $userEmail],
            [
                'name' => $name,
                'password' => bcrypt($password),
                'phone' => $phone,
                'phone_verified' => true,
                'role' => $role,
                'email_verified_at' => now(),
            ]
        );
        $user->assignRole($role);

        // Profile now uses ONLY the fields that actually exist in the profiles table
        UserProfile::firstOrCreate(['user_id' => $user->id], [
            'first_name' => $profileData['first_name'] ?? null,
            'last_name' => $profileData['last_name'] ?? null,
            'address' => $profileData['address'] ?? null,
        ]);

        return $user;
    }
}
