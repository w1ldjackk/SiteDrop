<?php
// database/seeders/TruckSeeder.php

namespace Database\Seeders;

use App\Models\Order;
use App\Models\TripLog;
use App\Models\Truck;
use App\Models\TruckDocument;
use App\Models\TruckInsurance;
use App\Models\TruckLog;
use App\Models\TruckMaintenance;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class TruckSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        $this->command->info('🚛 Seeding trucks and related data...');

        // ====================== TRUNCATE TABLES ======================
        $this->command->info('   - Clearing existing truck data...');

        // Disable foreign key checks for truncation
        DB::statement('SET FOREIGN_KEY_CHECKS=0');

        TripLog::truncate();
        TruckLog::truncate();
        TruckInsurance::truncate();
        TruckDocument::truncate();
        TruckMaintenance::truncate();
        Truck::truncate();

        DB::statement('SET FOREIGN_KEY_CHECKS=1');

        $this->command->info('   - Existing truck data cleared.');

        // Get users from PermissionSeederService
        $seller = User::where('email', 'seller@sitedrop.gh')->first();
        $driver = User::where('email', 'driver@sitedrop.gh')->first();
        $admin = User::where('email', 'admin@sitedrop.gh')->first();
        $buyer = User::where('email', 'buyer@sitedrop.gh')->first();

        if (!$seller) {
            $this->command->error('❌ Seller user not found. Please run PermissionSeederService first.');
            return;
        }

        // Define trucks
        $trucks = [
            [
                'user_id' => $seller->id,
                'driver_id' => $driver ? $driver->id : null,
                'registration_number' => 'GR-1234-24',
                'make' => 'Mercedes-Benz',
                'model' => 'Actros 2545',
                'year' => 2023,
                'color' => 'White',
                'license_plate_front' => 'GR-1234-24',
                'license_plate_back' => 'GR-1234-24',
                'capacity_tons' => 25.00,
                'capacity_cubic_meters' => 12.00,
                'vehicle_type' => Truck::VEHICLE_TYPE_TIPPER,
                'features' => json_encode([
                    'GPS' => true,
                    'Tracking' => true,
                    'Reverse Camera' => true,
                    'Air Conditioning' => true,
                    'Hydraulic Lift' => true,
                    'Weighing System' => true,
                ]),
                'documents' => json_encode([
                    'road_worthy' => 'RW-2024-001',
                    'insurance' => 'INS-2024-001',
                    'registration' => 'REG-2024-001',
                ]),
                'fuel_type' => Truck::FUEL_TYPE_DIESEL,
                'fuel_efficiency_km_per_liter' => 4.5,
                'current_mileage' => 12500.00,
                'last_service_mileage' => 10000.00,
                'next_service_mileage' => 15000.00,
                'last_maintenance_date' => '2024-01-15 10:00:00',
                'next_maintenance_date' => '2024-04-15 10:00:00',
                'insurance_expiry' => '2024-12-31 23:59:59',
                'registration_expiry' => '2024-12-31 23:59:59',
                'owner_type' => Truck::OWNER_TYPE_COMPANY,
                'company_name' => 'ABC Transport Services',
                'status' => Truck::STATUS_AVAILABLE,
                'is_verified' => true,
                'current_location' => json_encode([
                    'lat' => 5.6037,
                    'lng' => -0.1870,
                    'timestamp' => now()->toIso8601String(),
                ]),
                'driver_assigned_at' => '2024-01-01 08:00:00',
                'notes' => 'Well-maintained truck. Ready for long-distance hauling.',
            ],
            [
                'user_id' => $seller->id,
                'driver_id' => null,
                'registration_number' => 'GR-5678-24',
                'make' => 'Scania',
                'model' => 'R-Series R500',
                'year' => 2022,
                'color' => 'Blue',
                'license_plate_front' => 'GR-5678-24',
                'license_plate_back' => 'GR-5678-24',
                'capacity_tons' => 30.00,
                'capacity_cubic_meters' => 15.00,
                'vehicle_type' => Truck::VEHICLE_TYPE_DUMP_TRUCK,
                'features' => json_encode([
                    'GPS' => true,
                    'Tracking' => true,
                    'Reverse Camera' => true,
                    'Air Conditioning' => true,
                    'Hydraulic Lift' => true,
                    'Weighing System' => true,
                    'Automatic Transmission' => true,
                ]),
                'documents' => json_encode([
                    'road_worthy' => 'RW-2024-002',
                    'insurance' => 'INS-2024-002',
                    'registration' => 'REG-2024-002',
                ]),
                'fuel_type' => Truck::FUEL_TYPE_DIESEL,
                'fuel_efficiency_km_per_liter' => 4.0,
                'current_mileage' => 18500.00,
                'last_service_mileage' => 15000.00,
                'next_service_mileage' => 20000.00,
                'last_maintenance_date' => '2024-02-01 10:00:00',
                'next_maintenance_date' => '2024-05-01 10:00:00',
                'insurance_expiry' => '2024-12-31 23:59:59',
                'registration_expiry' => '2024-12-31 23:59:59',
                'owner_type' => Truck::OWNER_TYPE_COMPANY,
                'company_name' => 'ABC Transport Services',
                'status' => Truck::STATUS_IN_TRANSIT,
                'is_verified' => true,
                'current_location' => json_encode([
                    'lat' => 5.6685,
                    'lng' => -0.0184,
                    'timestamp' => now()->toIso8601String(),
                ]),
                'driver_assigned_at' => '2024-02-15 06:00:00',
                'notes' => 'Heavy-duty dump truck. Currently on a delivery run.',
            ],
            [
                'user_id' => $seller->id,
                'driver_id' => null,
                'registration_number' => 'GR-9012-24',
                'make' => 'Volvo',
                'model' => 'FH Series',
                'year' => 2024,
                'color' => 'Red',
                'license_plate_front' => 'GR-9012-24',
                'license_plate_back' => 'GR-9012-24',
                'capacity_tons' => 20.00,
                'capacity_cubic_meters' => 10.00,
                'vehicle_type' => Truck::VEHICLE_TYPE_CONCRETE_MIXER,
                'features' => json_encode([
                    'GPS' => true,
                    'Tracking' => true,
                    'Reverse Camera' => true,
                    'Air Conditioning' => true,
                    'Hydraulic Lift' => true,
                    'Concrete Mixer' => true,
                    'Water Tank' => true,
                ]),
                'documents' => json_encode([
                    'road_worthy' => 'RW-2024-003',
                    'insurance' => 'INS-2024-003',
                    'registration' => 'REG-2024-003',
                ]),
                'fuel_type' => Truck::FUEL_TYPE_DIESEL,
                'fuel_efficiency_km_per_liter' => 3.5,
                'current_mileage' => 5000.00,
                'last_service_mileage' => 4000.00,
                'next_service_mileage' => 9000.00,
                'last_maintenance_date' => '2024-03-01 10:00:00',
                'next_maintenance_date' => '2024-06-01 10:00:00',
                'insurance_expiry' => '2025-03-31 23:59:59',
                'registration_expiry' => '2025-03-31 23:59:59',
                'owner_type' => Truck::OWNER_TYPE_PERSONAL,
                'company_name' => null,
                'status' => Truck::STATUS_MAINTENANCE,
                'is_verified' => true,
                'current_location' => json_encode([
                    'lat' => 5.7200,
                    'lng' => -0.2300,
                    'timestamp' => now()->toIso8601String(),
                ]),
                'driver_assigned_at' => null,
                'notes' => 'Under routine maintenance. Scheduled to be back in service next week.',
            ],
            [
                'user_id' => $seller->id,
                'driver_id' => null,
                'registration_number' => 'GR-3456-24',
                'make' => 'MAN',
                'model' => 'TGS 18.400',
                'year' => 2023,
                'color' => 'Silver',
                'license_plate_front' => 'GR-3456-24',
                'license_plate_back' => 'GR-3456-24',
                'capacity_tons' => 18.00,
                'capacity_cubic_meters' => 8.00,
                'vehicle_type' => Truck::VEHICLE_TYPE_FLATBED,
                'features' => json_encode([
                    'GPS' => true,
                    'Tracking' => true,
                    'Reverse Camera' => true,
                    'Air Conditioning' => true,
                    'Crane' => true,
                ]),
                'documents' => json_encode([
                    'road_worthy' => 'RW-2024-004',
                    'insurance' => 'INS-2024-004',
                    'registration' => 'REG-2024-004',
                ]),
                'fuel_type' => Truck::FUEL_TYPE_DIESEL,
                'fuel_efficiency_km_per_liter' => 5.0,
                'current_mileage' => 8000.00,
                'last_service_mileage' => 7000.00,
                'next_service_mileage' => 12000.00,
                'last_maintenance_date' => '2024-02-15 10:00:00',
                'next_maintenance_date' => '2024-05-15 10:00:00',
                'insurance_expiry' => '2024-11-30 23:59:59',
                'registration_expiry' => '2024-11-30 23:59:59',
                'owner_type' => Truck::OWNER_TYPE_PERSONAL,
                'company_name' => null,
                'status' => Truck::STATUS_AVAILABLE,
                'is_verified' => true,
                'current_location' => json_encode([
                    'lat' => 5.6400,
                    'lng' => -0.1700,
                    'timestamp' => now()->toIso8601String(),
                ]),
                'driver_assigned_at' => null,
                'notes' => 'Flatbed truck with crane. Ideal for transporting construction materials.',
            ],
        ];

        // Create trucks
        $createdCount = 0;
        $updatedCount = 0;

        foreach ($trucks as $truckData) {
            // Check if truck exists with same registration number
            $existing = Truck::where('registration_number', $truckData['registration_number'])->first();

            if ($existing) {
                $existing->update($truckData);
                $updatedCount++;
            } else {
                Truck::create($truckData);
                $createdCount++;
            }
        }

        $this->command->info("✅ Trucks seeded successfully!");
        $this->command->info("   - Created: {$createdCount} trucks");
        $this->command->info("   - Updated: {$updatedCount} trucks");

        // ====================== Seed Related Data ======================
        $this->seedTruckInsurance();
        $this->seedTruckDocuments($admin);
        $this->seedTruckLogs($admin);
        $this->seedTruckMaintenance();
        $this->seedTripLogs($driver, $buyer);

        $this->command->info('🚛 All truck-related data seeded successfully!');
    }

    /**
     * Seed truck insurance
     */
    private function seedTruckInsurance(): void
    {
        $trucks = Truck::all();

        if ($trucks->isEmpty()) {
            return;
        }

        $insurances = [
            [
                'truck_id' => $trucks->first()->id,
                'policy_number' => 'POL-INS-001-2024',
                'insurance_company' => 'Enterprise Insurance',
                'type' => TruckInsurance::TYPE_COMPREHENSIVE,
                'coverage_start_date' => '2024-01-01 00:00:00',
                'coverage_end_date' => '2024-12-31 23:59:59',
                'premium_amount' => 5000.00,
                'premium_currency' => 'GHS',
                'payment_frequency' => TruckInsurance::PAYMENT_FREQUENCY_ANNUALLY,
                'status' => TruckInsurance::STATUS_ACTIVE,
                'coverage_details' => json_encode([
                    'Third Party Liability' => 'Unlimited',
                    'Comprehensive Damage' => '100%',
                    'Theft' => '100%',
                    'Fire' => '100%',
                ]),
                'exclusions' => json_encode([
                    'Intentional Damage',
                    'Driving Under Influence',
                    'Wear and Tear',
                ]),
                'beneficiary_name' => 'ABC Transport Services',
                'beneficiary_relationship' => 'Policy Holder',
                'document_path' => '/documents/insurance/policy_001.pdf',
                'agent_name' => 'John Doe',
                'agent_phone' => '233501234599',
                'agent_email' => 'john.agent@insurance.com',
                'claim_contact' => '233501234588',
                'last_claim_date' => null,
                'claim_count' => 0,
                'notes' => 'Annual comprehensive insurance policy.',
            ],
            [
                'truck_id' => $trucks->skip(1)->first()->id ?? $trucks->first()->id,
                'policy_number' => 'POL-INS-002-2024',
                'insurance_company' => 'Ghana Insurance Company',
                'type' => TruckInsurance::TYPE_THIRD_PARTY,
                'coverage_start_date' => '2024-01-01 00:00:00',
                'coverage_end_date' => '2024-12-31 23:59:59',
                'premium_amount' => 3000.00,
                'premium_currency' => 'GHS',
                'payment_frequency' => TruckInsurance::PAYMENT_FREQUENCY_ANNUALLY,
                'status' => TruckInsurance::STATUS_ACTIVE,
                'coverage_details' => json_encode([
                    'Third Party Liability' => 'GHS 500,000',
                    'Property Damage' => 'GHS 100,000',
                ]),
                'exclusions' => json_encode([
                    'Theft',
                    'Fire',
                    'Intentional Damage',
                ]),
                'beneficiary_name' => 'ABC Transport Services',
                'beneficiary_relationship' => 'Policy Holder',
                'document_path' => '/documents/insurance/policy_002.pdf',
                'agent_name' => 'Jane Doe',
                'agent_phone' => '233501234577',
                'agent_email' => 'jane.agent@insurance.com',
                'claim_contact' => '233501234566',
                'last_claim_date' => null,
                'claim_count' => 0,
                'notes' => 'Annual third-party insurance policy.',
            ],
        ];

        foreach ($insurances as $insuranceData) {
            TruckInsurance::create($insuranceData);
        }

        $this->command->info('   - Truck insurance created: ' . count($insurances));
    }

    /**
     * Seed truck documents
     */
    private function seedTruckDocuments($admin): void
    {
        $trucks = Truck::all();

        if ($trucks->isEmpty()) {
            return;
        }

        $documents = [
            [
                'truck_id' => $trucks->first()->id,
                'user_id' => $admin->id,
                'document_type' => TruckDocument::DOCUMENT_TYPE_REGISTRATION,
                'title' => 'Vehicle Registration Certificate',
                'description' => 'Official vehicle registration for GR-1234-24',
                'file_path' => '/documents/registration/reg_001.pdf',
                'file_name' => 'reg_001.pdf',
                'file_size' => 1024000,
                'file_extension' => 'pdf',
                'document_number' => 'REG-2024-001',
                'issue_date' => '2024-01-01 00:00:00',
                'expiry_date' => '2024-12-31 23:59:59',
                'status' => TruckDocument::STATUS_ACTIVE,
                'verified_by' => $admin->id,
                'verified_at' => now()->subMonths(3),
                'is_required' => true,
                'notes' => 'Annual registration document.',
            ],
            [
                'truck_id' => $trucks->first()->id,
                'user_id' => $admin->id,
                'document_type' => TruckDocument::DOCUMENT_TYPE_INSURANCE,
                'title' => 'Insurance Certificate',
                'description' => 'Insurance coverage for GR-1234-24',
                'file_path' => '/documents/insurance/ins_001.pdf',
                'file_name' => 'ins_001.pdf',
                'file_size' => 2048000,
                'file_extension' => 'pdf',
                'document_number' => 'INS-2024-001',
                'issue_date' => '2024-01-01 00:00:00',
                'expiry_date' => '2024-12-31 23:59:59',
                'status' => TruckDocument::STATUS_ACTIVE,
                'verified_by' => $admin->id,
                'verified_at' => now()->subMonths(3),
                'is_required' => true,
                'notes' => 'Annual insurance certificate.',
            ],
            [
                'truck_id' => $trucks->skip(1)->first()->id ?? $trucks->first()->id,
                'user_id' => $admin->id,
                'document_type' => TruckDocument::DOCUMENT_TYPE_ROAD_WORTHY,
                'title' => 'Road Worthy Certificate',
                'description' => 'Certificate of roadworthiness for GR-5678-24',
                'file_path' => '/documents/road_worthy/rw_002.pdf',
                'file_name' => 'rw_002.pdf',
                'file_size' => 1536000,
                'file_extension' => 'pdf',
                'document_number' => 'RW-2024-002',
                'issue_date' => '2024-01-15 00:00:00',
                'expiry_date' => '2024-12-31 23:59:59',
                'status' => TruckDocument::STATUS_ACTIVE,
                'verified_by' => $admin->id,
                'verified_at' => now()->subMonths(2),
                'is_required' => true,
                'notes' => 'Annual roadworthy certificate.',
            ],
            [
                'truck_id' => $trucks->skip(2)->first()->id ?? $trucks->first()->id,
                'user_id' => $admin->id,
                'document_type' => TruckDocument::DOCUMENT_TYPE_INSPECTION,
                'title' => 'Annual Safety Inspection Report',
                'description' => 'Safety inspection report for GR-9012-24',
                'file_path' => '/documents/inspection/insp_003.pdf',
                'file_name' => 'insp_003.pdf',
                'file_size' => 2560000,
                'file_extension' => 'pdf',
                'document_number' => 'INSP-2024-003',
                'issue_date' => '2024-01-01 00:00:00',
                'expiry_date' => '2024-12-31 23:59:59',
                'status' => TruckDocument::STATUS_ACTIVE,
                'verified_by' => $admin->id,
                'verified_at' => now()->subMonths(3),
                'is_required' => true,
                'notes' => 'Annual safety inspection.',
            ],
        ];

        foreach ($documents as $documentData) {
            TruckDocument::create($documentData);
        }

        $this->command->info('   - Truck documents created: ' . count($documents));
    }

    /**
     * Seed truck logs
     */
    private function seedTruckLogs($admin): void
    {
        $trucks = Truck::all();

        if ($trucks->isEmpty()) {
            return;
        }

        $logs = [
            [
                'truck_id' => $trucks->first()->id,
                'user_id' => $admin->id,
                'action' => TruckLog::ACTION_CREATED,
                'description' => 'Truck added to fleet',
                'metadata' => json_encode(['type' => 'new_vehicle', 'status' => 'registered']),
                'ip_address' => '127.0.0.1',
                'user_agent' => 'Seeder',
            ],
            [
                'truck_id' => $trucks->first()->id,
                'user_id' => $admin->id,
                'action' => TruckLog::ACTION_STATUS_CHANGED,
                'description' => 'Truck marked as available',
                'metadata' => json_encode([
                    'old_status' => 'inactive',
                    'new_status' => 'available',
                    'reason' => 'Ready for service',
                ]),
                'ip_address' => '127.0.0.1',
                'user_agent' => 'Seeder',
            ],
            [
                'truck_id' => $trucks->skip(1)->first()->id ?? $trucks->first()->id,
                'user_id' => $admin->id,
                'action' => TruckLog::ACTION_MAINTENANCE,
                'description' => 'Routine maintenance performed',
                'metadata' => json_encode([
                    'maintenance_type' => 'routine',
                    'cost' => 2500.00,
                    'service_mileage' => 15000,
                ]),
                'ip_address' => '127.0.0.1',
                'user_agent' => 'Seeder',
            ],
            [
                'truck_id' => $trucks->skip(2)->first()->id ?? $trucks->first()->id,
                'user_id' => $admin->id,
                'action' => TruckLog::ACTION_TRIP_STARTED,
                'description' => 'Delivery trip started',
                'metadata' => json_encode([
                    'trip_id' => 'TRIP-001',
                    'destination' => 'Accra Central',
                    'distance' => 25.5,
                ]),
                'ip_address' => '127.0.0.1',
                'user_agent' => 'Seeder',
            ],
            [
                'truck_id' => $trucks->skip(2)->first()->id ?? $trucks->first()->id,
                'user_id' => $admin->id,
                'action' => TruckLog::ACTION_LOCATION_UPDATED,
                'description' => 'Location updated during transit',
                'metadata' => json_encode([
                    'lat' => 5.6037,
                    'lng' => -0.1870,
                ]),
                'ip_address' => '127.0.0.1',
                'user_agent' => 'Seeder',
            ],
        ];

        foreach ($logs as $logData) {
            TruckLog::create($logData);
        }

        $this->command->info('   - Truck logs created: ' . count($logs));
    }

    /**
     * Seed truck maintenance records
     */
    private function seedTruckMaintenance(): void
    {
        $trucks = Truck::all();

        if ($trucks->isEmpty()) {
            return;
        }

        $admin = User::where('email', 'admin@sitedrop.gh')->first();

        $maintenanceRecords = [];

        // Maintenance for Truck 1 (GR-1234-24)
        $truck1 = $trucks->first();
        if ($truck1) {
            $maintenanceRecords = array_merge($maintenanceRecords, [
                [
                    'truck_id' => $truck1->id,
                    'maintenance_type' => 'routine',
                    'description' => 'Oil change and filter replacement',
                    'cost' => 850.00,
                    'performed_at' => '2024-01-15 09:00:00',
                    'performed_by' => $admin ? $admin->id : null,
                    'notes' => 'Regular oil change service. Engine running smoothly.',
                    'mileage_at_service' => 10000.00,
                    'next_service_mileage' => 15000.00,
                    'status' => 'completed',
                ],
                [
                    'truck_id' => $truck1->id,
                    'maintenance_type' => 'routine',
                    'description' => 'Tire rotation and brake inspection',
                    'cost' => 1200.00,
                    'performed_at' => '2024-02-15 10:00:00',
                    'performed_by' => $admin ? $admin->id : null,
                    'notes' => 'Tires rotated, brake pads inspected and found in good condition.',
                    'mileage_at_service' => 11250.00,
                    'next_service_mileage' => 16250.00,
                    'status' => 'completed',
                ],
            ]);
        }

        // Maintenance for Truck 2 (GR-5678-24)
        $truck2 = $trucks->skip(1)->first();
        if ($truck2) {
            $maintenanceRecords = array_merge($maintenanceRecords, [
                [
                    'truck_id' => $truck2->id,
                    'maintenance_type' => 'repair',
                    'description' => 'Transmission repair - Gearbox overhaul',
                    'cost' => 5000.00,
                    'performed_at' => '2024-01-20 08:00:00',
                    'performed_by' => $admin ? $admin->id : null,
                    'notes' => 'Complete gearbox overhaul. Transmission fluid replaced.',
                    'mileage_at_service' => 15000.00,
                    'next_service_mileage' => 18000.00,
                    'status' => 'completed',
                ],
                [
                    'truck_id' => $truck2->id,
                    'maintenance_type' => 'routine',
                    'description' => 'Cooling system flush and refill',
                    'cost' => 650.00,
                    'performed_at' => '2024-03-10 10:00:00',
                    'performed_by' => $admin ? $admin->id : null,
                    'notes' => 'Coolant flushed and replaced. System pressure tested.',
                    'mileage_at_service' => 16500.00,
                    'next_service_mileage' => 21500.00,
                    'status' => 'in_progress',
                ],
            ]);
        }

        // Maintenance for Truck 3 (GR-9012-24) - Currently in maintenance
        $truck3 = $trucks->skip(2)->first();
        if ($truck3) {
            $maintenanceRecords = array_merge($maintenanceRecords, [
                [
                    'truck_id' => $truck3->id,
                    'maintenance_type' => 'emergency',
                    'description' => 'Engine overheating - Radiator replacement',
                    'cost' => 3500.00,
                    'performed_at' => '2024-03-01 09:00:00',
                    'performed_by' => $admin ? $admin->id : null,
                    'notes' => 'Radiator cracked and replaced. System flushed and refilled.',
                    'mileage_at_service' => 4000.00,
                    'next_service_mileage' => 6000.00,
                    'status' => 'completed',
                ],
                [
                    'truck_id' => $truck3->id,
                    'maintenance_type' => 'routine',
                    'description' => 'Full engine diagnostic and tune-up',
                    'cost' => 1500.00,
                    'performed_at' => '2024-06-01 08:00:00',
                    'performed_by' => $admin ? $admin->id : null,
                    'notes' => 'Scheduled maintenance. Engine diagnostics completed. All systems operational.',
                    'mileage_at_service' => 5000.00,
                    'next_service_mileage' => 9000.00,
                    'status' => 'scheduled',
                ],
            ]);
        }

        // Maintenance for Truck 4 (GR-3456-24)
        $truck4 = $trucks->skip(3)->first();
        if ($truck4) {
            $maintenanceRecords = array_merge($maintenanceRecords, [
                [
                    'truck_id' => $truck4->id,
                    'maintenance_type' => 'routine',
                    'description' => 'Brake pad replacement and system service',
                    'cost' => 950.00,
                    'performed_at' => '2024-02-15 10:00:00',
                    'performed_by' => $admin ? $admin->id : null,
                    'notes' => 'Front and rear brake pads replaced. System bled and refilled.',
                    'mileage_at_service' => 7000.00,
                    'next_service_mileage' => 12000.00,
                    'status' => 'completed',
                ],
                [
                    'truck_id' => $truck4->id,
                    'maintenance_type' => 'routine',
                    'description' => 'Crane inspection and certification',
                    'cost' => 750.00,
                    'performed_at' => '2024-03-20 14:00:00',
                    'performed_by' => $admin ? $admin->id : null,
                    'notes' => 'Annual crane inspection. All hydraulics and lifting mechanisms tested.',
                    'mileage_at_service' => 8000.00,
                    'next_service_mileage' => 9000.00,
                    'status' => 'completed',
                ],
                [
                    'truck_id' => $truck4->id,
                    'maintenance_type' => 'repair',
                    'description' => 'Hydraulic hose replacement',
                    'cost' => 300.00,
                    'performed_at' => '2024-04-05 11:00:00',
                    'performed_by' => $admin ? $admin->id : null,
                    'notes' => 'Replaced worn hydraulic hoses on crane system.',
                    'mileage_at_service' => 8500.00,
                    'next_service_mileage' => 9000.00,
                    'status' => 'completed',
                ],
            ]);
        }

        foreach ($maintenanceRecords as $record) {
            TruckMaintenance::create($record);
        }

        $this->command->info('   - Truck maintenance records created: ' . count($maintenanceRecords));
    }

    /**
     * Seed trip logs
     */
    private function seedTripLogs($driver, $buyer): void
    {
        $trucks = Truck::all();

        if ($trucks->isEmpty()) {
            return;
        }

        // Get first truck that has a driver assigned
        $truck = $trucks->whereNotNull('driver_id')->first();

        if (!$truck) {
            $this->command->warn('⚠️ No truck with driver found. Skipping trip logs.');
            return;
        }

        $driverId = $truck->driver_id;

        // Get an order if exists (for order_id reference)
        $order = \App\Models\Order::first();

        $tripLogs = [
            [
                'truck_id' => $truck->id,
                'driver_id' => $driverId,
                'order_id' => $order ? $order->id : null,
                'start_location' => json_encode([
                    'lat' => 5.6037,
                    'lng' => -0.1870,
                    'address' => 'Accra Central, Ghana',
                ]),
                'end_location' => json_encode([
                    'lat' => 5.6685,
                    'lng' => -0.0184,
                    'address' => 'Tema Industrial Area, Ghana',
                ]),
                'distance_km' => 25.50,
                'duration_minutes' => 45,
                'fuel_consumed_liters' => 15.00,
                'fuel_efficiency_km_per_liter' => 1.70,
                'started_at' => now()->subHours(4),
                'ended_at' => now()->subHours(3),
                'status' => TripLog::STATUS_COMPLETED,
                'start_odometer' => 12500.00,
                'end_odometer' => 12525.50,
                'route_path' => json_encode([
                    ['lat' => 5.6037, 'lng' => -0.1870, 'timestamp' => now()->subHours(4)->toIso8601String()],
                    ['lat' => 5.6100, 'lng' => -0.1800, 'timestamp' => now()->subHours(3.8)->toIso8601String()],
                    ['lat' => 5.6200, 'lng' => -0.1600, 'timestamp' => now()->subHours(3.5)->toIso8601String()],
                    ['lat' => 5.6400, 'lng' => -0.1200, 'timestamp' => now()->subHours(3.2)->toIso8601String()],
                    ['lat' => 5.6600, 'lng' => -0.0800, 'timestamp' => now()->subHours(3.0)->toIso8601String()],
                    ['lat' => 5.6685, 'lng' => -0.0184, 'timestamp' => now()->subHours(2.8)->toIso8601String()],
                ]),
                'waypoints' => json_encode([
                    ['lat' => 5.6100, 'lng' => -0.1800, 'stop_type' => 'traffic_light'],
                    ['lat' => 5.6400, 'lng' => -0.1200, 'stop_type' => 'weigh_station'],
                ]),
                'average_speed' => 34.00,
                'max_speed' => 62.00,
                'weather_conditions' => json_encode([
                    'temperature' => 28,
                    'condition' => 'sunny',
                    'visibility' => 'good',
                ]),
                'road_conditions' => json_encode([
                    'traffic' => 'moderate',
                    'road_quality' => 'good',
                    'construction_zones' => false,
                ]),
                'notes' => 'Routine delivery to Tema Industrial Area. All materials delivered successfully.',
                'completed_at' => now()->subHours(3),
            ],
            [
                'truck_id' => $truck->id,
                'driver_id' => $driverId,
                'order_id' => $order ? $order->id : null,
                'start_location' => json_encode([
                    'lat' => 5.6685,
                    'lng' => -0.0184,
                    'address' => 'Tema Industrial Area, Ghana',
                ]),
                'end_location' => json_encode([
                    'lat' => 5.7200,
                    'lng' => -0.2300,
                    'address' => 'Kwabenya Quarry Site, Ghana',
                ]),
                'distance_km' => 35.80,
                'duration_minutes' => 65,
                'fuel_consumed_liters' => 22.00,
                'fuel_efficiency_km_per_liter' => 1.63,
                'started_at' => now()->subDays(1)->setTime(14, 0),
                'ended_at' => now()->subDays(1)->setTime(15, 5),
                'status' => TripLog::STATUS_COMPLETED,
                'start_odometer' => 12525.50,
                'end_odometer' => 12561.30,
                'route_path' => json_encode([
                    ['lat' => 5.6685, 'lng' => -0.0184, 'timestamp' => now()->subDays(1)->setTime(14, 0)->toIso8601String()],
                    ['lat' => 5.6800, 'lng' => -0.0500, 'timestamp' => now()->subDays(1)->setTime(14, 15)->toIso8601String()],
                    ['lat' => 5.7000, 'lng' => -0.1000, 'timestamp' => now()->subDays(1)->setTime(14, 30)->toIso8601String()],
                    ['lat' => 5.7100, 'lng' => -0.1500, 'timestamp' => now()->subDays(1)->setTime(14, 45)->toIso8601String()],
                    ['lat' => 5.7200, 'lng' => -0.2000, 'timestamp' => now()->subDays(1)->setTime(15, 0)->toIso8601String()],
                    ['lat' => 5.7200, 'lng' => -0.2300, 'timestamp' => now()->subDays(1)->setTime(15, 5)->toIso8601String()],
                ]),
                'waypoints' => json_encode([
                    ['lat' => 5.7000, 'lng' => -0.1000, 'stop_type' => 'fuel_stop'],
                ]),
                'average_speed' => 33.00,
                'max_speed' => 58.00,
                'weather_conditions' => json_encode([
                    'temperature' => 26,
                    'condition' => 'partly_cloudy',
                    'visibility' => 'good',
                ]),
                'road_conditions' => json_encode([
                    'traffic' => 'light',
                    'road_quality' => 'fair',
                    'construction_zones' => true,
                ]),
                'notes' => 'Delivered stones to quarry site. Road construction caused slight delay.',
                'completed_at' => now()->subDays(1)->setTime(15, 5),
            ],
            [
                'truck_id' => $truck->id,
                'driver_id' => $driverId,
                'order_id' => null,
                'start_location' => json_encode([
                    'lat' => 5.7200,
                    'lng' => -0.2300,
                    'address' => 'Kwabenya Quarry Site, Ghana',
                ]),
                'end_location' => json_encode([
                    'lat' => 5.6037,
                    'lng' => -0.1870,
                    'address' => 'Accra Central, Ghana',
                ]),
                'distance_km' => 28.30,
                'duration_minutes' => 50,
                'fuel_consumed_liters' => 17.50,
                'fuel_efficiency_km_per_liter' => 1.62,
                'started_at' => now()->subDays(2)->setTime(9, 0),
                'ended_at' => now()->subDays(2)->setTime(9, 50),
                'status' => TripLog::STATUS_COMPLETED,
                'start_odometer' => 12561.30,
                'end_odometer' => 12589.60,
                'route_path' => json_encode([
                    ['lat' => 5.7200, 'lng' => -0.2300, 'timestamp' => now()->subDays(2)->setTime(9, 0)->toIso8601String()],
                    ['lat' => 5.7000, 'lng' => -0.2000, 'timestamp' => now()->subDays(2)->setTime(9, 10)->toIso8601String()],
                    ['lat' => 5.6800, 'lng' => -0.1500, 'timestamp' => now()->subDays(2)->setTime(9, 25)->toIso8601String()],
                    ['lat' => 5.6500, 'lng' => -0.1800, 'timestamp' => now()->subDays(2)->setTime(9, 40)->toIso8601String()],
                    ['lat' => 5.6037, 'lng' => -0.1870, 'timestamp' => now()->subDays(2)->setTime(9, 50)->toIso8601String()],
                ]),
                'waypoints' => null,
                'average_speed' => 34.00,
                'max_speed' => 55.00,
                'weather_conditions' => json_encode([
                    'temperature' => 30,
                    'condition' => 'sunny',
                    'visibility' => 'excellent',
                ]),
                'road_conditions' => json_encode([
                    'traffic' => 'moderate',
                    'road_quality' => 'good',
                    'construction_zones' => false,
                ]),
                'notes' => 'Return trip from quarry. Vehicle operated normally.',
                'completed_at' => now()->subDays(2)->setTime(9, 50),
            ],
            [
                'truck_id' => $truck->id,
                'driver_id' => $driverId,
                'order_id' => $order ? $order->id : null,
                'start_location' => json_encode([
                    'lat' => 5.6037,
                    'lng' => -0.1870,
                    'address' => 'Accra Central, Ghana',
                ]),
                'end_location' => json_encode([
                    'lat' => 5.6400,
                    'lng' => -0.1700,
                    'address' => 'Spintex Residential Complex, Ghana',
                ]),
                'distance_km' => 8.50,
                'duration_minutes' => 20,
                'fuel_consumed_liters' => 5.00,
                'fuel_efficiency_km_per_liter' => 1.70,
                'started_at' => now()->subDays(3)->setTime(11, 0),
                'ended_at' => now()->subDays(3)->setTime(11, 20),
                'status' => TripLog::STATUS_COMPLETED,
                'start_odometer' => 12589.60,
                'end_odometer' => 12598.10,
                'route_path' => json_encode([
                    ['lat' => 5.6037, 'lng' => -0.1870, 'timestamp' => now()->subDays(3)->setTime(11, 0)->toIso8601String()],
                    ['lat' => 5.6200, 'lng' => -0.1800, 'timestamp' => now()->subDays(3)->setTime(11, 5)->toIso8601String()],
                    ['lat' => 5.6400, 'lng' => -0.1700, 'timestamp' => now()->subDays(3)->setTime(11, 20)->toIso8601String()],
                ]),
                'waypoints' => null,
                'average_speed' => 25.50,
                'max_speed' => 40.00,
                'weather_conditions' => json_encode([
                    'temperature' => 27,
                    'condition' => 'cloudy',
                    'visibility' => 'good',
                ]),
                'road_conditions' => json_encode([
                    'traffic' => 'heavy',
                    'road_quality' => 'good',
                    'construction_zones' => false,
                ]),
                'notes' => 'Local delivery to Spintex. Heavy traffic in the area.',
                'completed_at' => now()->subDays(3)->setTime(11, 20),
            ],
            [
                'truck_id' => $truck->id,
                'driver_id' => $driverId,
                'order_id' => null,
                'start_location' => json_encode([
                    'lat' => 5.6037,
                    'lng' => -0.1870,
                    'address' => 'Accra Central, Ghana',
                ]),
                'end_location' => json_encode([
                    'lat' => 6.6885,
                    'lng' => -1.6244,
                    'address' => 'Kumasi Central Market, Ghana',
                ]),
                'distance_km' => 210.00,
                'duration_minutes' => 240,
                'fuel_consumed_liters' => 120.00,
                'fuel_efficiency_km_per_liter' => 1.75,
                'started_at' => now()->subDays(5)->setTime(6, 0),
                'ended_at' => now()->subDays(5)->setTime(10, 0),
                'status' => TripLog::STATUS_COMPLETED,
                'start_odometer' => 12598.10,
                'end_odometer' => 12808.10,
                'route_path' => json_encode([
                    ['lat' => 5.6037, 'lng' => -0.1870, 'timestamp' => now()->subDays(5)->setTime(6, 0)->toIso8601String()],
                    ['lat' => 5.8000, 'lng' => -0.3000, 'timestamp' => now()->subDays(5)->setTime(6, 30)->toIso8601String()],
                    ['lat' => 6.0000, 'lng' => -0.5000, 'timestamp' => now()->subDays(5)->setTime(7, 0)->toIso8601String()],
                    ['lat' => 6.2000, 'lng' => -0.8000, 'timestamp' => now()->subDays(5)->setTime(7, 30)->toIso8601String()],
                    ['lat' => 6.4000, 'lng' => -1.1000, 'timestamp' => now()->subDays(5)->setTime(8, 0)->toIso8601String()],
                    ['lat' => 6.5000, 'lng' => -1.3000, 'timestamp' => now()->subDays(5)->setTime(8, 30)->toIso8601String()],
                    ['lat' => 6.6000, 'lng' => -1.5000, 'timestamp' => now()->subDays(5)->setTime(9, 0)->toIso8601String()],
                    ['lat' => 6.6885, 'lng' => -1.6244, 'timestamp' => now()->subDays(5)->setTime(10, 0)->toIso8601String()],
                ]),
                'waypoints' => json_encode([
                    ['lat' => 6.0000, 'lng' => -0.5000, 'stop_type' => 'rest_stop'],
                    ['lat' => 6.4000, 'lng' => -1.1000, 'stop_type' => 'weigh_station'],
                ]),
                'average_speed' => 52.50,
                'max_speed' => 85.00,
                'weather_conditions' => json_encode([
                    'temperature' => 25,
                    'condition' => 'sunny',
                    'visibility' => 'excellent',
                ]),
                'road_conditions' => json_encode([
                    'traffic' => 'light',
                    'road_quality' => 'fair',
                    'construction_zones' => true,
                ]),
                'notes' => 'Long-distance delivery to Kumasi. Vehicle performed well on highway.',
                'completed_at' => now()->subDays(5)->setTime(10, 0),
            ],
        ];

        foreach ($tripLogs as $tripData) {
            TripLog::create($tripData);
        }

        $this->command->info('   - Trip logs created: ' . count($tripLogs));

        // Add trip logs to truck logs as well
        $this->addTripLogsToTruckLogs($truck);
    }

    /**
     * Add trip logs to truck logs for auditing
     */
    private function addTripLogsToTruckLogs($truck): void
    {
        $tripLogs = TripLog::where('truck_id', $truck->id)->get();

        foreach ($tripLogs as $trip) {
            // Decode JSON strings to arrays
            $startLocation = is_string($trip->start_location) ? json_decode($trip->start_location, true) : $trip->start_location;
            $endLocation = is_string($trip->end_location) ? json_decode($trip->end_location, true) : $trip->end_location;

            $startAddress = $startLocation['address'] ?? 'Unknown';
            $endAddress = $endLocation['address'] ?? 'Unknown';

            // Only create truck log if it doesn't already exist
            $existing = TruckLog::where('truck_id', $truck->id)
                ->where('metadata->trip_id', $trip->id)
                ->first();

            if (!$existing) {
                TruckLog::create([
                    'truck_id' => $truck->id,
                    'user_id' => $trip->driver_id,
                    'action' => TruckLog::ACTION_TRIP_STARTED,
                    'description' => "Trip started from {$startAddress} to {$endAddress}",
                    'metadata' => json_encode([
                        'trip_id' => $trip->id,
                        'distance' => $trip->distance_km,
                        'start_location' => $startLocation,
                        'end_location' => $endLocation,
                    ]),
                    'ip_address' => '127.0.0.1',
                    'user_agent' => 'Seeder',
                ]);

                TruckLog::create([
                    'truck_id' => $truck->id,
                    'user_id' => $trip->driver_id,
                    'action' => TruckLog::ACTION_TRIP_ENDED,
                    'description' => "Trip completed. Total distance: {$trip->distance_km} km",
                    'metadata' => json_encode([
                        'trip_id' => $trip->id,
                        'distance' => $trip->distance_km,
                        'duration' => $trip->duration_minutes,
                        'fuel_consumed' => $trip->fuel_consumed_liters,
                    ]),
                    'ip_address' => '127.0.0.1',
                    'user_agent' => 'Seeder',
                ]);
            }
        }

        $this->command->info('   - Associated truck logs created for trips.');
    }
}
