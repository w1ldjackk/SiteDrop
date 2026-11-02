<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Services\Security\PermissionSeederService;

class PermissionSeeder extends Seeder
{
    public function run(): void
    {
        // Instantiate the service and run it
        $service = new PermissionSeederService();
        $service->setCommand($this->command);
        $service->run();

        // Optional: output info message
        $this->command->info('Profiles created for all users!');
    }
}
