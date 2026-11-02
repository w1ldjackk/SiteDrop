<?php

/**
 * Buyer area — /buyer/*
 * Auth + buyer role required. Wrong role → 403.
 *
 * Related (scoped) modules mirrored from admin.php:
 * orders, products (catalog), payments, deliveries, reviews,
 * notifications, support + account settings.
 */

use App\Http\Controllers\Backend\DeliveryController;
use App\Http\Controllers\Backend\NotificationController;
use App\Http\Controllers\Backend\OrderController;
use App\Http\Controllers\Backend\PaymentController;
use App\Http\Controllers\Backend\ProductController;
use App\Http\Controllers\Backend\ReviewController;
use App\Http\Controllers\Backend\WalletController;
use App\Http\Controllers\RoleDashboardController;
use Illuminate\Support\Facades\Route;
use Inertia\Inertia;

require __DIR__.'/settings.php';

Route::middleware(['auth', 'verified', 'role.area:buyer'])
    ->prefix('buyer')
    ->name('buyer.')
    ->group(function () {
        Route::get('/', [RoleDashboardController::class, 'buyer'])->name('dashboard');

        register_role_settings_routes('buyer');

        // Orders (own purchases)
        Route::prefix('orders')->name('orders.')->controller(OrderController::class)->group(function () {
            Route::get('/', 'index')->name('index');
            Route::get('/{id}', 'show')->name('show')->whereNumber('id');
        });

        // Products (available catalog)
        Route::prefix('products')->name('products.')->controller(ProductController::class)->group(function () {
            Route::get('/', 'index')->name('index');
            Route::get('/{id}', 'show')->name('show')->whereNumber('id');
        });

        // Payments (own)
        Route::prefix('payments')->name('payments.')->controller(PaymentController::class)->group(function () {
            Route::get('/', 'index')->name('index');
            Route::get('/{id}', 'show')->name('show')->whereNumber('id');
        });

        // Wallet
        Route::prefix('wallet')->name('wallet.')->controller(WalletController::class)->group(function () {
            Route::get('/', 'myWallet')->name('index');
            Route::post('/deposit', 'requestDeposit')->name('deposit');
            Route::post('/withdraw', 'requestWithdrawal')->name('withdraw');
        });

        // Deliveries (own orders)
        Route::prefix('deliveries')->name('deliveries.')->controller(DeliveryController::class)->group(function () {
            Route::get('/', 'index')->name('index');
            Route::get('/{id}', 'show')->name('show')->whereNumber('id');
        });

        // Reviews
        Route::prefix('reviews')->name('reviews.')->controller(ReviewController::class)->group(function () {
            Route::get('/', 'index')->name('index');
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
