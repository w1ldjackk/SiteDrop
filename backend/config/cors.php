<?php

/**
 * Cross-Origin Resource Sharing (CORS)
 *
 * Used by the web SPA / Vite admin and any browser clients.
 * Native Flutter apps do not use CORS, but correct origins still matter for
 * Sanctum stateful SPA auth and admin tooling.
 *
 * Configure via .env:
 *   CORS_ALLOWED_ORIGINS=http://localhost:8000,http://localhost:5173,...
 *   CORS_SUPPORTS_CREDENTIALS=true
 */

$defaultOrigins = [
    'http://localhost:8000',
    'http://127.0.0.1:8000',
    'http://localhost:5173',
    'http://127.0.0.1:5173',
    'http://10.0.2.2:8000',
];

$envOrigins = array_values(array_filter(array_map(
    'trim',
    explode(',', (string) env('CORS_ALLOWED_ORIGINS', implode(',', $defaultOrigins)))
)));

// Always include APP_URL origin when set
$appUrl = rtrim((string) env('APP_URL', ''), '/');
if ($appUrl !== '' && ! in_array($appUrl, $envOrigins, true)) {
    $envOrigins[] = $appUrl;
}

return [
    'paths' => [
        'api/*',
        'sanctum/csrf-cookie',
        'login',
        'logout',
        'register',
        'user/password',
        'forgot-password',
        'reset-password',
        'email/verification-notification',
        'two-factor-challenge',
    ],

    'allowed_methods' => ['*'],

    'allowed_origins' => $envOrigins,

    'allowed_origins_patterns' => array_values(array_filter([
        // Localhost any port
        '#^https?://localhost(:\d+)?$#',
        '#^https?://127\.0\.0\.1(:\d+)?$#',
        // Android emulator host bridge
        '#^https?://10\.0\.2\.2(:\d+)?$#',
        // Optional LAN pattern for physical devices (set CORS_ALLOW_LAN=true)
        env('CORS_ALLOW_LAN', false)
            ? '#^https?://192\.168\.\d{1,3}\.\d{1,3}(:\d+)?$#'
            : null,
        env('CORS_ALLOW_LAN', false)
            ? '#^https?://10\.\d{1,3}\.\d{1,3}\.\d{1,3}(:\d+)?$#'
            : null,
    ])),

    'allowed_headers' => ['*'],

    'exposed_headers' => [],

    'max_age' => (int) env('CORS_MAX_AGE', 0),

    'supports_credentials' => filter_var(
        env('CORS_SUPPORTS_CREDENTIALS', true),
        FILTER_VALIDATE_BOOLEAN
    ),
];
