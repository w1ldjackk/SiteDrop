<?php
// app/Http/Controllers/Api/SettingController.php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Setting;
use App\Services\Activity\ActivityActions;
use App\Services\Activity\ActivityLogger;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class SettingController extends Controller
{
    /**
     * List all settings for the authenticated user.
     * GET /api/v1/settings
     */
    public function index(Request $request): JsonResponse
    {
        $user = $request->user();
        $settings = Setting::allForUser($user->id);

        // Defaults for known keys
        $settings = array_merge([
            Setting::KEY_THEME_MODE => 'system',
        ], $settings);

        return response()->json([
            'status' => 'success',
            'data' => [
                'settings' => $settings,
            ],
        ]);
    }

    /**
     * Get one setting by key.
     * GET /api/v1/settings/{key}
     */
    public function show(Request $request, string $key): JsonResponse
    {
        $user = $request->user();
        $default = $key === Setting::KEY_THEME_MODE ? 'system' : null;
        $value = Setting::getForUser($user->id, $key, $default);

        return response()->json([
            'status' => 'success',
            'data' => [
                'name' => $key,
                'val' => $value,
            ],
        ]);
    }

    /**
     * Update one or more settings.
     * PUT /api/v1/settings
     *
     * Body examples:
     *  { "theme_mode": "dark" }
     *  { "settings": { "theme_mode": "light" } }
     */
    public function update(Request $request): JsonResponse
    {
        $user = $request->user();

        $payload = $request->input('settings');
        if (!is_array($payload)) {
            // Accept flat body of key => value
            $payload = $request->except(['_token']);
        }

        $request->validate([
            'theme_mode' => ['sometimes', Rule::in(['system', 'light', 'dark'])],
            'settings' => 'sometimes|array',
            'settings.theme_mode' => ['sometimes', Rule::in(['system', 'light', 'dark'])],
        ]);

        if (isset($payload['theme_mode'])) {
            Setting::setForUser(
                $user->id,
                Setting::KEY_THEME_MODE,
                $payload['theme_mode'],
                'string'
            );
        }

        // Allow other simple string/bool settings in the future
        foreach ($payload as $name => $value) {
            if ($name === 'theme_mode' || $name === 'settings') {
                continue;
            }
            if (!is_string($name) || is_array($value)) {
                continue;
            }
            $type = is_bool($value) ? 'boolean' : 'string';
            Setting::setForUser($user->id, $name, $value, $type);
        }

        return response()->json([
            'status' => 'success',
            'message' => 'Settings updated successfully',
            'data' => [
                'settings' => Setting::allForUser($user->id),
            ],
        ]);
    }

    /**
     * Update a single setting by key.
     * PUT /api/v1/settings/{key}
     *
     * Body: { "val": "dark" } or { "value": "dark" }
     */
    public function updateKey(Request $request, string $key): JsonResponse
    {
        $user = $request->user();
        $value = $request->input('val', $request->input('value'));

        if ($key === Setting::KEY_THEME_MODE) {
            $request->validate([
                'val' => ['nullable', Rule::in(['system', 'light', 'dark'])],
                'value' => ['nullable', Rule::in(['system', 'light', 'dark'])],
            ]);
            if ($value === null) {
                return response()->json([
                    'status' => 'error',
                    'message' => 'val is required',
                ], 422);
            }
        }

        if ($value === null) {
            return response()->json([
                'status' => 'error',
                'message' => 'val is required',
            ], 422);
        }

        $type = is_bool($value) ? 'boolean' : 'string';
        Setting::setForUser($user->id, $key, $value, $type);

        return response()->json([
            'status' => 'success',
            'message' => 'Setting updated',
            'data' => [
                'name' => $key,
                'val' => Setting::getForUser($user->id, $key),
            ],
        ]);
    }

    /**
     * Appearance shortcut — theme only.
     * GET /api/v1/settings/appearance
     */
    public function getAppearance(Request $request): JsonResponse
    {
        $user = $request->user();
        $themeMode = Setting::getForUser($user->id, Setting::KEY_THEME_MODE, 'system');

        return response()->json([
            'status' => 'success',
            'data' => [
                'theme_mode' => $themeMode,
            ],
        ]);
    }

    /**
     * Appearance shortcut — update theme.
     * PUT /api/v1/settings/appearance
     * Body: { "theme_mode": "dark" }
     */
    public function updateAppearance(Request $request): JsonResponse
    {
        $request->validate([
            'theme_mode' => ['required', Rule::in(['system', 'light', 'dark'])],
        ]);

        $user = $request->user();
        Setting::setForUser(
            $user->id,
            Setting::KEY_THEME_MODE,
            $request->input('theme_mode'),
            'string'
        );

        ActivityLogger::log(
            ActivityActions::SETTINGS_APPEARANCE,
            "Appearance set to {$request->input('theme_mode')}",
            $user,
            ['theme_mode' => $request->input('theme_mode')],
            module: 'settings',
            userId: $user->id,
        );

        return response()->json([
            'status' => 'success',
            'message' => 'Appearance updated',
            'data' => [
                'theme_mode' => $request->input('theme_mode'),
            ],
        ]);
    }
}
