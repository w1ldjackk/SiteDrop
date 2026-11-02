<?php

/**
 * Admin area — /admin/*
 * Auth + admin/super-admin required. Wrong role → 403.
 */

use App\Http\Controllers\Backend\ActivityLogController;
use App\Http\Controllers\Backend\AnalyticsController;
use App\Http\Controllers\Backend\DashController;
use App\Http\Controllers\Backend\DeliveryController;
use App\Http\Controllers\Backend\OrderController;
use App\Http\Controllers\Backend\PaymentController;
use App\Http\Controllers\Backend\PermissionController;
use App\Http\Controllers\Backend\ProductController;
use App\Http\Controllers\Backend\ReportController;
use App\Http\Controllers\Backend\ReviewController;
use App\Http\Controllers\Backend\RoleController;
use App\Http\Controllers\Backend\SellerController;
use App\Http\Controllers\Backend\SystemSettingController;
use App\Http\Controllers\Backend\TruckController;
use App\Http\Controllers\Backend\UserController;
use App\Http\Controllers\Backend\WalletController;
use Illuminate\Support\Facades\Route;
use Inertia\Inertia;

require __DIR__.'/settings.php';

// ==============================
// Admin-only management routes
// (ops-manager uses this area too — see User::isAdmin / AdminMiddleware)
// ==============================
Route::middleware(['auth', 'verified', 'admin'])
    ->prefix('admin')
    ->group(function () {

        // Dashboard
        Route::get('/', [DashController::class, 'index'])->name('admin.dashboard');

        // Account settings — /admin/settings/*
        Route::name('admin.')->group(function () {
            register_role_settings_routes('admin');
        });
        Route::get('/stats', [DashController::class, 'stats']);
        Route::get('/charts', [DashController::class, 'charts']);
        Route::get('/activity', [DashController::class, 'recentActivity']);
        Route::get('/quick-stats', [DashController::class, 'quickStats']);

        // Operations
        Route::prefix('sellers')->name('admin.sellers.')->controller(SellerController::class)->group(function () {
            Route::get('/', 'index')->name('index');
            Route::get('/create', 'create')->name('create');
            Route::post('/', 'store')->name('store');
            Route::get('/{id}', 'show')->name('show')->whereNumber('id');
            Route::get('/{id}/edit', 'edit')->name('edit')->whereNumber('id');
            Route::put('/{id}', 'update')->name('update')->whereNumber('id');
            Route::delete('/{id}', 'destroy')->name('destroy')->whereNumber('id');
            Route::post('/{id}/approve', 'approve')->name('approve')->whereNumber('id');
            Route::post('/{id}/reject', 'reject')->name('reject')->whereNumber('id');
            Route::post('/{id}/suspend', 'suspend')->name('suspend')->whereNumber('id');
            Route::post('/{id}/activate', 'activate')->name('activate')->whereNumber('id');
            Route::get('/{id}/performance', 'performance')->name('performance')->whereNumber('id');
        });

        Route::prefix('orders')->name('admin.orders.')->controller(OrderController::class)->group(function () {
            Route::get('/', 'index')->name('index');
            Route::get('/statistics', 'statistics')->name('statistics');
            Route::get('/create', 'create')->name('create');
            Route::post('/', 'store')->name('store');
            Route::post('/bulk', 'bulkUpdate')->name('bulk');
            Route::post('/bulk-delete', 'bulkDelete')->name('bulk-delete');
            Route::get('/{id}', 'show')->name('show')->whereNumber('id');
            Route::get('/{id}/edit', 'edit')->name('edit')->whereNumber('id');
            Route::put('/{id}', 'update')->name('update')->whereNumber('id');
            Route::delete('/{id}', 'destroy')->name('destroy')->whereNumber('id');
        });

        Route::prefix('deliveries')->name('admin.deliveries.')->controller(DeliveryController::class)->group(function () {
            Route::get('/', 'index')->name('index');
            Route::get('/{id}', 'show')->name('show')->whereNumber('id');
            Route::post('/{id}/assign', 'assign')->name('assign')->whereNumber('id');
            Route::post('/{id}/dispatch', 'dispatch')->name('dispatch')->whereNumber('id');
        });

        Route::prefix('products')->name('admin.products.')->controller(ProductController::class)->group(function () {
            Route::get('/', 'index')->name('index');
            Route::get('/{id}', 'show')->name('show')->whereNumber('id');
        });

        Route::prefix('trucks')->name('admin.trucks.')->controller(TruckController::class)->group(function () {
            Route::get('/', 'index')->name('index');
            Route::get('/{id}', 'show')->name('show')->whereNumber('id');
            Route::post('/{id}/approve', 'approve')->name('approve')->whereNumber('id');
            Route::post('/{id}/reject', 'reject')->name('reject')->whereNumber('id');
        });

        // Finance & insights
        Route::prefix('payments')->name('admin.payments.')->controller(PaymentController::class)->group(function () {
            Route::get('/', 'index')->name('index');
            Route::get('/{id}', 'show')->name('show')->whereNumber('id');
        });

        // Wallets (admin manage + own wallet)
        Route::prefix('wallets')->name('admin.wallets.')->controller(WalletController::class)->group(function () {
            Route::get('/', 'adminIndex')->name('index');
            Route::get('/mine', 'myWallet')->name('mine');
            Route::post('/mine/deposit', 'requestDeposit')->name('mine.deposit');
            Route::post('/mine/withdraw', 'requestWithdrawal')->name('mine.withdraw');
            Route::get('/{id}', 'adminShow')->name('show')->whereNumber('id');
            Route::post('/transactions/{id}/approve', 'adminApprove')->name('approve')->whereNumber('id');
            Route::post('/transactions/{id}/reject', 'adminReject')->name('reject')->whereNumber('id');
            Route::post('/{id}/adjust', 'adminAdjust')->name('adjust')->whereNumber('id');
            Route::post('/{id}/credit', 'adminCredit')->name('credit')->whereNumber('id');
            Route::post('/{id}/toggle', 'adminToggle')->name('toggle')->whereNumber('id');
        });

        Route::get('reports', [ReportController::class, 'index'])->name('admin.reports.index');
        Route::get('analytics', [AnalyticsController::class, 'index'])->name('admin.analytics.index');

        Route::prefix('reviews')->name('admin.reviews.')->controller(ReviewController::class)->group(function () {
            Route::get('/', 'index')->name('index');
            Route::post('/bulk-delete', 'bulkDelete')->name('bulk-delete');
            Route::put('/{id}', 'update')->name('update')->whereNumber('id');
            Route::delete('/{id}', 'destroy')->name('destroy')->whereNumber('id');
        });

        // Platform-wide system settings
        Route::get('system-settings', [SystemSettingController::class, 'index'])
            ->name('admin.system-settings.index');
        Route::put('system-settings', [SystemSettingController::class, 'update'])
            ->name('admin.system-settings.update');

        // System
        Route::resource('roles', RoleController::class);
        Route::post('roles/bulk-delete', [RoleController::class, 'bulkDelete'])->name('admin.roles.bulk-delete');

        Route::resource('permissions', PermissionController::class);
        Route::post('permissions/bulk-delete', [PermissionController::class, 'bulkDelete'])->name('admin.permissions.bulk-delete');

        Route::prefix('users')->controller(UserController::class)->group(function () {
            Route::get('/', 'index');
            Route::post('/', 'store');
            Route::get('/create', 'create');
            Route::get('/{id}', 'show')->whereNumber('id');
            Route::get('/{id}/edit', 'edit')->whereNumber('id');
            Route::put('/{id}', 'update')->whereNumber('id');
            Route::delete('/{id}', 'destroy')->whereNumber('id');
            Route::post('/bulk', 'bulkAction');
        });

        Route::get('support', fn () => Inertia::render('backend/Support'))->name('admin.support');
        Route::get('api-docs', fn () => Inertia::render('backend/ApiDocs'))->name('admin.api-docs');

        Route::prefix('notifications')
            ->name('admin.notifications.')
            ->controller(\App\Http\Controllers\Backend\NotificationController::class)
            ->group(function () {
                Route::get('/', 'index')->name('index');
                Route::get('/recent', 'recent')->name('recent');
                Route::post('/{notification}/read', 'markAsRead')->name('mark-as-read');
                Route::post('/mark-all-read', 'markAllAsRead')->name('mark-all-read');
                Route::delete('/{notification}', 'destroy')->name('destroy');
                Route::post('/send-message', 'sendMessage')->name('send-message');
                Route::post('/preferences', 'updatePreferences')->name('preferences');
            });

        // Activity logs (admin area)
        Route::prefix('activity-logs')
            ->name('admin.activity-logs.')
            ->controller(ActivityLogController::class)
            ->group(function () {
                Route::get('/', 'index')->name('index');
                Route::post('/bulk-delete', 'bulkDelete')->name('bulk-delete');
                Route::get('/{activityLog}', 'show')->name('show');
                Route::delete('/{activityLog}', 'destroy')->name('destroy');
            });
    });
