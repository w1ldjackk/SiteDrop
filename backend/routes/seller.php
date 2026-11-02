<?php

/**
 * Seller area — /seller/*
 * Auth + seller role required. Wrong role → 403.
 *
 * Related (scoped) modules mirrored from admin.php:
 * products (own), orders (as seller), payments, deliveries, reviews,
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

Route::middleware(['auth', 'verified', 'role.area:seller'])
    ->prefix('seller')
    ->name('seller.')
    ->group(function () {
        Route::get('/', [RoleDashboardController::class, 'seller'])->name('dashboard');
        Route::get('/listing', function () {
            return Inertia::render('dashboard/seller-listing');
        })->name('listing');

        register_role_settings_routes('seller');

        // Products (own catalogue)
        Route::prefix('products')->name('products.')->controller(ProductController::class)->group(function () {
            Route::get('/', 'index')->name('index');
            Route::get('/{id}', 'show')->name('show')->whereNumber('id');
        });

        // Orders (as seller)
        Route::prefix('orders')->name('orders.')->controller(OrderController::class)->group(function () {
            Route::get('/', 'index')->name('index');
            Route::get('/statistics', 'statistics')->name('statistics');
            Route::get('/{id}', 'show')->name('show')->whereNumber('id');
        });

        // Payments (for seller orders)
        Route::prefix('payments')->name('payments.')->controller(PaymentController::class)->group(function () {
            Route::get('/', 'index')->name('index');
            Route::get('/{id}', 'show')->name('show')->whereNumber('id');
        });

        // Wallet / earnings cash-out
        Route::prefix('wallet')->name('wallet.')->controller(WalletController::class)->group(function () {
            Route::get('/', 'myWallet')->name('index');
            Route::post('/deposit', 'requestDeposit')->name('deposit');
            Route::post('/withdraw', 'requestWithdrawal')->name('withdraw');
        });

        // Deliveries (seller orders)
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
