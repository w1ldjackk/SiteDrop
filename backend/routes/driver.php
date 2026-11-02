<?php

/**
 * Driver area — /driver/*
 * Auth + driver role required. Wrong role → 403.
 *
 * Related (scoped) modules mirrored from admin.php:
 * deliveries (assigned), orders (linked), notifications, support + settings.
 */

use App\Http\Controllers\Backend\DeliveryController;
use App\Http\Controllers\Backend\NotificationController;
use App\Http\Controllers\Backend\OrderController;
use App\Http\Controllers\Backend\WalletController;
use App\Http\Controllers\RoleDashboardController;
use Illuminate\Support\Facades\Route;
use Inertia\Inertia;

require __DIR__.'/settings.php';

Route::middleware(['auth', 'verified', 'role.area:driver'])
    ->prefix('driver')
    ->name('driver.')
    ->group(function () {
        Route::get('/', [RoleDashboardController::class, 'driver'])->name('dashboard');

        register_role_settings_routes('driver');

        // Deliveries (assigned to this driver)
        Route::prefix('deliveries')->name('deliveries.')->controller(DeliveryController::class)->group(function () {
            Route::get('/', 'index')->name('index');
            Route::get('/{id}', 'show')->name('show')->whereNumber('id');
        });

        // Orders linked to assigned deliveries
        Route::prefix('orders')->name('orders.')->controller(OrderController::class)->group(function () {
            Route::get('/', 'index')->name('index');
            Route::get('/{id}', 'show')->name('show')->whereNumber('id');
        });

        // Wallet
        Route::prefix('wallet')->name('wallet.')->controller(WalletController::class)->group(function () {
            Route::get('/', 'myWallet')->name('index');
            Route::post('/deposit', 'requestDeposit')->name('deposit');
            Route::post('/withdraw', 'requestWithdrawal')->name('withdraw');
        });

        // Notifications
        Route::prefix('notifications')
            ->name('notifications.')
            ->controller(NotificationController::class)
            ->group(function () {
                Route::get('/', 'index')->name('index');
                Route::get('/recent', 'recent')->name('recent');
                Route::post('/{notification}/read', 'markAsRead')->name('mark-as-read');
                Route::post('/mark-all-read', 'markAllAsRead')->name('mark-all-read');
                Route::delete('/{notification}', 'destroy')->name('destroy');
                Route::post('/preferences', 'updatePreferences')->name('preferences');
            });

        Route::get('support', fn () => Inertia::render('backend/Support'))->name('support');
    });
