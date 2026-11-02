<?php

/**
 * Shared settings route definitions for role areas.
 *
 * Call inside a group that already has the correct path prefix AND name prefix:
 *   - buyer group: prefix('buyer')->name('buyer.')  → buyer.profile.edit
 *   - admin group: name('admin.') around this call   → admin.profile.edit
 *
 * Paths: /{area}/settings/profile|password|appearance|two-factor
 */

use App\Http\Controllers\Backend\Settings\PasswordController;
use App\Http\Controllers\Backend\Settings\ProfileController;
use App\Http\Controllers\Backend\Settings\TwoFactorAuthenticationController;
use Illuminate\Support\Facades\Route;
use Inertia\Inertia;

if (! function_exists('register_role_settings_routes')) {
    /**
     * @param  string  $area  Path segment: admin|buyer|seller|driver
     */
    function register_role_settings_routes(string $area): void
    {
        $base = '/'.trim($area, '/').'/settings';

        Route::redirect('settings', $base.'/profile');

        Route::get('settings/profile', [ProfileController::class, 'edit'])
            ->name('profile.edit');
        Route::patch('settings/profile', [ProfileController::class, 'update'])
            ->name('profile.update');
        Route::delete('settings/profile', [ProfileController::class, 'destroy'])
            ->name('profile.destroy');

        Route::get('settings/password', [PasswordController::class, 'edit'])
            ->name('password.edit');
        Route::put('settings/password', [PasswordController::class, 'update'])
            ->middleware('throttle:6,1')
            ->name('password.update');

        Route::get('settings/appearance', function () {
            return Inertia::render('settings/appearance');
        })->name('appearance.edit');

        Route::get('settings/two-factor', [TwoFactorAuthenticationController::class, 'show'])
            ->name('two-factor.show');
    }
}
