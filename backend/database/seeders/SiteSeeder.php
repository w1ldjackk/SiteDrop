<?php
// database/seeders/SiteSeeder.php

namespace Database\Seeders;

use App\Models\Site;
use App\Models\SiteDocument;
use App\Models\SiteMaterial;
use App\Models\SiteStaff;
use App\Models\SiteStatusLog;
use App\Models\SiteVisit;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class SiteSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        $this->command->info('🏗️ Seeding sites and related data...');

        // ====================== TRUNCATE TABLES ======================
        $this->command->info('   - Clearing existing site data...');

        // Disable foreign key checks for truncation
        DB::statement('SET FOREIGN_KEY_CHECKS=0');

        SiteStatusLog::truncate();
        SiteVisit::truncate();
        SiteDocument::truncate();
        SiteStaff::truncate();
        SiteMaterial::truncate();
        Site::truncate();

        DB::statement('SET FOREIGN_KEY_CHECKS=1');

        $this->command->info('   - Existing site data cleared.');

        // Get users from PermissionSeederService
        $buyer = User::where('email', 'buyer@sitedrop.gh')->first();
        $seller = User::where('email', 'seller@sitedrop.gh')->first();
        $admin = User::where('email', 'admin@sitedrop.gh')->first();
        $driver = User::where('email', 'driver@sitedrop.gh')->first();

        if (!$buyer) {
            $this->command->error('❌ Buyer user not found. Please run PermissionSeederService first.');
            return;
        }

        // Define sites
        $sites = [
            [
                'user_id' => $buyer->id,
                'name' => 'Accra Central Construction Site',
                'address' => '123 Liberation Road, Accra Central, Ghana',
                'coordinates' => ['lat' => 5.6037, 'lng' => -0.1870],
                'contact_person' => 'John Mensah',
                'contact_phone' => '233501234573',
                'site_photos' => [
                    '/assets/img/seed/site-accra-1.png',
                    '/assets/img/seed/site-accra-2.png',
                ],
                'description' => 'Large-scale commercial construction project in the heart of Accra. Includes office complex and retail spaces.',
                'site_type' => Site::SITE_TYPE_CONSTRUCTION,
                'status' => Site::STATUS_ACTIVE,
                'priority_level' => Site::PRIORITY_HIGH,
                'size_sq_meters' => 2500.00,
                'budget' => 2500000.00,
                'materials_needed' => [
                    ['material' => 'sand', 'quantity' => 500, 'unit' => 'tons'],
                    ['material' => 'gravel', 'quantity' => 300, 'unit' => 'tons'],
                    ['material' => 'cement_blocks', 'quantity' => 5000, 'unit' => 'pieces'],
                    ['material' => 'steel_rebar', 'quantity' => 200, 'unit' => 'tons'],
                ],
                'project_start_date' => '2024-01-15 08:00:00',
                'estimated_completion_date' => '2025-06-30 17:00:00',
                'site_manager_id' => $seller ? $seller->id : null,
                'supervisor_id' => $driver ? $driver->id : null,
                'access_notes' => 'Access via main gate. Security guard on duty 24/7. All visitors must sign in.',
                'security_requirements' => 'Hard hat and safety boots required. High visibility vest mandatory.',
                'site_code' => 'SITE2024ACC001',
            ],
            [
                'user_id' => $buyer->id,
                'name' => 'Tema Industrial Area Development',
                'address' => 'Industrial Area, Tema, Ghana',
                'coordinates' => ['lat' => 5.6685, 'lng' => -0.0184],
                'contact_person' => 'Ama Osei',
                'contact_phone' => '233501234574',
                'site_photos' => [
                    '/assets/img/seed/site-tema-1.png',
                ],
                'description' => 'Industrial development project including warehouses and manufacturing facilities.',
                'site_type' => Site::SITE_TYPE_CONSTRUCTION,
                'status' => Site::STATUS_PLANNING,
                'priority_level' => Site::PRIORITY_MEDIUM,
                'size_sq_meters' => 5000.00,
                'budget' => 5000000.00,
                'materials_needed' => [
                    ['material' => 'sand', 'quantity' => 800, 'unit' => 'tons'],
                    ['material' => 'stones', 'quantity' => 600, 'unit' => 'tons'],
                    ['material' => 'cement', 'quantity' => 1000, 'unit' => 'bags'],
                ],
                'project_start_date' => '2024-06-01 08:00:00',
                'estimated_completion_date' => '2025-12-31 17:00:00',
                'site_manager_id' => $admin ? $admin->id : null,
                'supervisor_id' => null,
                'access_notes' => 'Need site access pass from main office. No entry without authorization.',
                'security_requirements' => 'Full PPE required. Site induction mandatory for all visitors.',
                'site_code' => 'SITE2024TMA001',
            ],
            [
                'user_id' => $buyer->id,
                'name' => 'Kwabenya Quarry Site',
                'address' => 'Kwabenya, Greater Accra, Ghana',
                'coordinates' => ['lat' => 5.7200, 'lng' => -0.2300],
                'contact_person' => 'Kwame Asante',
                'contact_phone' => '233501234575',
                'site_photos' => [
                    '/assets/img/seed/site-quarry.png',
                ],
                'description' => 'Active quarry operation supplying construction materials to Accra and surrounding regions.',
                'site_type' => Site::SITE_TYPE_QUARRY,
                'status' => Site::STATUS_ACTIVE,
                'priority_level' => Site::PRIORITY_HIGH,
                'size_sq_meters' => 10000.00,
                'budget' => 10000000.00,
                'materials_needed' => [
                    ['material' => 'stones', 'quantity' => 1000, 'unit' => 'tons'],
                    ['material' => 'gravel', 'quantity' => 800, 'unit' => 'tons'],
                    ['material' => 'sharp_sand', 'quantity' => 500, 'unit' => 'tons'],
                ],
                'project_start_date' => '2023-06-01 06:00:00',
                'estimated_completion_date' => '2025-12-31 18:00:00',
                'site_manager_id' => $seller ? $seller->id : null,
                'supervisor_id' => null,
                'access_notes' => 'Heavy vehicle access only. Check in at security gate.',
                'security_requirements' => 'Quarry safety regulations apply. Hard hat, safety boots, and high-visibility vest required.',
                'site_code' => 'SITE2023KWA001',
            ],
            [
                'user_id' => $buyer->id,
                'name' => 'Spintex Residential Complex',
                'address' => 'Spintex Road, Accra, Ghana',
                'coordinates' => ['lat' => 5.6400, 'lng' => -0.1700],
                'contact_person' => 'Esi Tetteh',
                'contact_phone' => '233501234576',
                'site_photos' => [
                    '/assets/img/seed/site-residential.png',
                ],
                'description' => 'Luxury residential complex with 50 units including penthouses and garden apartments.',
                'site_type' => Site::SITE_TYPE_CONSTRUCTION,
                'status' => Site::STATUS_ON_HOLD,
                'priority_level' => Site::PRIORITY_MEDIUM,
                'size_sq_meters' => 3000.00,
                'budget' => 3500000.00,
                'materials_needed' => [
                    ['material' => 'sand', 'quantity' => 400, 'unit' => 'tons'],
                    ['material' => 'cement_blocks', 'quantity' => 3000, 'unit' => 'pieces'],
                    ['material' => 'roofing_sheets', 'quantity' => 500, 'unit' => 'sheets'],
                    ['material' => 'paint', 'quantity' => 200, 'unit' => 'gallons'],
                ],
                'project_start_date' => '2024-03-01 08:00:00',
                'estimated_completion_date' => '2025-09-30 17:00:00',
                'site_manager_id' => null,
                'supervisor_id' => null,
                'access_notes' => 'Site currently on hold. Contact project manager for access.',
                'security_requirements' => 'Security guard on site. No unauthorized entry.',
                'site_code' => 'SITE2024SPI001',
            ],
            [
                'user_id' => $buyer->id,
                'name' => 'Kumasi Central Market Renovation',
                'address' => 'Kumasi Central, Ashanti Region, Ghana',
                'coordinates' => ['lat' => 6.6885, 'lng' => -1.6244],
                'contact_person' => 'Kofi Owusu',
                'contact_phone' => '233501234577',
                'site_photos' => [
                    '/assets/img/seed/site-kumasi.png',
                ],
                'description' => 'Renovation and expansion of Kumasi Central Market to improve facilities for traders.',
                'site_type' => Site::SITE_TYPE_CONSTRUCTION,
                'status' => Site::STATUS_ACTIVE,
                'priority_level' => Site::PRIORITY_HIGH,
                'size_sq_meters' => 8000.00,
                'budget' => 8000000.00,
                'materials_needed' => [
                    ['material' => 'sand', 'quantity' => 600, 'unit' => 'tons'],
                    ['material' => 'stones', 'quantity' => 400, 'unit' => 'tons'],
                    ['material' => 'cement_blocks', 'quantity' => 8000, 'unit' => 'pieces'],
                    ['material' => 'steel_rebar', 'quantity' => 300, 'unit' => 'tons'],
                ],
                'project_start_date' => '2024-02-01 07:00:00',
                'estimated_completion_date' => '2025-08-31 18:00:00',
                'site_manager_id' => $admin ? $admin->id : null,
                'supervisor_id' => null,
                'access_notes' => 'Site in busy market area. Early morning deliveries only.',
                'security_requirements' => 'Hard hat and safety boots required. Market safety protocols apply.',
                'site_code' => 'SITE2024KUM001',
            ],
        ];

        // Create sites
        $createdCount = 0;
        $updatedCount = 0;

        foreach ($sites as $siteData) {
            // Check if site exists with same name
            $existing = Site::where('name', $siteData['name'])
                ->where('user_id', $siteData['user_id'])
                ->first();

            if ($existing) {
                $existing->update($siteData);
                $updatedCount++;
            } else {
                Site::create($siteData);
                $createdCount++;
            }
        }

        $this->command->info("✅ Sites seeded successfully!");
        $this->command->info("   - Created: {$createdCount} sites");
        $this->command->info("   - Updated: {$updatedCount} sites");

        // ====================== Seed Related Data ======================
        $this->seedSiteVisits($buyer, $seller, $admin, $driver);
        $this->seedSiteStaff($buyer, $seller, $admin, $driver);
        $this->seedSiteMaterials();
        $this->seedSiteDocuments($admin);

        $this->command->info('🏗️ All site-related data seeded successfully!');
    }

    /**
     * Seed site visits
     */
    private function seedSiteVisits($buyer, $seller, $admin, $driver): void
    {
        $sites = Site::all();

        if ($sites->isEmpty()) {
            return;
        }

        $visits = [
            [
                'site_id' => $sites->first()->id,
                'user_id' => $buyer->id,
                'visitor_name' => 'John Mensah',
                'visitor_phone' => '233501234573',
                'visitor_email' => 'john@example.com',
                'visit_date' => now()->subDays(5),
                'check_in_time' => now()->subDays(5)->setTime(9, 0),
                'check_out_time' => now()->subDays(5)->setTime(12, 30),
                'purpose' => 'Site inspection for progress report',
                'notes' => 'Reviewed foundation work. All good.',
                'status' => SiteVisit::STATUS_COMPLETED,
                'approved_by' => $admin->id,
                'approved_at' => now()->subDays(6),
                'safety_briefing_completed' => true,
                'ppe_provided' => true,
                'temperature' => 36.5,
                'vehicle_registration' => 'GR-1234-24',
                'visit_type' => SiteVisit::VISIT_TYPE_SCHEDULED,
            ],
            [
                'site_id' => $sites->skip(1)->first()->id ?? $sites->first()->id,
                'user_id' => $seller->id,
                'visitor_name' => 'Kwame Asante',
                'visitor_phone' => '233501234575',
                'visitor_email' => 'kwame@example.com',
                'visit_date' => now()->subDays(3),
                'check_in_time' => now()->subDays(3)->setTime(14, 0),
                'check_out_time' => now()->subDays(3)->setTime(16, 45),
                'purpose' => 'Material delivery coordination',
                'notes' => 'Discussed sand delivery schedule for next week.',
                'status' => SiteVisit::STATUS_CHECKED_IN,
                'approved_by' => $admin->id,
                'approved_at' => now()->subDays(4),
                'safety_briefing_completed' => true,
                'ppe_provided' => true,
                'temperature' => 36.8,
                'vehicle_registration' => 'GR-5678-24',
                'visit_type' => SiteVisit::VISIT_TYPE_SCHEDULED,
            ],
            [
                'site_id' => $sites->skip(2)->first()->id ?? $sites->first()->id,
                'user_id' => $driver->id,
                'visitor_name' => 'Ama Osei',
                'visitor_phone' => '233501234574',
                'visitor_email' => 'ama@example.com',
                'visit_date' => now()->subDay(),
                'check_in_time' => now()->subDay()->setTime(10, 0),
                'check_out_time' => null,
                'purpose' => 'Driver assignment for material delivery',
                'notes' => 'Assigned driver for cement delivery.',
                'status' => SiteVisit::STATUS_IN_PROGRESS,
                'approved_by' => $admin->id,
                'approved_at' => now()->subDays(2),
                'safety_briefing_completed' => true,
                'ppe_provided' => false,
                'temperature' => 37.0,
                'vehicle_registration' => 'GR-9012-24',
                'visit_type' => SiteVisit::VISIT_TYPE_WALK_IN,
            ],
        ];

        foreach ($visits as $visitData) {
            SiteVisit::create($visitData);
        }

        $this->command->info('   - Site visits created: ' . count($visits));
    }

    /**
     * Seed site staff
     */
    private function seedSiteStaff($buyer, $seller, $admin, $driver): void
    {
        $sites = Site::all();

        if ($sites->isEmpty()) {
            return;
        }

        $staff = [
            [
                'site_id' => $sites->first()->id,
                'user_id' => $admin->id,
                'role' => SiteStaff::ROLE_SITE_MANAGER,
                'department' => 'Construction',
                'position' => 'Site Manager',
                'start_date' => now()->subMonths(6),
                'end_date' => null,
                'is_active' => true,
                'shift_schedule' => ['monday_to_friday' => '08:00-17:00'],
                'contact_emergency' => json_encode(['name' => 'Emergency Contact', 'phone' => '233501234599']),
                'certifications' => ['Project Management', 'Safety Officer'],
                'skills' => ['Leadership', 'Project Management', 'Safety Compliance'],
                'performance_rating' => 4.5,
                'last_performance_review' => now()->subMonths(2),
            ],
            [
                'site_id' => $sites->first()->id,
                'user_id' => $seller->id,
                'role' => SiteStaff::ROLE_SUPERVISOR,
                'department' => 'Operations',
                'position' => 'Site Supervisor',
                'start_date' => now()->subMonths(4),
                'end_date' => null,
                'is_active' => true,
                'shift_schedule' => ['monday_to_saturday' => '07:00-16:00'],
                'contact_emergency' => json_encode(['name' => 'Supervisor Contact', 'phone' => '233501234588']),
                'certifications' => ['Supervision', 'First Aid'],
                'skills' => ['Team Management', 'Quality Control'],
                'performance_rating' => 4.2,
                'last_performance_review' => now()->subMonths(1),
            ],
            [
                'site_id' => $sites->skip(1)->first()->id ?? $sites->first()->id,
                'user_id' => $driver->id,
                'role' => SiteStaff::ROLE_SAFETY_OFFICER,
                'department' => 'Safety',
                'position' => 'Safety Officer',
                'start_date' => now()->subMonths(3),
                'end_date' => null,
                'is_active' => true,
                'shift_schedule' => ['monday_to_friday' => '08:00-17:00'],
                'contact_emergency' => json_encode(['name' => 'Safety Contact', 'phone' => '233501234577']),
                'certifications' => ['Safety Management', 'First Aid', 'Fire Safety'],
                'skills' => ['Safety Compliance', 'Risk Assessment', 'Training'],
                'performance_rating' => 4.8,
                'last_performance_review' => now()->subMonths(2),
            ],
        ];

        foreach ($staff as $staffData) {
            SiteStaff::create($staffData);
        }

        $this->command->info('   - Site staff created: ' . count($staff));
    }

    /**
     * Seed site materials
     */
    private function seedSiteMaterials(): void
    {
        $sites = Site::all();

        if ($sites->isEmpty()) {
            return;
        }

        $materials = [
            [
                'site_id' => $sites->first()->id,
                'supplier_id' => User::where('email', 'seller@sitedrop.gh')->first()?->id,
                'material_name' => 'Sharp Sand',
                'quantity_needed' => 500.00,
                'quantity_delivered' => 150.00,
                'unit' => 'tons',
                'estimated_cost' => 75000.00,
                'actual_cost' => 22500.00,
                'delivery_status' => SiteMaterial::STATUS_PARTIAL,
                'ordered_at' => now()->subDays(30),
                'expected_delivery_date' => now()->addDays(10),
                'delivered_at' => now()->subDays(20),
                'notes' => 'First batch delivered. Remaining scheduled for next week.',
            ],
            [
                'site_id' => $sites->first()->id,
                'supplier_id' => User::where('email', 'seller@sitedrop.gh')->first()?->id,
                'material_name' => 'Cement Blocks - 6 inch',
                'quantity_needed' => 5000.00,
                'quantity_delivered' => 0.00,
                'unit' => 'pieces',
                'estimated_cost' => 60000.00,
                'actual_cost' => 0.00,
                'delivery_status' => SiteMaterial::STATUS_PENDING,
                'ordered_at' => now()->subDays(15),
                'expected_delivery_date' => now()->addDays(14),
                'delivered_at' => null,
                'notes' => 'Order placed. Awaiting delivery from supplier.',
            ],
            [
                'site_id' => $sites->skip(1)->first()->id ?? $sites->first()->id,
                'supplier_id' => User::where('email', 'seller@sitedrop.gh')->first()?->id,
                'material_name' => 'Gravel - 3/4 inch',
                'quantity_needed' => 800.00,
                'quantity_delivered' => 800.00,
                'unit' => 'tons',
                'estimated_cost' => 144000.00,
                'actual_cost' => 140000.00,
                'delivery_status' => SiteMaterial::STATUS_COMPLETED,
                'ordered_at' => now()->subDays(45),
                'expected_delivery_date' => now()->subDays(10),
                'delivered_at' => now()->subDays(15),
                'notes' => 'Fully delivered. All materials received and inspected.',
            ],
        ];

        foreach ($materials as $materialData) {
            SiteMaterial::create($materialData);
        }

        $this->command->info('   - Site materials created: ' . count($materials));
    }

    /**
     * Seed site documents
     */
    private function seedSiteDocuments($admin): void
    {
        $sites = Site::all();

        if ($sites->isEmpty()) {
            return;
        }

        $documents = [
            [
                'site_id' => $sites->first()->id,
                'user_id' => $admin->id,
                'title' => 'Construction Permit',
                'description' => 'Official construction permit for Accra Central site',
                'document_type' => SiteDocument::DOCUMENT_TYPE_PERMIT,
                'file_path' => '/documents/permits/accra_central_permit.pdf',
                'file_name' => 'accra_central_permit.pdf',
                'file_size' => 2048576,
                'file_extension' => 'pdf',
                'version' => '1.0',
                'status' => SiteDocument::STATUS_ACTIVE,
                'expiry_date' => '2025-12-31',
                'uploaded_by' => $admin->id,
                'approved_by' => $admin->id,
                'approved_at' => now()->subMonths(3),
                'tags' => ['permit', 'construction', 'legal'],
                'is_confidential' => false,
                'access_level' => SiteDocument::ACCESS_PUBLIC,
            ],
            [
                'site_id' => $sites->first()->id,
                'user_id' => $admin->id,
                'title' => 'Site Blueprint - Ground Floor',
                'description' => 'Architectural blueprint for ground floor layout',
                'document_type' => SiteDocument::DOCUMENT_TYPE_BLUEPRINT,
                'file_path' => '/documents/blueprints/ground_floor.pdf',
                'file_name' => 'ground_floor.pdf',
                'file_size' => 3072000,
                'file_extension' => 'pdf',
                'version' => '2.1',
                'status' => SiteDocument::STATUS_ACTIVE,
                'expiry_date' => null,
                'uploaded_by' => $admin->id,
                'approved_by' => $admin->id,
                'approved_at' => now()->subMonths(2),
                'tags' => ['blueprint', 'architecture', 'floor_plan'],
                'is_confidential' => true,
                'access_level' => SiteDocument::ACCESS_RESTRICTED,
            ],
            [
                'site_id' => $sites->skip(1)->first()->id ?? $sites->first()->id,
                'user_id' => $admin->id,
                'title' => 'Insurance Policy - Tema Site',
                'description' => 'Construction insurance policy covering Tema project',
                'document_type' => SiteDocument::DOCUMENT_TYPE_INSURANCE,
                'file_path' => '/documents/insurance/tema_insurance.pdf',
                'file_name' => 'tema_insurance.pdf',
                'file_size' => 1536000,
                'file_extension' => 'pdf',
                'version' => '1.0',
                'status' => SiteDocument::STATUS_ACTIVE,
                'expiry_date' => '2025-06-30',
                'uploaded_by' => $admin->id,
                'approved_by' => $admin->id,
                'approved_at' => now()->subMonths(4),
                'tags' => ['insurance', 'policy', 'construction'],
                'is_confidential' => true,
                'access_level' => SiteDocument::ACCESS_PRIVATE,
            ],
            [
                'site_id' => $sites->skip(2)->first()->id ?? $sites->first()->id,
                'user_id' => $admin->id,
                'title' => 'Quarry License',
                'description' => 'Official quarry operating license for Kwabenya site',
                'document_type' => SiteDocument::DOCUMENT_TYPE_PERMIT,
                'file_path' => '/documents/permits/quarry_license.pdf',
                'file_name' => 'quarry_license.pdf',
                'file_size' => 1024000,
                'file_extension' => 'pdf',
                'version' => '3.0',
                'status' => SiteDocument::STATUS_ACTIVE,
                'expiry_date' => '2025-12-31',
                'uploaded_by' => $admin->id,
                'approved_by' => $admin->id,
                'approved_at' => now()->subMonths(6),
                'tags' => ['quarry', 'license', 'permit'],
                'is_confidential' => false,
                'access_level' => SiteDocument::ACCESS_PUBLIC,
            ],
        ];

        foreach ($documents as $documentData) {
            SiteDocument::create($documentData);
        }

        $this->command->info('   - Site documents created: ' . count($documents));
    }
}
