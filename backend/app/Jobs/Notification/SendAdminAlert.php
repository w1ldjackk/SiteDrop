<?php
// app/Jobs/Notification/SendAdminAlert.php

namespace App\Jobs\Notification;

use App\Models\Notification;
use App\Models\User;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;

class SendAdminAlert implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public array $alertData;
    public int $tries = 3;

    public function __construct(array $alertData)
    {
        $this->alertData = $alertData;
    }

    public function handle(): void
    {
        try {
            // Get all admin users
            $admins = User::whereHas('roles', function ($query) {
                $query->whereIn('name', ['admin', 'super-admin']);
            })->get();

            foreach ($admins as $admin) {
                Notification::createNotification(
                    $admin->id,
                    "Admin Alert: {$this->alertData['type']}",
                    $this->alertData['message'] ?? 'An admin alert was triggered',
                    'system',
                    $this->alertData,
                    'in_app',
                    'high'
                );

                // Send email for critical alerts
                if (($this->alertData['priority'] ?? 'high') === 'critical') {
                    // Mail::to($admin->email)->send(new AdminAlert($this->alertData));
                }
            }

            Log::info('Admin alert sent', [
                'type' => $this->alertData['type'],
                'admins_notified' => $admins->count(),
            ]);
        } catch (\Exception $e) {
            Log::error('Admin alert failed', [
                'error' => $e->getMessage(),
                'alert_data' => $this->alertData,
            ]);
        }
    }
}
