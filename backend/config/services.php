<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Third Party Services
    |--------------------------------------------------------------------------
    |
    | This file is for storing the credentials for third party services such
    | as Mailgun, Postmark, AWS and more. This file provides the de facto
    | location for this type of information, allowing packages to have
    | a conventional file to locate the various service credentials.
    |
    */

    'postmark' => [
        'key' => env('POSTMARK_API_KEY'),
    ],

    'resend' => [
        'key' => env('RESEND_API_KEY'),
    ],

    'ses' => [
        'key' => env('AWS_ACCESS_KEY_ID'),
        'secret' => env('AWS_SECRET_ACCESS_KEY'),
        'region' => env('AWS_DEFAULT_REGION', 'us-east-1'),
    ],

    'slack' => [
        'notifications' => [
            'bot_user_oauth_token' => env('SLACK_BOT_USER_OAUTH_TOKEN'),
            'channel' => env('SLACK_BOT_USER_DEFAULT_CHANNEL'),
        ],
    ],


    'hubtel' => [
        'api_key' => env('HUBTEL_API_KEY'),
        'secret_key' => env('HUBTEL_SECRET_KEY'),
        'base_url' => 'https://api.hubtel.com/v1',
    ],

    /*
    |--------------------------------------------------------------------------
    | SMS (outbound transactional SMS — OTP, order updates)
    |--------------------------------------------------------------------------
    | provider: log (dev default) | hubtel | arkesel
    | Hubtel SMS uses its own client_id/client_secret (smsc.hubtel.com),
    | separate from the Hubtel payments api_key above.
    */
    'sms' => [
        'provider' => env('SMS_PROVIDER', 'log'),
        'sender_id' => env('SMS_SENDER_ID', 'SiteDrop'),
        'hubtel_client_id' => env('HUBTEL_SMS_CLIENT_ID'),
        'hubtel_client_secret' => env('HUBTEL_SMS_CLIENT_SECRET'),
        'arkesel_api_key' => env('ARKESEL_API_KEY'),
    ],

    'paystack' => [
        'public_key' => env('PAYSTACK_PUBLIC_KEY'),
        'secret_key' => env('PAYSTACK_SECRET_KEY'),
        'base_url' => 'https://api.paystack.co',
    ],

    /*
    |--------------------------------------------------------------------------
    | IP Geolocation (ipgeolocation.io)
    |--------------------------------------------------------------------------
    */
    'ip_geolocation' => [
        'api_key' => env('IP_GEOLOCATION_API_KEY'),
        'base_url' => env('IP_GEOLOCATION_BASE_URL', 'https://api.ipgeolocation.io'),
        'cache_ttl' => (int) env('IP_GEOLOCATION_CACHE_TTL', 3600),
    ],

    /*
    |--------------------------------------------------------------------------
    | Firebase / FCM
    |--------------------------------------------------------------------------
    | Client keys (api_key, app_id, …) may be exposed to the mobile app via
    | SystemSettingController::publicConfig. Server keys stay private.
    */
    'firebase' => [
        'api_key' => env('FIREBASE_API_KEY'),
        'app_id' => env('FIREBASE_APP_ID'),
        'messaging_sender_id' => env('FIREBASE_MESSAGING_SENDER_ID'),
        'project_id' => env('FIREBASE_PROJECT_ID', 'sitedrop-eb666'),
        'storage_bucket' => env('FIREBASE_STORAGE_BUCKET', 'sitedrop-eb666.appspot.com'),
        'auth_domain' => env('FIREBASE_AUTH_DOMAIN', 'sitedrop-eb666.firebaseapp.com'),
        'measurement_id' => env('FIREBASE_MEASUREMENT_ID'),

        'android' => [
            'api_key' => env('FIREBASE_ANDROID_API_KEY', env('FIREBASE_API_KEY')),
            'app_id' => env('FIREBASE_ANDROID_APP_ID', env('FIREBASE_APP_ID')),
        ],

        'ios' => [
            'api_key' => env('FIREBASE_IOS_API_KEY', env('FIREBASE_API_KEY')),
            'app_id' => env('FIREBASE_IOS_APP_ID', env('FIREBASE_APP_ID')),
            'bundle_id' => env('FIREBASE_IOS_BUNDLE_ID', 'com.sitedrop.app'),
            'client_id' => env('FIREBASE_IOS_CLIENT_ID'),
        ],

        'web' => [
            'api_key' => env('FIREBASE_WEB_API_KEY', env('FIREBASE_API_KEY')),
            'app_id' => env('FIREBASE_WEB_APP_ID', env('FIREBASE_APP_ID')),
            'measurement_id' => env('FIREBASE_MEASUREMENT_ID'),
            // Public only — safe to expose via publicConfig for Flutter web getToken.
            'vapid_public_key' => env('FIREBASE_VAPID_PUBLIC_KEY'),
        ],
    ],

    /*
    |--------------------------------------------------------------------------
    | FCM (server-side push — never send to clients)
    |--------------------------------------------------------------------------
    */
    'fcm' => [
        // HTTP v1 (recommended): path to Firebase service account JSON
        // e.g. storage/app/firebase/service-account.json
        'credentials' => env('FIREBASE_CREDENTIALS', env('GOOGLE_APPLICATION_CREDENTIALS')),
        'project_id' => env('FIREBASE_PROJECT_ID', env('FCM_PROJECT_ID', 'sitedrop-eb666')),
        // Legacy (deprecated) server key — used only if credentials are missing
        'server_key' => env('FCM_SERVER_KEY', env('FIREBASE_SERVER_KEY')),
        'sender_id' => env('FIREBASE_MESSAGING_SENDER_ID'),
        // Web Push VAPID private key — server only; never expose via API.
        'vapid_private_key' => env('FIREBASE_VAPID_PRIVATE_KEY'),
        'vapid_public_key' => env('FIREBASE_VAPID_PUBLIC_KEY'),
    ],

    /*
    |--------------------------------------------------------------------------
    | Google Maps (client key — exposed via publicConfig for mobile maps)
    |--------------------------------------------------------------------------
    | Restrict this key in Google Cloud Console (Android package / iOS bundle /
    | HTTP referrers / API restrictions). Prefer Maps SDK + Distance Matrix only.
    */
    'google_maps' => [
        'api_key' => env('GOOGLE_MAPS_API_KEY', ''),
    ],


    /*
    |--------------------------------------------------------------------------
    | Moolre Payment Gateway / Open Banking / Collect
    |--------------------------------------------------------------------------
    */
    // Moolre Open Banking / Collect
    'moolre' => [
        'mode' => env('MOOLRE_MODE', 'sandbox'),
        'username' => env('MOOLRE_USERNAME'),
        'api_key' => env('MOOLRE_API_KEY'),
        'public_key' => env('MOOLRE_PUBLIC_KEY'),
        'account_number' => env('MOOLRE_ACCOUNT_NUMBER'),
        'fee' => (float) env('MOOLRE_TNX_FEE', 0.02),
        'payout_fee' => (float) env('MOOLRE_PRO_FEE', 0.01),
        'currency' => env('MOOLRE_DEFAULT_CURRENCY', 'GHS'),
        'base_url' => env('MOOLRE_BASE_URL', 'https://sandbox.moolre.com/open'),
        'url' => env('MOOLRE_API_URL', env('MOOLRE_BASE_URL', 'https://sandbox.moolre.com/open')),
        'callback_url' => env('MOOLRE_CALLBACK_URL'),
        'channels' => [
            'MTN' => (int) env('MOOLRE_CHANNEL_MTN', 13),
            'TELECEL' => (int) env('MOOLRE_CHANNEL_TELECEL', 6),
            'AIRTELTIGO' => (int) env('MOOLRE_CHANNEL_AIRTELTIGO', 7),
        ],
    ],

    // Moolre SMS Configuration
    'moolre_sms' => [
        'mode' => env('MOOLRE_MODE', 'sandbox'),
        'key' => env('MOOLRE_VASKEY', ''),
        'sender_id' => env('MOOLRE_SENDER_ID', 'QuickVoucha'),
        'timeout' => (float) env('MOOLRE_TIMEOUT', 15),
        'connect_timeout' => (float) env('MOOLRE_CONNECT_TIMEOUT', 5),
    ],

];
