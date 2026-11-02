<?php

namespace App\Services\Notification;

use App\Http\Controllers\Backend\SystemSettingController;
use App\Jobs\Notification\SendPushNotification;
use App\Models\Notification;
use App\Models\User;
use Illuminate\Support\Facades\Log;

class NotificationService
{
    /**
     * Send notification via multiple channels, respecting user + platform preferences.
     *
     * Defaults (when user has no explicit notification_channels):
     * - in_app: on
     * - email: on
     * - push: on (so FCM reaches the mobile/web app when a token exists)
     * - sms: off by default (costs per message — user opts in via
     *     notification_channels and platform enables notification_sms_enabled)
     *
     * Platform toggles from System Settings (notification_*_enabled) apply as defaults.
     */
    public function send(User $user, string $type, array $data): void
    {
        $enabledChannels = $this->resolveChannels($user);

        if (in_array('in_app', $enabledChannels, true)) {
            $this->createInAppNotification($user, $type, $data);
        }

        if (in_array('push', $enabledChannels, true) && filled($user->fcm_token)) {
            $this->sendPushNotification($user, $type, $data);
        } elseif (in_array('push', $enabledChannels, true) && ! filled($user->fcm_token)) {
            Log::debug('Push skipped — user has no fcm_token', [
                'user_id' => $user->id,
                'type' => $type,
            ]);
        }

        if (in_array('email', $enabledChannels, true) && filled($user->email)) {
            $this->sendEmailNotification($user, $type, $data);
        }

        if (in_array('sms', $enabledChannels, true) && filled($user->phone)) {
            $this->sendSmsNotification($user, $type, $data);
        }
    }

    /**
     * @return list<string>
     */
    public function resolveChannels(User $user): array
    {
        $prefs = is_array($user->preferences) ? $user->preferences : [];

        if (! empty($prefs['notification_channels']) && is_array($prefs['notification_channels'])) {
            return array_values(array_unique(array_map('strval', $prefs['notification_channels'])));
        }

        $channels = [];
        if ($this->platformChannelEnabled('in_app', true)) {
            $channels[] = 'in_app';
        }
        if ($this->platformChannelEnabled('email', true)) {
            $channels[] = 'email';
        }
        if ($this->platformChannelEnabled('push', true)) {
            $channels[] = 'push';
        }
        if ($this->platformChannelEnabled('sms', false)) {
            $channels[] = 'sms';
        }

        return $channels;
    }

    protected function platformChannelEnabled(string $channel, bool $default): bool
    {
        $key = 'notification_'.$channel.'_enabled';

        try {
            $value = SystemSettingController::resolve($key, $default);
        } catch (\Throwable) {
            return $default;
        }

        if ($value === null || $value === '') {
            return $default;
        }

        return filter_var($value, FILTER_VALIDATE_BOOLEAN);
    }

    private function createInAppNotification(User $user, string $type, array $data): void
    {
        $templates = $this->getNotificationTemplates();

        if (! isset($templates[$type])) {
            Log::warning('Notification template not found', ['type' => $type]);

            return;
        }

        $template = $templates[$type];

        Notification::createNotification(
            $user->id,
            $this->replacePlaceholders($template['title'], $data),
            $this->replacePlaceholders($template['body'], $data),
            $template['category'] ?? 'system',
            $data,
            'in_app',
            $template['priority'] ?? 'normal',
            $data['action_url'] ?? null,
            $data['image_url'] ?? null
        );
    }

    private function sendPushNotification(User $user, string $type, array $data): void
    {
        if (! filled($user->fcm_token)) {
            return;
        }

        $templates = $this->getNotificationTemplates();
        $template = $templates[$type] ?? null;

        if (! $template) {
            Log::warning('Push skipped — unknown template', ['type' => $type]);

            return;
        }

        $title = $this->replacePlaceholders($template['title'], $data);
        $body = $this->replacePlaceholders($template['body'], $data);

        // Stringify data for FCM HTTP v1
        $payload = [];
        foreach ($data as $key => $value) {
            if ($value === null) {
                continue;
            }
            $payload[(string) $key] = is_scalar($value)
                ? (string) $value
                : json_encode($value, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        }
        $payload['type'] = $type;
        $payload['notification_type'] = $type;
        $payload['route'] = $data['route'] ?? $this->routeForType($type);

        $job = new SendPushNotification(
            (string) $user->fcm_token,
            $title,
            $body,
            $payload
        );

        // Local / no worker: send immediately so the app receives push without queue:work.
        // Production can set FCM_DISPATCH_SYNC=false to always queue.
        $sync = filter_var(
            env('FCM_DISPATCH_SYNC', config('queue.default') === 'sync' || app()->environment('local')),
            FILTER_VALIDATE_BOOLEAN
        );

        if ($sync) {
            dispatch_sync($job);
        } else {
            dispatch($job)->onQueue('notifications');
        }
    }

    private function sendEmailNotification(User $user, string $type, array $data): void
    {
        try {
            $templates = $this->getNotificationTemplates();
            $title = $this->replacePlaceholders($templates[$type]['title'] ?? 'Notification', $data);
            $body = $this->replacePlaceholders($templates[$type]['body'] ?? '', $data);

            \Illuminate\Support\Facades\Mail::raw(
                "You have a new notification:\n\n{$title}\n\n{$body}\n\n".
                (isset($data['action_url']) ? 'View: '.url((string) $data['action_url']) : ''),
                function ($message) use ($user, $title) {
                    $message->to($user->email)
                        ->subject('[SiteDrop] '.$title);
                }
            );
        } catch (\Throwable $e) {
            Log::warning('Failed to send notification email', ['error' => $e->getMessage()]);
        }
    }

    private function sendSmsNotification(User $user, string $type, array $data): void
    {
        try {
            $templates = $this->getNotificationTemplates();
            $title = $this->replacePlaceholders($templates[$type]['title'] ?? 'Notification', $data);
            $body = $this->replacePlaceholders($templates[$type]['body'] ?? '', $data);

            $text = trim($title.($body !== '' ? ' — '.$body : ''));
            $text = mb_substr('SiteDrop: '.$text, 0, 480);

            app(\App\Services\Sms\SmsService::class)->send((string) $user->phone, $text);
        } catch (\Throwable $e) {
            Log::warning('Failed to send notification SMS', ['error' => $e->getMessage()]);
        }
    }

    /**
     * @return array<string, array{title: string, body: string, category?: string, priority?: string}>
     */
    private function getNotificationTemplates(): array
    {
        return [
            'order_confirmation' => [
                'title' => 'Order #{{order_number}} Confirmed',
                'body' => 'Your order for {{items}} has been confirmed. Total: {{total_amount}}',
                'category' => 'order',
                'priority' => 'high',
            ],
            'new_order_notification' => [
                'title' => 'New Order #{{order_number}}',
                'body' => 'You have received a new order from {{buyer_name}} for {{items}}',
                'category' => 'order',
                'priority' => 'high',
            ],
            'order_status_update' => [
                'title' => 'Order #{{order_number}} Update',
                'body' => 'Your order status has been updated to {{status_label}}',
                'category' => 'order',
                'priority' => 'normal',
            ],
            'payment_confirmation' => [
                'title' => 'Payment Received',
                'body' => 'Your payment of {{amount}} for order #{{order_number}} has been confirmed',
                'category' => 'payment',
                'priority' => 'high',
            ],
            'delivery_assigned' => [
                'title' => 'Delivery Assigned',
                'body' => 'Your order #{{order_number}} has been assigned to a driver',
                'category' => 'delivery',
                'priority' => 'high',
            ],
            // Used by admin / fcm:status style tests
            'system_test' => [
                'title' => '{{title}}',
                'body' => '{{body}}',
                'category' => 'system',
                'priority' => 'normal',
            ],
            'fcm_test' => [
                'title' => 'SiteDrop test',
                'body' => '{{body}}',
                'category' => 'system',
                'priority' => 'normal',
            ],
            // Wallet
            'wallet_credited' => [
                'title' => 'Wallet credited',
                'body' => 'GH₵ {{amount}} was added to your wallet. Balance: GH₵ {{balance}}. {{description}}',
                'category' => 'payment',
                'priority' => 'high',
            ],
            'wallet_debited' => [
                'title' => 'Wallet debited',
                'body' => 'GH₵ {{amount}} was deducted from your wallet. Balance: GH₵ {{balance}}. {{description}}',
                'category' => 'payment',
                'priority' => 'high',
            ],
            'wallet_deposit_requested' => [
                'title' => 'Deposit request submitted',
                'body' => 'Your deposit of GH₵ {{amount}} ({{reference}}) is pending admin approval.',
                'category' => 'payment',
                'priority' => 'normal',
            ],
            'wallet_withdrawal_requested' => [
                'title' => 'Withdrawal request submitted',
                'body' => 'Your withdrawal of GH₵ {{amount}} ({{reference}}) is pending admin approval.',
                'category' => 'payment',
                'priority' => 'normal',
            ],
            'wallet_transaction_approved' => [
                'title' => 'Wallet request approved',
                'body' => 'Your {{type}} of GH₵ {{amount}} ({{reference}}) was approved. Balance: GH₵ {{balance}}.',
                'category' => 'payment',
                'priority' => 'high',
            ],
            'wallet_transaction_rejected' => [
                'title' => 'Wallet request rejected',
                'body' => 'Your request {{reference}} for GH₵ {{amount}} was rejected. {{reason}}',
                'category' => 'payment',
                'priority' => 'high',
            ],
            'wallet_activated' => [
                'title' => 'Wallet activated',
                'body' => 'Your SiteDrop wallet is active again.',
                'category' => 'system',
                'priority' => 'normal',
            ],
            'wallet_suspended' => [
                'title' => 'Wallet suspended',
                'body' => 'Your SiteDrop wallet has been suspended. Contact support for help.',
                'category' => 'system',
                'priority' => 'high',
            ],
            'wallet_admin_pending' => [
                'title' => 'Wallet {{type}} pending',
                'body' => '{{user_name}} requested a {{type}} of GH₵ {{amount}} ({{reference}}).',
                'category' => 'system',
                'priority' => 'high',
            ],
        ];
    }

    private function replacePlaceholders(string $text, array $data): string
    {
        foreach ($data as $key => $value) {
            if (is_array($value) || is_object($value)) {
                $value = json_encode($value);
            }
            $text = str_replace('{{'.$key.'}}', (string) ($value ?? ''), $text);
        }

        return $text;
    }

    /**
     * Deep-link route bundled into the FCM data payload so the mobile apps
     * can open the right screen on notification tap. Routes exist in all
     * three apps (buyer/seller/driver).
     */
    private function routeForType(string $type): string
    {
        if (str_starts_with($type, 'wallet')) {
            return '/wallet';
        }

        return '/notifications';
    }
}
