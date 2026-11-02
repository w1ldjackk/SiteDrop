<?php

namespace App\Console\Commands;

use App\Models\User;
use App\Services\Notification\NotificationService;
use App\Services\Notification\PushNotificationService;
use Illuminate\Console\Command;

class FcmStatusCommand extends Command
{
    protected $signature = 'fcm:status
                            {--test-user= : Send a test push to this user id (must have fcm_token)}
                            {--test-token= : Send a test push to a raw FCM device token}
                            {--via-app : Also run NotificationService (in-app + push channels like real app events)}';

    protected $description = 'Show FCM configuration status (HTTP v1 / legacy) and optionally send a test push';

    public function handle(PushNotificationService $push, NotificationService $notifications): int
    {
        $status = $push->status();

        $this->info('FCM configuration');
        $this->table(
            ['Key', 'Value'],
            [
                ['project_id', $status['project_id'] ?? '—'],
                ['http_v1 (service account)', $status['http_v1'] ? 'yes' : 'no'],
                ['legacy server key', $status['legacy'] ? 'yes' : 'no'],
                ['credentials_path', $status['credentials_path'] ?? '—'],
                ['credentials_readable', $status['credentials_readable'] ? 'yes' : 'no'],
                ['configured', $status['configured'] ? 'YES' : 'NO'],
            ]
        );

        if (! $status['configured']) {
            $this->warn('Not configured. Prefer HTTP v1:');
            $this->line('  1. Firebase Console → Project settings → Service accounts → Generate new private key');
            $this->line('  2. Save as storage/app/firebase/service-account.json');
            $this->line('  3. Set FIREBASE_CREDENTIALS=storage/app/firebase/service-account.json in .env');
            $this->line('  Or legacy: FCM_SERVER_KEY=… (deprecated)');
        }

        $tokenUsers = User::query()
            ->whereNotNull('fcm_token')
            ->where('fcm_token', '!=', '')
            ->orderBy('id')
            ->get(['id', 'name', 'email', 'phone', 'device_type', 'fcm_token']);

        $this->line('Users with fcm_token: '.$tokenUsers->count());
        if ($tokenUsers->isNotEmpty()) {
            $this->table(
                ['id', 'name', 'device', 'token_suffix', 'test hint'],
                $tokenUsers->map(fn (User $u) => [
                    $u->id,
                    $u->name,
                    $u->device_type ?? '—',
                    '…'.substr((string) $u->fcm_token, -10),
                    "php artisan fcm:status --test-user={$u->id}",
                ])->all()
            );
        } else {
            $this->warn('No device tokens stored yet. Sign in on the app, allow notifications, then re-check.');
        }

        $token = $this->option('test-token');
        $userId = $this->option('test-user');

        if ($userId) {
            $user = User::query()->find($userId);
            if (! $user) {
                $this->error("User {$userId} not found");

                return self::FAILURE;
            }
            if (! $user->fcm_token) {
                $this->error("User {$userId} ({$user->name}) has no fcm_token.");
                if ($tokenUsers->isNotEmpty()) {
                    $ids = $tokenUsers->pluck('id')->implode(', #');
                    $this->line("Try a user that has a token: #{$ids}");
                    $this->line('Example: php artisan fcm:status --test-user='.$tokenUsers->first()->id);
                } else {
                    $this->line('Open the app while signed in as this user, allow notifications, then retry.');
                }

                return self::FAILURE;
            }
            $token = $user->fcm_token;
            $this->line("Using token from user #{$user->id} ({$user->name}) …".substr((string) $token, -8));
        }

        if ($token) {
            if (! $status['configured']) {
                $this->error('Cannot send test: FCM not configured');

                return self::FAILURE;
            }

            $this->info('Sending test push…');
            $result = $push->send(
                (string) $token,
                'SiteDrop test',
                'FCM is working — '.now()->toDateTimeString(),
                ['type' => 'fcm_test', 'ts' => (string) now()->timestamp]
            );

            if ($result['success']) {
                $this->info('OK via '.($result['transport'] ?? 'unknown'));
                $this->line(json_encode($result['result'] ?? [], JSON_PRETTY_PRINT));
            } else {
                $this->error('Failed: '.($result['message'] ?? 'unknown'));
                if (! empty($result['result'])) {
                    $this->line(is_string($result['result'])
                        ? $result['result']
                        : json_encode($result['result'], JSON_PRETTY_PRINT));
                }

                return self::FAILURE;
            }

            // Full app path: in-app notification row + push channel resolution
            if ($this->option('via-app') && $userId) {
                $user = User::query()->find($userId);
                if ($user) {
                    $channels = $notifications->resolveChannels($user);
                    $this->line('User notification channels: '.implode(', ', $channels));
                    $this->info('Sending via NotificationService (app channels)…');
                    $notifications->send($user, 'system_test', [
                        'title' => 'SiteDrop app test',
                        'body' => 'In-app + push path — '.now()->toDateTimeString(),
                        'action_url' => '/notifications',
                    ]);
                    $this->info('NotificationService::send completed (check device + in-app list)');
                }
            }

            return self::SUCCESS;
        }

        return $status['configured'] ? self::SUCCESS : self::FAILURE;
    }
}
