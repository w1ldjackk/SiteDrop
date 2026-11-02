<?php
// app/Jobs/Notification/SendPushNotification.php

namespace App\Jobs\Notification;

use App\Services\Notification\PushNotificationService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;

class SendPushNotification implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public string $token;
    public string $title;
    public string $body;
    public ?array $data;
    public int $tries = 3;

    public function __construct(string $token, string $title, string $body, ?array $data = null)
    {
        $this->token = $token;
        $this->title = $title;
        $this->body = $body;
        $this->data = $data;
    }

    public function handle(PushNotificationService $pushService): void
    {
        try {
            $result = $pushService->send(
                $this->token,
                $this->title,
                $this->body,
                $this->data
            );

            if ($result['success']) {
                Log::info('Push notification sent', [
                    'title' => $this->title,
                    'body' => $this->body,
                ]);
            } else {
                Log::warning('Push notification failed', [
                    'error' => $result['message'] ?? 'Unknown error',
                    'token' => substr($this->token, -10),
                ]);
            }
        } catch (\Exception $e) {
            Log::error('Push notification error', [
                'error' => $e->getMessage(),
                'token' => substr($this->token, -10),
            ]);

            if ($this->attempts() < 3) {
                $this->release(now()->addMinutes(5));
            }
        }
    }
}
