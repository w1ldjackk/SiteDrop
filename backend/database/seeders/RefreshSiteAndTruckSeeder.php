<?php
// database/seeders/RefreshSiteAndTruckSeeder.php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class RefreshSiteAndTruckSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        $this->command->info('🔄 Refreshing Site and Truck data...');

        // Disable foreign key checks
        DB::statement('SET FOREIGN_KEY_CHECKS=0');

        // Truncate Site related tables
        $this->command->info('   - Truncating site tables...');
        \App\Models\SiteStatusLog::truncate();
        \App\Models\SiteVisit::truncate();
        \App\Models\SiteDocument::truncate();
        \App\Models\SiteStaff::truncate();
        \App\Models\SiteMaterial::truncate();
        \App\Models\Site::truncate();

        // Truncate Truck related tables
        $this->command->info('   - Truncating truck tables...');
        \App\Models\TripLog::truncate();
        \App\Models\TruckLog::truncate();
        \App\Models\TruckInsurance::truncate();
        \App\Models\TruckDocument::truncate();
        \App\Models\Truck::truncate();

        // Re-enable foreign key checks
        DB::statement('SET FOREIGN_KEY_CHECKS=1');

        $this->command->info('   - Tables truncated successfully.');

        // Now re-run the seeders
        $this->command->info('   - Re-seeding sites...');
        $this->call(SiteSeeder::class);

        $this->command->info('   - Re-seeding trucks...');
        $this->call(TruckSeeder::class);

        $this->command->info('✅ Site and Truck data refreshed successfully!');
    }
}
