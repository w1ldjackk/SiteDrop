<?php

namespace App\Services\Notification;

use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * FCM push sender.
 *
 * Prefers HTTP v1 (service account JSON) and falls back to the legacy
 * server key endpoint when configured.
 */
class PushNotificationService
{
    protected string $legacyUrl = 'https://fcm.googleapis.com/fcm/send';

    protected ?string $serverKey;

    protected ?string $projectId;

    protected ?string $credentialsPath;

    public function __construct()
    {
        $this->serverKey = config('services.fcm.server_key') ?: null;
        $this->projectId = config('services.fcm.project_id')
            ?: config('services.firebase.project_id')
            ?: null;
        $path = config('services.fcm.credentials');
        $this->credentialsPath = $path ? $this->resolvePath((string) $path) : null;
    }

    /**
     * @return array{http_v1: bool, legacy: bool, project_id: ?string, credentials_path: ?string, credentials_readable: bool}
     */
    public function status(): array
    {
        $readable = $this->credentialsPath !== null
            && is_file($this->credentialsPath)
            && is_readable($this->credentialsPath);

        return [
            'http_v1' => $readable && filled($this->projectId),
            'legacy' => filled($this->serverKey),
            'project_id' => $this->projectId,
            'credentials_path' => $this->credentialsPath,
            'credentials_readable' => $readable,
            'configured' => ($readable && filled($this->projectId)) || filled($this->serverKey),
        ];
    }

    /**
     * @param  array<string, mixed>|null  $data
     * @return array{success: bool, message: string, transport?: string, result?: mixed, status_code?: int}
     */
    public function send(string $token, string $title, string $body, ?array $data = null): array
    {
        $token = trim($token);
        if ($token === '') {
            return ['success' => false, 'message' => 'Empty FCM token'];
        }

        $status = $this->status();
        if (! $status['configured']) {
            Log::warning('FCM not configured (set FIREBASE_CREDENTIALS or FCM_SERVER_KEY)');

            return ['success' => false, 'message' => 'FCM not configured'];
        }

        // Prefer HTTP v1.
        if ($status['http_v1']) {
            try {
                return $this->sendHttpV1($token, $title, $body, $data);
            } catch (\Throwable $e) {
                Log::error('FCM HTTP v1 error', [
                    'error' => $e->getMessage(),
                    'token_suffix' => substr($token, -10),
                ]);

                // Fall through to legacy if available.
                if (! $status['legacy']) {
                    return [
                        'success' => false,
                        'message' => $e->getMessage(),
                    ];
                }
            }
        }

        if ($status['legacy']) {
            return $this->sendLegacy($token, $title, $body, $data);
        }

        return ['success' => false, 'message' => 'FCM not configured'];
    }

    /**
     * @param  array<string, mixed>|null  $data
     * @return array{success: bool, message: string, transport?: string, result?: mixed, status_code?: int}
     */
    protected function sendHttpV1(string $token, string $title, string $body, ?array $data): array
    {
        $accessToken = $this->getAccessToken();
        $url = sprintf(
            'https://fcm.googleapis.com/v1/projects/%s/messages:send',
            rawurlencode((string) $this->projectId)
        );

        $stringData = [];
        foreach ($data ?? [] as $key => $value) {
            if ($value === null) {
                continue;
            }
            $stringData[(string) $key] = is_scalar($value)
                ? (string) $value
                : json_encode($value, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        }

        $message = [
            'token' => $token,
            'notification' => [
                'title' => $title,
                'body' => $body,
            ],
            'android' => [
                'priority' => 'HIGH',
                'notification' => [
                    'sound' => 'default',
                    'channel_id' => 'sitedrop_default',
                ],
            ],
            'apns' => [
                'payload' => [
                    'aps' => [
                        'sound' => 'default',
                        'badge' => 1,
                    ],
                ],
            ],
            'webpush' => [
                'notification' => [
                    'title' => $title,
                    'body' => $body,
                ],
                'fcm_options' => [
                    'link' => config('app.url'),
                ],
            ],
        ];

        if ($stringData !== []) {
            $message['data'] = $stringData;
        }

        $response = Http::withToken($accessToken)
            ->acceptJson()
            ->post($url, ['message' => $message]);

        if ($response->successful()) {
            return [
                'success' => true,
                'message' => 'Push notification sent',
                'transport' => 'http_v1',
                'result' => $response->json(),
            ];
        }

        Log::warning('FCM HTTP v1 request failed', [
            'status' => $response->status(),
            'body' => $response->json() ?? $response->body(),
            'token_suffix' => substr($token, -10),
        ]);

        return [
            'success' => false,
            'message' => 'FCM HTTP v1 request failed',
            'transport' => 'http_v1',
            'status_code' => $response->status(),
            'result' => $response->json() ?? $response->body(),
        ];
    }

    /**
     * @param  array<string, mixed>|null  $data
     * @return array{success: bool, message: string, transport?: string, result?: mixed, status_code?: int}
     */
    protected function sendLegacy(string $token, string $title, string $body, ?array $data): array
    {
        try {
            $payload = [
                'to' => $token,
                'notification' => [
                    'title' => $title,
                    'body' => $body,
                    'sound' => 'default',
                    'badge' => 1,
                ],
                'data' => $data ?? [],
                'priority' => 'high',
                'content_available' => true,
            ];

            $response = Http::withHeaders([
                'Authorization' => 'key='.$this->serverKey,
                'Content-Type' => 'application/json',
            ])->post($this->legacyUrl, $payload);

            if ($response->successful()) {
                return [
                    'success' => true,
                    'message' => 'Push notification sent',
                    'transport' => 'legacy',
                    'result' => $response->json(),
                ];
            }

            return [
                'success' => false,
                'message' => 'FCM legacy request failed',
                'transport' => 'legacy',
                'status_code' => $response->status(),
                'result' => $response->json() ?? $response->body(),
            ];
        } catch (\Throwable $e) {
            Log::error('FCM legacy send error', [
                'error' => $e->getMessage(),
                'token_suffix' => substr($token, -10),
            ]);

            return [
                'success' => false,
                'message' => $e->getMessage(),
                'transport' => 'legacy',
            ];
        }
    }

    protected function getAccessToken(): string
    {
        $cacheKey = 'fcm_oauth_access_token_'.md5((string) $this->credentialsPath);
        $cached = Cache::get($cacheKey);
        if (is_string($cached) && $cached !== '') {
            return $cached;
        }

        $sa = $this->loadServiceAccount();
        $now = time();
        $header = $this->base64UrlEncode(json_encode(['alg' => 'RS256', 'typ' => 'JWT'], JSON_THROW_ON_ERROR));
        $claims = $this->base64UrlEncode(json_encode([
            'iss' => $sa['client_email'],
            'scope' => 'https://www.googleapis.com/auth/firebase.messaging',
            'aud' => 'https://oauth2.googleapis.com/token',
            'iat' => $now,
            'exp' => $now + 3600,
        ], JSON_THROW_ON_ERROR));

        $unsigned = $header.'.'.$claims;
        $privateKey = openssl_pkey_get_private($sa['private_key']);
        if ($privateKey === false) {
            throw new \RuntimeException('Invalid Firebase service account private key');
        }

        $signature = '';
        $ok = openssl_sign($unsigned, $signature, $privateKey, OPENSSL_ALGO_SHA256);
        if (! $ok) {
            throw new \RuntimeException('Failed to sign FCM service account JWT');
        }

        $jwt = $unsigned.'.'.$this->base64UrlEncode($signature);

        $response = Http::asForm()->post('https://oauth2.googleapis.com/token', [
            'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
            'assertion' => $jwt,
        ]);

        if (! $response->successful()) {
            throw new \RuntimeException(
                'FCM OAuth token exchange failed: '.($response->body() ?: $response->status())
            );
        }

        $accessToken = (string) $response->json('access_token');
        $expiresIn = (int) ($response->json('expires_in') ?? 3600);
        if ($accessToken === '') {
            throw new \RuntimeException('FCM OAuth response missing access_token');
        }

        // Cache slightly under expiry.
        Cache::put($cacheKey, $accessToken, now()->addSeconds(max(60, $expiresIn - 60)));

        return $accessToken;
    }

    /**
     * @return array{client_email: string, private_key: string, project_id?: string}
     */
    protected function loadServiceAccount(): array
    {
        if (! $this->credentialsPath || ! is_readable($this->credentialsPath)) {
            throw new \RuntimeException('Firebase credentials file not readable: '.$this->credentialsPath);
        }

        $json = file_get_contents($this->credentialsPath);
        if ($json === false) {
            throw new \RuntimeException('Unable to read Firebase credentials file');
        }

        /** @var array<string, mixed> $data */
        $data = json_decode($json, true, 512, JSON_THROW_ON_ERROR);

        if (empty($data['client_email']) || empty($data['private_key'])) {
            throw new \RuntimeException('Firebase credentials missing client_email/private_key');
        }

        // Prefer project_id from the service account when env is empty.
        if (empty($this->projectId) && ! empty($data['project_id'])) {
            $this->projectId = (string) $data['project_id'];
        }

        return [
            'client_email' => (string) $data['client_email'],
            'private_key' => (string) $data['private_key'],
            'project_id' => isset($data['project_id']) ? (string) $data['project_id'] : null,
        ];
    }

    protected function resolvePath(string $path): string
    {
        if ($path === '') {
            return $path;
        }

        // Absolute / Windows drive / UNC
        if (str_starts_with($path, DIRECTORY_SEPARATOR)
            || preg_match('/^[A-Za-z]:[\\\\\\/]/', $path)
            || str_starts_with($path, '\\\\')) {
            return $path;
        }

        return base_path($path);
    }

    protected function base64UrlEncode(string $data): string
    {
        return rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
    }
}
