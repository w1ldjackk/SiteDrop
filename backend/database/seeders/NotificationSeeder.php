<?php

namespace Database\Seeders;

use App\Models\Notification;
use App\Models\User;
use Illuminate\Database\Seeder;

class NotificationSeeder extends Seeder
{
    public function run(): void
    {
        $admin = User::where('email', 'admin@sitedrop.gh')->first() ?? User::first();

        if (!$admin) {
            $this->command->warn('No admin user found. Skipping notification seeding.');
            return;
        }

        $samples = [
            [
                'title' => 'New high-priority order',
                'body' => 'Order #ORD-9921 requires immediate attention from seller Acme Supplies.',
                'type' => 'order',
                'priority' => Notification::PRIORITY_HIGH,
                'action_url' => '/admin/orders',
            ],
            [
                'title' => 'Truck maintenance due',
                'body' => 'Truck TRK-47 is due for scheduled maintenance within 48 hours.',
                'type' => 'truck',
                'priority' => Notification::PRIORITY_NORMAL,
            ],
            [
                'title' => 'Payment received',
                'body' => 'Payment of GHS 1,450 for order #ORD-9918 has been confirmed.',
                'type' => 'payment',
                'priority' => Notification::PRIORITY_NORMAL,
            ],
            [
                'title' => 'Seller onboarding approved',
                'body' => 'Tema Aggregates Ltd has completed verification and is now active.',
                'type' => 'system',
                'priority' => Notification::PRIORITY_NORMAL,
            ],
            [
                'title' => 'Delivery delay alert',
                'body' => 'Delivery #DLV-304 is running 45 minutes behind schedule.',
                'type' => 'delivery',
                'priority' => Notification::PRIORITY_HIGH,
            ],
        ];

        foreach ($samples as $sample) {
            Notification::createNotification(
                $admin->id,
                $sample['title'],
                $sample['body'],
                $sample['type'],
                ['seeded' => true],
                Notification::CHANNEL_IN_APP,
                $sample['priority'],
                $sample['action_url'] ?? null
            );
        }

        $this->command->info('Sample admin notifications seeded.');
    }
}
