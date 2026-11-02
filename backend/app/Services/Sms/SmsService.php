<?php

namespace App\Services\Sms;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * Outbound SMS with env-selected provider and safe local fallback.
 *
 * Providers (SMS_PROVIDER):
 * - log     : write to laravel.log, always "succeeds" (dev default)
 * - hubtel  : Hubtel SMS API (Basic auth client_id:client_secret)
 * - arkesel : Arkesel SMS API (api-key header)
 *
 * Never throws — returns bool and logs failures so notification flows
 * (OTP, order updates) are never broken by an SMS outage.
 */
class SmsService
{
    public function configured(): bool
    {
        $provider = strtolower((string) config('services.sms.provider', 'log'));

        return match ($provider) {
            'hubtel' => filled(config('services.sms.hubtel_client_id'))
                && filled(config('services.sms.hubtel_client_secret')),
            'arkesel' => filled(config('services.sms.arkesel_api_key')),
            default => false,
        };
    }

    public function provider(): string
    {
        return strtolower((string) config('services.sms.provider', 'log'));
    }

    public function send(string $phone, string $message): bool
    {
        $to = $this->normalize($phone);

        if (! $this->configured()) {
            Log::info('SMS via log fallback (no provider configured)', [
                'phone' => $this->mask($to),
                'message_length' => strlen($message),
            ]);

            return true;
        }

        return match ($this->provider()) {
            'hubtel' => $this->sendViaHubtel($to, $message),
            'arkesel' => $this->sendViaArkesel($to, $message),
            default => true,
        };
    }

    private function sendViaHubtel(string $to, string $message): bool
    {
        try {
            $response = Http::withBasicAuth(
                (string) config('services.sms.hubtel_client_id'),
                (string) config('services.sms.hubtel_client_secret')
            )->timeout(15)->get('https://smsc.hubtel.com/v1/messages/send', [
                'From' => (string) config('services.sms.sender_id', 'SiteDrop'),
                'To' => $to,
                'Content' => $message,
            ]);

            if ($response->successful()) {
                Log::info('SMS sent via Hubtel', ['phone' => $this->mask($to)]);

                return true;
            }

            Log::warning('Hubtel SMS failed', [
                'phone' => $this->mask($to),
                'status' => $response->status(),
                'body' => mb_substr((string) $response->body(), 0, 500),
            ]);

            return false;
        } catch (\Throwable $e) {
            Log::warning('Hubtel SMS exception', [
                'phone' => $this->mask($to),
                'error' => $e->getMessage(),
            ]);

            return false;
        }
    }

    private function sendViaArkesel(string $to, string $message): bool
    {
        try {
            $response = Http::withHeaders([
                'api-key' => (string) config('services.sms.arkesel_api_key'),
            ])->timeout(15)->post('https://sms.arkesel.com/api/v2/sms/send', [
                'sender' => (string) config('services.sms.sender_id', 'SiteDrop'),
                'message' => $message,
                'recipients' => [$to],
            ]);

            if ($response->successful()) {
                Log::info('SMS sent via Arkesel', ['phone' => $this->mask($to)]);

                return true;
            }

            Log::warning('Arkesel SMS failed', [
                'phone' => $this->mask($to),
                'status' => $response->status(),
                'body' => mb_substr((string) $response->body(), 0, 500),
            ]);

            return false;
        } catch (\Throwable $e) {
            Log::warning('Arkesel SMS exception', [
                'phone' => $this->mask($to),
                'error' => $e->getMessage(),
            ]);

            return false;
        }
    }

    /**
     * Normalize to international format without "+": 233XXXXXXXXX.
     */
    private function normalize(string $phone): string
    {
        $digits = preg_replace('/\D/', '', $phone) ?? '';

        if (str_starts_with($digits, '0') && strlen($digits) === 10) {
            return '233'.substr($digits, 1);
        }

        return $digits;
    }

    private function mask(string $phone): string
    {
        $digits = preg_replace('/\D/', '', $phone) ?? '';

        if (strlen($digits) < 6) {
            return '***';
        }

        return substr($digits, 0, 3).str_repeat('*', max(0, strlen($digits) - 6)).substr($digits, -3);
    }
}
