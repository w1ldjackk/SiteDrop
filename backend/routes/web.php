<?php

use App\Http\Controllers\Api\PaymentController;
use App\Http\Controllers\RoleHomeController;
use Illuminate\Support\Facades\Route;
use Inertia\Inertia;
use Laravel\Fortify\Features;

/*
|--------------------------------------------------------------------------
| Public
|--------------------------------------------------------------------------
*/

Route::get('/', function () {
    return Inertia::render('welcome', [
        'canRegister' => Features::enabled(Features::registration()),
    ]);
})->name('home');

/*
|--------------------------------------------------------------------------
| Guest auth screens
|--------------------------------------------------------------------------
*/

Route::middleware('guest')->group(function () {
    Route::get('login', function () {
        return Inertia::render('auth/login');
    })->name('login');

    Route::get('register', function () {
        return Inertia::render('auth/register');
    })->name('register');

    Route::get('login/otp', [\App\Http\Controllers\Auth\OtpLoginController::class, 'create'])
        ->name('login.otp');
    Route::post('login/otp/send', [\App\Http\Controllers\Auth\OtpLoginController::class, 'send'])
        ->middleware('throttle:5,1')
        ->name('login.otp.send');
    Route::post('login/otp/verify', [\App\Http\Controllers\Auth\OtpLoginController::class, 'verify'])
        ->middleware('throttle:10,1')
        ->name('login.otp.verify');
    Route::post('login/otp/resend', [\App\Http\Controllers\Auth\OtpLoginController::class, 'resend'])
        ->middleware('throttle:5,1')
        ->name('login.otp.resend');
});

Route::get('reset-password/phone/{token}', [\App\Http\Controllers\Backend\Auth\PhonePasswordResetController::class, 'show'])
    ->name('password.reset.phone');
Route::post('reset-password/phone', [\App\Http\Controllers\Backend\Auth\PhonePasswordResetController::class, 'store'])
    ->name('password.reset.phone.store');

Route::post('/payments/hubtel-callback', [PaymentController::class, 'hubtelCallback']);
Route::post('/payments/paystack-callback', [PaymentController::class, 'paystackCallback']);

/*
|--------------------------------------------------------------------------
| Shared authenticated redirects (any role)
|--------------------------------------------------------------------------
| Role areas: admin.php, buyer.php, seller.php, driver.php
| Settings live under each area: /{role}/settings/*
*/

Route::middleware(['auth', 'verified'])->group(function () {
    Route::get('dashboard', [RoleHomeController::class, 'legacyDashboard'])
        ->name('dashboard');
    Route::get('dashboard/buyer', fn () => redirect()->route('buyer.dashboard'))
        ->name('dashboard.buyer');
    Route::get('dashboard/seller', fn () => redirect()->route('seller.dashboard'))
        ->name('dashboard.seller');
    Route::get('dashboard/seller-listing', fn () => redirect()->route('seller.listing'))
        ->name('dashboard.seller-listing');
    Route::get('admin/dashboard', fn () => redirect()->route('admin.dashboard'));

    // Legacy /settings/* → current user's role settings
    Route::get('/settings/{path?}', function (?string $path = null) {
        $user = auth()->user();
        $page = $path && $path !== '' ? trim($path, '/') : 'profile';

        return redirect()->to($user->settingsPath($page));
    })->where('path', '.*')->name('settings.legacy');
});
