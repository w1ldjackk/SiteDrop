<?php

namespace Database\Seeders;

use App\Models\User;
use Database\Seeders\PermissionsSeeder;
use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    /**
     * Seed the application's database.
     */
    public function run(): void
    {
        $this->call([
            PermissionSeeder::class,
            ProductSeeder::class,
            SiteSeeder::class,
            TruckSeeder::class,
            OrderAndPaymentSeeder::class,
            NotificationSeeder::class,
        ]);
        // User::factory(10)->create();

        User::factory()->create([
            'name' => 'Test User',
            'email' => 'test@example.com',
        ]);
    }
}
