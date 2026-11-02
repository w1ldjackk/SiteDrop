<?php

namespace App\Http\Controllers\Backend;

use App\Http\Controllers\Controller;
use App\Models\Setting;
use App\Services\Notification\PushNotificationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Inertia\Inertia;
use Inertia\Response;

/**
 * Global (app-wide) system settings — user_id is null on Setting rows.
 *
 * Defaults come from config / .env; admins can override via DB settings UI.
 * Public mobile config is served by {@see publicConfig()}.
 */
class SystemSettingController extends Controller
{
    /**
     * Keys safe to expose to mobile / public clients (no secrets).
     *
     * @var list<string>
     */
    public const PUBLIC_KEYS = [
        'app_name',
        'support_email',
        'support_phone',
        'support_whatsapp',
        'currency',
        'maintenance_mode',
        'allow_registration',
        'default_theme_mode',
        'sms_enabled',
        'email_enabled',
        // Firebase client options (not server keys)
        'firebase_api_key',
        'firebase_app_id',
        'firebase_messaging_sender_id',
        'firebase_project_id',
        'firebase_storage_bucket',
        'firebase_auth_domain',
        'firebase_measurement_id',
        'firebase_android_api_key',
        'firebase_android_app_id',
        'firebase_ios_api_key',
        'firebase_ios_app_id',
        'firebase_ios_bundle_id',
        'firebase_ios_client_id',
        'firebase_web_api_key',
        'firebase_web_app_id',
        // Web Push VAPID **public** key only (private stays in .env / FCM config)
        'firebase_vapid_public_key',
        // Google Maps (Maps SDK / Distance Matrix client key)
        'google_maps_api_key',
    ];

    /**
     * Known platform keys with defaults + types.
     * Defaults prefer config('services.firebase.*') / env.
     *
     * @return array<string, array{default: mixed, type: string, label: string, group: string}>
     */
    public static function keys(): array
    {
        $fb = config('services.firebase', []);

        return [
            'app_name' => [
                'default' => config('app.name', 'SiteDrop'),
                'type' => 'string',
                'label' => 'App name',
                'group' => 'general',
            ],
            'support_email' => [
                'default' => env('SUPPORT_EMAIL', 'support@sitedrop.gh'),
                'type' => 'string',
                'label' => 'Support email',
                'group' => 'general',
            ],
            'support_phone' => [
                'default' => env('SUPPORT_PHONE', ''),
                'type' => 'string',
                'label' => 'Support phone',
                'group' => 'general',
            ],
            'support_whatsapp' => [
                'default' => env('SUPPORT_WHATSAPP', ''),
                'type' => 'string',
                'label' => 'Support WhatsApp (digits, e.g. 233240000000)',
                'group' => 'general',
            ],
            'currency' => [
                'default' => env('APP_CURRENCY', 'GHS'),
                'type' => 'string',
                'label' => 'Default currency',
                'group' => 'general',
            ],
            'commission_rate' => [
                'default' => env('PLATFORM_COMMISSION_RATE', '10'),
                'type' => 'float',
                'label' => 'Platform commission (%)',
                'group' => 'general',
            ],
            'default_theme_mode' => [
                'default' => 'system',
                'type' => 'string',
                'label' => 'Default theme (system/light/dark)',
                'group' => 'general',
            ],
            'maintenance_mode' => [
                'default' => false,
                'type' => 'boolean',
                'label' => 'Maintenance mode',
                'group' => 'platform',
            ],
            'allow_registration' => [
                'default' => true,
                'type' => 'boolean',
                'label' => 'Allow registration',
                'group' => 'platform',
            ],
            'sms_enabled' => [
                'default' => filter_var(env('SMS_ENABLED', false), FILTER_VALIDATE_BOOLEAN),
                'type' => 'boolean',
                'label' => 'SMS notifications enabled',
                'group' => 'platform',
            ],
            'email_enabled' => [
                'default' => filter_var(env('EMAIL_ENABLED', true), FILTER_VALIDATE_BOOLEAN),
                'type' => 'boolean',
                'label' => 'Email notifications enabled',
                'group' => 'platform',
            ],

            // —— Default notification channels (user prefs can override) ——
            'notification_in_app_enabled' => [
                'default' => true,
                'type' => 'boolean',
                'label' => 'Default: in-app notifications',
                'group' => 'notifications',
            ],
            'notification_email_enabled' => [
                'default' => true,
                'type' => 'boolean',
                'label' => 'Default: email notifications',
                'group' => 'notifications',
            ],
            'notification_push_enabled' => [
                'default' => true,
                'type' => 'boolean',
                'label' => 'Default: push to mobile/web app (FCM)',
                'group' => 'notifications',
            ],
            'notification_sms_enabled' => [
                'default' => false,
                'type' => 'boolean',
                'label' => 'Default: SMS notifications',
                'group' => 'notifications',
            ],

            // —— Firebase client (shared / fallback) ——
            'firebase_api_key' => [
                'default' => $fb['api_key'] ?? '',
                'type' => 'string',
                'label' => 'Firebase API key (default)',
                'group' => 'firebase',
            ],
            'firebase_app_id' => [
                'default' => $fb['app_id'] ?? '',
                'type' => 'string',
                'label' => 'Firebase App ID (default)',
                'group' => 'firebase',
            ],
            'firebase_messaging_sender_id' => [
                'default' => $fb['messaging_sender_id'] ?? '',
                'type' => 'string',
                'label' => 'Firebase messaging sender ID',
                'group' => 'firebase',
            ],
            'firebase_project_id' => [
                'default' => $fb['project_id'] ?? '',
                'type' => 'string',
                'label' => 'Firebase project ID',
                'group' => 'firebase',
            ],
            'firebase_storage_bucket' => [
                'default' => $fb['storage_bucket'] ?? '',
                'type' => 'string',
                'label' => 'Firebase storage bucket',
                'group' => 'firebase',
            ],
            'firebase_auth_domain' => [
                'default' => $fb['auth_domain'] ?? '',
                'type' => 'string',
                'label' => 'Firebase auth domain',
                'group' => 'firebase',
            ],
            'firebase_measurement_id' => [
                'default' => $fb['measurement_id'] ?? '',
                'type' => 'string',
                'label' => 'Firebase measurement ID (web analytics)',
                'group' => 'firebase',
            ],

            // —— Platform-specific overrides (empty = fall back to core) ——
            'firebase_android_api_key' => [
                'default' => self::nonPlaceholder(data_get($fb, 'android.api_key'))
                    ?: ($fb['api_key'] ?? ''),
                'type' => 'string',
                'label' => 'Firebase Android API key',
                'group' => 'firebase',
            ],
            'firebase_android_app_id' => [
                'default' => self::nonPlaceholder(data_get($fb, 'android.app_id'))
                    ?: ($fb['app_id'] ?? ''),
                'type' => 'string',
                'label' => 'Firebase Android App ID',
                'group' => 'firebase',
            ],
            'firebase_ios_api_key' => [
                'default' => self::nonPlaceholder(data_get($fb, 'ios.api_key'))
                    ?: ($fb['api_key'] ?? ''),
                'type' => 'string',
                'label' => 'Firebase iOS API key',
                'group' => 'firebase',
            ],
            'firebase_ios_app_id' => [
                'default' => self::nonPlaceholder(data_get($fb, 'ios.app_id'))
                    ?: ($fb['app_id'] ?? ''),
                'type' => 'string',
                'label' => 'Firebase iOS App ID',
                'group' => 'firebase',
            ],
            'firebase_ios_bundle_id' => [
                'default' => data_get($fb, 'ios.bundle_id', 'com.sitedrop.sitedropMobile'),
                'type' => 'string',
                'label' => 'Firebase iOS bundle ID',
                'group' => 'firebase',
            ],
            'firebase_ios_client_id' => [
                'default' => data_get($fb, 'ios.client_id', ''),
                'type' => 'string',
                'label' => 'Firebase iOS OAuth client ID',
                'group' => 'firebase',
            ],
            'firebase_web_api_key' => [
                'default' => self::nonPlaceholder(data_get($fb, 'web.api_key'))
                    ?: ($fb['api_key'] ?? ''),
                'type' => 'string',
                'label' => 'Firebase Web API key',
                'group' => 'firebase',
            ],
            'firebase_web_app_id' => [
                'default' => self::nonPlaceholder(data_get($fb, 'web.app_id'))
                    ?: ($fb['app_id'] ?? ''),
                'type' => 'string',
                'label' => 'Firebase Web App ID',
                'group' => 'firebase',
            ],
            'firebase_vapid_public_key' => [
                'default' => data_get($fb, 'web.vapid_public_key', config('services.fcm.vapid_public_key', '')),
                'type' => 'string',
                'label' => 'Firebase Web Push VAPID public key',
                'group' => 'firebase',
            ],

            // —— Google Maps ——
            'google_maps_api_key' => [
                'default' => config('services.google_maps.api_key', env('GOOGLE_MAPS_API_KEY', '')),
                'type' => 'string',
                'label' => 'Google Maps API key (mobile / maps)',
                'group' => 'maps',
            ],
        ];
    }

    /**
     * Resolve a setting: DB override → default from keys()/env.
     * Placeholder values (YOUR_API_KEY, xxxx…) are treated as empty.
     */
    public static function resolve(string $key, mixed $fallback = null): mixed
    {
        $meta = self::keys()[$key] ?? null;
        $default = $meta['default'] ?? $fallback;
        $type = $meta['type'] ?? null;

        $value = Setting::get($key, $default, $type);

        if (is_string($value) && self::isPlaceholderValue($value)) {
            // Prefer non-placeholder default, then empty string.
            if (is_string($default) && ! self::isPlaceholderValue($default)) {
                return $default;
            }

            return is_string($fallback) ? $fallback : '';
        }

        return $value;
    }

    /**
     * True when a config string is a stub / template, not a real secret.
     */
    public static function isPlaceholderValue(mixed $value): bool
    {
        if ($value === null) {
            return true;
        }
        if (! is_string($value)) {
            return false;
        }

        $v = trim($value);
        if ($v === '') {
            return true;
        }

        $upper = strtoupper($v);

        return $v === 'YOUR_API_KEY'
            || str_contains($upper, 'XXXX')
            || str_contains($v, 'AIzaSyBxxxxx')
            || str_contains($v, '123456789')
            || str_starts_with($upper, 'YOUR_')
            || str_contains($upper, 'REPLACE_ME')
            || str_contains($upper, 'TODO');
    }

    protected static function nonPlaceholder(mixed $value): string
    {
        if (! is_string($value) || self::isPlaceholderValue($value)) {
            return '';
        }

        return trim($value);
    }

    /**
     * Admin UI — list editable system settings.
     */
    public function index(PushNotificationService $push): Response
    {
        // Clean known placeholder DB overrides so the form shows env defaults.
        $this->scrubFirebasePlaceholdersInDatabase();

        $settings = [];
        foreach (self::keys() as $key => $meta) {
            $value = self::resolve($key);

            $settings[] = [
                'name' => $key,
                'label' => $meta['label'],
                'type' => $meta['type'],
                'group' => $meta['group'] ?? 'other',
                'val' => $value,
            ];
        }

        // Include any extra global keys not in keys()
        $extras = Setting::query()
            ->whereNull('user_id')
            ->whereNotIn('name', array_keys(self::keys()))
            ->orderBy('name')
            ->get()
            ->map(fn (Setting $s) => [
                'name' => $s->name,
                'label' => $s->name,
                'type' => $s->type,
                'group' => 'other',
                'val' => Setting::castValue($s->val, $s->type),
            ])
            ->values()
            ->all();

        return Inertia::render('backend/SystemSettings/index', [
            'settings' => array_merge($settings, $extras),
            'integrations' => $this->buildIntegrationsHealth($push),
        ]);
    }

    /**
     * Remove stub values saved into settings (e.g. YOUR_API_KEY) so .env/config apply.
     */
    protected function scrubFirebasePlaceholdersInDatabase(): void
    {
        $rows = Setting::query()
            ->whereNull('user_id')
            ->where('name', 'like', 'firebase_%')
            ->get();

        foreach ($rows as $row) {
            if (self::isPlaceholderValue($row->val)) {
                $row->delete();
            }
        }
    }

    /**
     * Health snapshot for System Settings UI (no secrets).
     *
     * @return array<string, mixed>
     */
    protected function buildIntegrationsHealth(PushNotificationService $push): array
    {
        $flat = [];
        foreach (self::PUBLIC_KEYS as $key) {
            $flat[$key] = self::resolve($key);
        }

        $web = $this->buildFirebaseClientOptions($flat, 'web');
        $android = $this->buildFirebaseClientOptions($flat, 'android');
        $ios = $this->buildFirebaseClientOptions($flat, 'ios');
        $fcm = $push->status();

        $tokenUsers = \App\Models\User::query()
            ->whereNotNull('fcm_token')
            ->where('fcm_token', '!=', '')
            ->count();

        $mapsKey = (string) ($flat['google_maps_api_key'] ?? '');
        $mapsOk = $mapsKey !== '' && ! self::isPlaceholderValue($mapsKey);

        $clientOk = (bool) ($web['configured'] ?? false);
        $serverOk = (bool) ($fcm['configured'] ?? false);

        return [
            'firebase' => [
                'project_id' => $flat['firebase_project_id'] ?? config('services.firebase.project_id'),
                'client_configured' => $clientOk,
                'web_configured' => (bool) ($web['configured'] ?? false),
                'android_configured' => (bool) ($android['configured'] ?? false),
                'ios_configured' => (bool) ($ios['configured'] ?? false),
                'vapid_public_set' => filled($flat['firebase_vapid_public_key'] ?? null),
                'server_push_configured' => $serverOk,
                'server_http_v1' => (bool) ($fcm['http_v1'] ?? false),
                'server_legacy' => (bool) ($fcm['legacy'] ?? false),
                'credentials_readable' => (bool) ($fcm['credentials_readable'] ?? false),
                'devices_with_token' => $tokenUsers,
                'overall' => $clientOk && $serverOk ? 'ok' : ($clientOk || $serverOk ? 'partial' : 'missing'),
                'notes' => array_values(array_filter([
                    $clientOk ? null : 'Client Firebase keys incomplete (check Core / Web fields or .env)',
                    $serverOk ? null : 'Server push not ready — add storage/app/firebase/service-account.json',
                    ($web['configured'] ?? false) ? null : 'Web client options incomplete',
                    ($android['configured'] ?? false) ? null : 'Android client options incomplete (optional until native app)',
                    ($ios['configured'] ?? false) ? null : 'iOS client options incomplete (optional until native app)',
                    filled($flat['firebase_vapid_public_key'] ?? null) ? null : 'VAPID public key missing (needed for web push tokens)',
                    $tokenUsers > 0 ? null : 'No device tokens registered yet — open the app signed-in and allow notifications',
                ])),
            ],
            'maps' => [
                'configured' => $mapsOk,
                'overall' => $mapsOk ? 'ok' : 'missing',
                'notes' => $mapsOk
                    ? []
                    : ['GOOGLE_MAPS_API_KEY not set (address map on mobile/web)'],
            ],
        ];
    }

    /**
     * Admin UI — save system settings.
     */
    public function update(Request $request): RedirectResponse
    {
        $payload = $request->input('settings', $request->except(['_token', '_method']));

        if (! is_array($payload)) {
            return back()->with('error', 'Invalid settings payload.');
        }

        $known = self::keys();

        foreach ($payload as $name => $value) {
            if (! is_string($name) || $name === '') {
                continue;
            }

            $type = $known[$name]['type']
                ?? (is_bool($value) ? 'boolean' : (is_array($value) ? 'json' : 'string'));

            if (is_bool($value) || $type === 'boolean') {
                $type = 'boolean';
            }

            Setting::set($name, $value, $type);
        }

        return back()->with('success', 'System settings saved.');
    }

    /**
     * Public mobile / client bootstrap config.
     * GET /api/v1/config
     *
     * Returns only {@see PUBLIC_KEYS} + structured `firebase` object for the app.
     * Never includes FCM server keys.
     */
    public function publicConfig(Request $request): JsonResponse
    {
        $flat = [];
        foreach (self::PUBLIC_KEYS as $key) {
            $flat[$key] = self::resolve($key);
        }

        $platform = strtolower((string) $request->query('platform', 'android'));

        $firebase = $this->buildFirebaseClientOptions($flat, $platform);
        $mapsApiKey = (string) ($flat['google_maps_api_key'] ?? '');
        $vapidPublic = (string) ($flat['firebase_vapid_public_key'] ?? '');

        return response()->json([
            'status' => 'success',
            'data' => [
                'app_name' => $flat['app_name'] ?? config('app.name'),
                'support_email' => $flat['support_email'] ?? null,
                'support_phone' => $flat['support_phone'] ?? null,
                'support_whatsapp' => $flat['support_whatsapp'] ?? null,
                'currency' => $flat['currency'] ?? 'GHS',
                'maintenance_mode' => (bool) ($flat['maintenance_mode'] ?? false),
                'allow_registration' => (bool) ($flat['allow_registration'] ?? true),
                'default_theme_mode' => $flat['default_theme_mode'] ?? 'system',
                'sms_enabled' => (bool) ($flat['sms_enabled'] ?? false),
                'email_enabled' => (bool) ($flat['email_enabled'] ?? true),
                'google_maps_api_key' => $mapsApiKey !== '' ? $mapsApiKey : null,
                'maps' => [
                    'api_key' => $mapsApiKey !== '' ? $mapsApiKey : null,
                    'configured' => $mapsApiKey !== '',
                ],
                // Public only — private VAPID key is never included.
                'firebase_vapid_public_key' => $vapidPublic !== '' ? $vapidPublic : null,
                'firebase' => $firebase,
                'settings' => $flat,
            ],
        ]);
    }

    /**
     * Build FirebaseOptions-shaped payload for Flutter Firebase.initializeApp.
     *
     * @param  array<string, mixed>  $flat
     * @return array<string, mixed>
     */
    protected function buildFirebaseClientOptions(array $flat, string $platform): array
    {
        $apiKey = match ($platform) {
            'ios' => self::nonPlaceholder($flat['firebase_ios_api_key'] ?? null)
                ?: self::nonPlaceholder($flat['firebase_api_key'] ?? null),
            'web' => self::nonPlaceholder($flat['firebase_web_api_key'] ?? null)
                ?: self::nonPlaceholder($flat['firebase_api_key'] ?? null),
            default => self::nonPlaceholder($flat['firebase_android_api_key'] ?? null)
                ?: self::nonPlaceholder($flat['firebase_api_key'] ?? null),
        };

        $appId = match ($platform) {
            'ios' => self::nonPlaceholder($flat['firebase_ios_app_id'] ?? null)
                ?: self::nonPlaceholder($flat['firebase_app_id'] ?? null),
            'web' => self::nonPlaceholder($flat['firebase_web_app_id'] ?? null)
                ?: self::nonPlaceholder($flat['firebase_app_id'] ?? null),
            default => self::nonPlaceholder($flat['firebase_android_app_id'] ?? null)
                ?: self::nonPlaceholder($flat['firebase_app_id'] ?? null),
        };

        $vapidPublic = $flat['firebase_vapid_public_key'] ?? null;

        $options = [
            'apiKey' => $apiKey ?: null,
            'appId' => $appId ?: null,
            'messagingSenderId' => $flat['firebase_messaging_sender_id'] ?: null,
            'projectId' => $flat['firebase_project_id'] ?: null,
            'storageBucket' => $flat['firebase_storage_bucket'] ?: null,
            'authDomain' => $flat['firebase_auth_domain'] ?: null,
            'measurementId' => $flat['firebase_measurement_id'] ?: null,
            'iosBundleId' => $flat['firebase_ios_bundle_id'] ?: null,
            'iosClientId' => $flat['firebase_ios_client_id'] ?: null,
            'vapidKey' => $vapidPublic ?: null,
            'platform' => $platform,
            'configured' => filled($apiKey)
                && filled($appId)
                && filled($flat['firebase_project_id'] ?? null)
                && ! self::isPlaceholderValue($apiKey)
                && ! self::isPlaceholderValue($appId),
        ];

        // Also expose platform-specific blocks for clients that want all platforms
        $options['platforms'] = [
            'android' => [
                'apiKey' => $flat['firebase_android_api_key'] ?: $flat['firebase_api_key'],
                'appId' => $flat['firebase_android_app_id'] ?: $flat['firebase_app_id'],
            ],
            'ios' => [
                'apiKey' => $flat['firebase_ios_api_key'] ?: $flat['firebase_api_key'],
                'appId' => $flat['firebase_ios_app_id'] ?: $flat['firebase_app_id'],
                'iosBundleId' => $flat['firebase_ios_bundle_id'],
                'iosClientId' => $flat['firebase_ios_client_id'],
            ],
            'web' => [
                'apiKey' => $flat['firebase_web_api_key'] ?: $flat['firebase_api_key'],
                'appId' => $flat['firebase_web_app_id'] ?: $flat['firebase_app_id'],
                'measurementId' => $flat['firebase_measurement_id'],
                'vapidKey' => $vapidPublic ?: null,
            ],
        ];

        return $options;
    }
}
