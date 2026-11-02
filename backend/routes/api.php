<?php

use App\Http\Controllers\Api\Auth\LoginController;
use App\Http\Controllers\Api\Auth\OtpController;
use App\Http\Controllers\Api\Auth\PasswordController;
use App\Http\Controllers\Api\Auth\RegisterController;
use App\Http\Controllers\Api\CartController;
use App\Http\Controllers\Api\CheckoutController;
use App\Http\Controllers\Api\DeliveryController;
use App\Http\Controllers\Api\FollowController;
use App\Http\Controllers\Api\OrderController;
use App\Http\Controllers\Api\PaymentController;
use App\Http\Controllers\Api\PaymentInstrumentController;
use App\Http\Controllers\Api\ProductController;
use App\Http\Controllers\Api\ReviewController;
use App\Http\Controllers\Api\ProfileController;
use App\Http\Controllers\Api\SecurityController;
use App\Http\Controllers\Api\SellerOnboardingController;
use App\Http\Controllers\Api\SettingController;
use App\Http\Controllers\Api\SiteController;
use App\Http\Controllers\Api\TripLogController;
use App\Http\Controllers\Api\TruckController;
use App\Http\Controllers\Api\WishlistController;
use App\Http\Controllers\Api\ActivityLogController;
use App\Http\Controllers\Api\AddressController;
use App\Http\Controllers\Api\DeviceTokenController;
use App\Http\Controllers\Api\FileController;
use App\Http\Controllers\Api\NotificationController as ApiNotificationController;
use App\Http\Controllers\Api\WalletController as ApiWalletController;
use App\Http\Controllers\Backend\SystemSettingController;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use Laravel\Sanctum\Http\Middleware\EnsureFrontendRequestsAreStateful;



// ====================== CSRF ======================
Route::get('/sanctum/csrf-cookie', function () {
    return response()->noContent();
})->middleware(EnsureFrontendRequestsAreStateful::class);

// ====================== API Version 1 ======================
Route::prefix('v1')->group(function () {

    // Health Check
    Route::get('/health', function () {
        return response()->json([
            'status' => 'ok',
            'version' => '1.0',
            'timestamp' => now()->toIso8601String(),
            'environment' => app()->environment(),
        ]);
    });

    // Public app bootstrap (Firebase client config, maintenance, support, …)
    // Query: ?platform=android|ios|web
    Route::get('/config', [SystemSettingController::class, 'publicConfig']);
    Route::get('/system-settings/public', [SystemSettingController::class, 'publicConfig']);

    // ====================== Auth Routes ======================
    Route::prefix('auth')->middleware('throttle:auth')->group(function () {
        // OTP Routes
        Route::prefix('otp')->controller(OtpController::class)->group(function () {
            Route::post('/send', 'sendOtp');
            Route::post('/verify', 'verifyOtp');
        });

        // Login & Register
        Route::post('/login', [LoginController::class, 'login']);
        Route::post('/login-otp', [LoginController::class, 'loginOtp']);
        Route::post('/register', [RegisterController::class, 'register']);

        // Forgot Password & Reset Password
        Route::post('/forgot-password', [PasswordController::class, 'forgotPassword']);
        Route::post('/reset-password', [PasswordController::class, 'resetPassword']);

        // Logout
        Route::post('/logout', [LoginController::class, 'logout'])->middleware('auth:sanctum');
    });

    // ====================== Public Marketplace (guests can browse) ======================
    Route::prefix('products')->controller(ProductController::class)->group(function () {
        Route::get('/listings', 'listings');
        Route::get('/categories', 'categories');
        Route::get('/{id}/reviews', 'reviews')->whereNumber('id');
        Route::get('/{id}', 'show')->whereNumber('id');
    });

    // Public site directory (view-only)
    Route::prefix('sites')->controller(SiteController::class)->group(function () {
        Route::get('/', 'index');
        Route::get('/nearby', 'nearby');
        Route::get('/{id}', 'show')->whereNumber('id');
        Route::get('/{id}/materials', 'materials')->whereNumber('id');
        Route::get('/{id}/products', 'products')->whereNumber('id');
    });

    // Public file serving WITH CORS headers (no auth — guests browse listings).
    // Flutter web (CanvasKit) blocks cross-origin images without
    // Access-Control-Allow-Origin, which `php artisan serve` never sends for
    // static files. Files still live in public/assets/...; this only streams
    // them through the API middleware stack.
    Route::get('/files/{path}', [FileController::class, 'show'])->where('path', '.*');

    // ====================== Authenticated Routes ======================
    Route::middleware('auth:sanctum')->group(function () {

        // Get Authenticated User Info
        Route::get('/user', function (Request $request) {
            $user = $request->user();
            $user->load(['profile', 'sellerProfile', 'wallet']);

            return response()->json([
                'status' => 'success',
                'data' => [
                    'user' => $user->only([
                        'id',
                        'name',
                        'email',
                        'phone',
                        'role',
                        'phone_verified',
                        'created_at',
                    ]),
                    'profile' => $user->profile,
                    'seller_profile' => $user->sellerProfile,
                    'wallet' => $user->wallet,
                ],
            ]);
        });

        // ====================== Profile Management ======================
        Route::prefix('profile')->controller(ProfileController::class)->group(function () {
            Route::get('/', 'show');
            Route::get('/stats', 'stats');
            Route::put('/', 'update');
            Route::post('/avatar', 'uploadAvatar');
            Route::delete('/avatar', 'deleteAvatar');
            Route::post('/verify-identity', 'verifyIdentity');
            Route::get('/preferences', 'getPreferences');
            Route::put('/preferences', 'updatePreferences');
        });

        // ====================== Account Security ======================
        Route::prefix('profile')->controller(SecurityController::class)->group(function () {
            Route::post('/password', 'changePassword');
            Route::get('/2fa/status', 'twoFactorStatus');
            Route::post('/2fa/enable', 'enableTwoFactor');
            Route::post('/2fa/confirm', 'confirmTwoFactor');
            Route::delete('/2fa', 'disableTwoFactor');
        });

        // ====================== Seller follows ======================
        Route::prefix('sellers')->controller(FollowController::class)->group(function () {
            Route::get('/following', 'following');
            Route::get('/{id}/follow-status', 'status')->whereNumber('id');
            Route::post('/{id}/follow', 'toggle')->whereNumber('id');
        });

        // ====================== Wishlist ======================
        Route::prefix('wishlist')->controller(WishlistController::class)->group(function () {
            Route::get('/', 'index');
            Route::post('/add', 'add');
            Route::post('/remove', 'remove');
            Route::delete('/remove', 'remove');
            Route::post('/toggle', 'toggle');
            Route::get('/check', 'check');
        });

        // ====================== Addresses (delivery book) ======================
        Route::prefix('addresses')->controller(AddressController::class)->group(function () {
            Route::get('/', 'index');
            Route::post('/', 'store');
            Route::get('/{id}', 'show')->whereNumber('id');
            Route::put('/{id}', 'update')->whereNumber('id');
            Route::delete('/{id}', 'destroy')->whereNumber('id');
            Route::post('/{id}/default', 'setDefault')->whereNumber('id');
        });

        // ====================== User Settings (appearance, etc.) ======================
        Route::prefix('settings')->controller(SettingController::class)->group(function () {
            Route::get('/', 'index');
            Route::put('/', 'update');
            Route::get('/appearance', 'getAppearance');
            Route::put('/appearance', 'updateAppearance');
            Route::get('/{key}', 'show');
            Route::put('/{key}', 'updateKey');
        });

        // ====================== Wallet (all roles) ======================
        Route::prefix('wallet')->controller(ApiWalletController::class)->group(function () {
            Route::get('/', 'show');
            Route::get('/transactions', 'transactions');
            Route::get('/lookup', 'lookup');
            Route::post('/deposit', 'deposit');
            Route::post('/withdraw', 'withdraw');
            Route::post('/transfer', 'transfer');
        });

        // ====================== Notifications inbox + FCM device tokens ======================
        Route::prefix('notifications')->group(function () {
            Route::get('/', [ApiNotificationController::class, 'index']);
            Route::get('/unread-count', [ApiNotificationController::class, 'unreadCount']);
            Route::post('/read-all', [ApiNotificationController::class, 'markAllAsRead']);
            Route::post('/{id}/read', [ApiNotificationController::class, 'markAsRead'])->whereNumber('id');
            Route::delete('/{id}', [ApiNotificationController::class, 'destroy'])->whereNumber('id');

            Route::post('/register-token', [DeviceTokenController::class, 'register']);
            Route::delete('/register-token', [DeviceTokenController::class, 'unregister']);
        });

        // ====================== Seller Onboarding ======================
        Route::prefix('seller')->controller(SellerOnboardingController::class)->group(function () {
            Route::get('/onboarding', 'show');
            Route::post('/onboarding', 'onboard');
            Route::post('/documents', 'uploadDocument');
            Route::get('/status', 'status');
            Route::post('/submit-for-review', 'submitForReview');
            // Coverage matcher for trucks/deliveries (approved sellers only).
            Route::get('/nearby', 'nearby');
        });

        // ====================== Product Management (seller) ======================
        Route::prefix('products')->controller(ProductController::class)->group(function () {
            // Seller-owned product CRUD (listings/show are public above)
            Route::get('/', 'index');
            Route::post('/', 'store');
            Route::put('/{id}', 'update')->whereNumber('id');
            Route::delete('/{id}', 'destroy')->whereNumber('id');
            Route::post('/{id}/toggle-availability', 'toggleAvailability')->whereNumber('id');
            // Buyer product reviews + reports
            Route::post('/{id}/reviews', 'storeReview')->whereNumber('id');
            Route::post('/{id}/report', 'report')->whereNumber('id');
        });

        // ====================== Site Management (mutations + private views) ======================
        Route::prefix('sites')->controller(SiteController::class)->group(function () {
            // Private views
            Route::get('/{id}/staff', 'staff')->whereNumber('id');
            Route::get('/{id}/documents', 'documents')->whereNumber('id');
            Route::get('/{id}/status-logs', 'statusLogs')->whereNumber('id');

            // Buyer/Seller routes (create and manage sites)
            Route::post('/', 'store');
            Route::put('/{id}', 'update')->whereNumber('id');
            Route::delete('/{id}', 'destroy')->whereNumber('id');
            Route::post('/{id}/status', 'updateStatus')->whereNumber('id');
            Route::post('/{id}/materials', 'addMaterial')->whereNumber('id');
            Route::post('/{id}/staff', 'addStaff')->whereNumber('id');
            Route::post('/{id}/documents', 'uploadDocument');

            // Site visits
            Route::prefix('{siteId}/visits')->group(function () {
                Route::get('/', 'visits');
                Route::post('/', 'createVisit');
                Route::put('/{visitId}', 'updateVisit');
                Route::post('/{visitId}/check-in', 'checkIn');
                Route::post('/{visitId}/check-out', 'checkOut');
            });
        });

        // ====================== Truck Management ======================
        Route::prefix('trucks')->controller(TruckController::class)->group(function () {
            // Public routes (view trucks)
            Route::get('/', 'index');
            Route::get('/available', 'available');
            Route::get('/nearby', 'nearby');
            Route::get('/{id}', 'show');

            // Seller/Admin routes
            Route::post('/', 'store');
            Route::put('/{id}', 'update');
            Route::delete('/{id}', 'destroy');
            Route::post('/{id}/status', 'updateStatus');
            Route::post('/{id}/location', 'updateLocation');
            Route::post('/{id}/assign-driver', 'assignDriver');

            // Truck documents
            Route::prefix('{truckId}/documents')->group(function () {
                Route::get('/', 'documents');
                Route::post('/', 'uploadDocument');
                Route::delete('/{documentId}', 'deleteDocument');
            });

            // Truck insurance
            Route::prefix('{truckId}/insurance')->group(function () {
                Route::get('/', 'insurance');
                Route::post('/', 'addInsurance');
                Route::put('/{insuranceId}', 'updateInsurance');
            });

            // Truck maintenance
            Route::prefix('{truckId}/maintenance')->group(function () {
                Route::get('/', 'maintenance');
                Route::post('/', 'addMaintenance');
                Route::put('/{maintenanceId}', 'updateMaintenance');
            });

            // Truck activity history
            Route::get('/{truckId}/logs', 'truckLogs');
        });

        // ====================== Trip Logs ======================
        Route::prefix('trips')->controller(TripLogController::class)->group(function () {
            Route::get('/', 'index');
            // Literal path MUST precede /{id}, otherwise "statistics" is
            // captured by show() and returns 404.
            Route::get('/statistics', 'statistics');
            Route::get('/{id}', 'show')->whereNumber('id');
            Route::post('/', 'store');
            Route::put('/{id}', 'update')->whereNumber('id');
            Route::post('/{id}/start', 'startTrip')->whereNumber('id');
            Route::post('/{id}/end', 'endTrip')->whereNumber('id');
            Route::post('/{id}/location', 'updateLocation')->whereNumber('id');
        });

        // ====================== Cart ======================
        Route::prefix('cart')->controller(CartController::class)->group(function () {
            Route::get('/', 'show');
            Route::post('/add', 'add');
            Route::put('/items/{itemId}', 'updateQuantity');
            Route::delete('/items/{itemId}', 'remove');
            Route::delete('/clear', 'clear');
        });

        // ====================== Checkout ======================
        Route::prefix('checkout')->controller(CheckoutController::class)->middleware('throttle:checkout')->group(function () {
            Route::get('/summary', 'summary');
            Route::get('/validate', 'validateCart');
            Route::post('/place-order', 'placeOrder');
            Route::get('/payment-methods', 'paymentMethods');
        });

        // ====================== Orders ======================
        Route::prefix('orders')->controller(OrderController::class)->group(function () {
            // User endpoints
            Route::get('/', 'index');
            Route::post('/', 'store');
            Route::get('/seller', 'sellerOrders');
            Route::get('/statistics', 'statistics');
            Route::get('/metrics', 'metrics');

            // Admin-specific endpoints — literal paths MUST be registered
            // before /{id}, otherwise they are swallowed by the show route.
            Route::middleware('role:admin')->group(function () {
                Route::get('/analytics', 'analytics');
                Route::get('/export', 'export');
                Route::post('/bulk-status', 'bulkUpdateStatus');
            });

            Route::get('/{id}', 'show')->whereNumber('id');
            Route::get('/{id}/timeline', 'timeline')->whereNumber('id');
            Route::put('/{id}/status', 'updateStatus')->whereNumber('id');
            Route::post('/{id}/cancel', 'cancel')->whereNumber('id');
            Route::post('/{id}/review', 'storeReview')->whereNumber('id');
        });

        // ====================== My Reviews ======================
        Route::prefix('reviews')->controller(ReviewController::class)->group(function () {
            Route::get('/mine', 'mine');
        });

        // ====================== Payment Management ======================
        Route::prefix('payments')->controller(PaymentController::class)->group(function () {
            Route::get('/methods', 'methods');
            Route::post('/initiate', 'initiate');
            Route::get('/verify', 'verify');
            Route::get('/order/{orderId}', 'byOrder')->whereNumber('orderId');
            Route::get('/history', 'history');
        });

        // ====================== Saved Instruments (MoMo / card / bank) ======================
        Route::prefix('payments/instruments')->controller(PaymentInstrumentController::class)->group(function () {
            Route::get('/', 'index');
            Route::post('/', 'store');
            Route::put('/{id}', 'update');
            Route::delete('/{id}', 'destroy');
            Route::post('/{id}/default', 'setDefault');
        });

        // ====================== Delivery Management ======================
        Route::prefix('deliveries')->controller(DeliveryController::class)->group(function () {
            // User routes
            Route::get('/', 'index');
            Route::get('/statistics', 'statistics');
            // Bolt-style offers BEFORE /{id} (order matters).
            Route::get('/offers', 'offers');
            Route::post('/offers/{offer}/accept', 'acceptOffer');
            Route::post('/offers/{offer}/decline', 'declineOffer');
            Route::post('/presence', 'presence');
            Route::get('/{id}', 'show');

            // Driver routes
            Route::post('/{id}/accept', 'accept');
            Route::post('/{id}/decline', 'decline');
            Route::post('/{id}/location', 'updateLocation');
            Route::put('/{id}/status', 'updateStatus');

            // Admin/Seller routes
            Route::post('/assign-driver', 'assignDriver');
            Route::post('/{id}/dispatch', 'dispatch')->middleware('throttle:dispatch');
            Route::get('/drivers/available', 'availableDrivers');
            Route::get('/{id}/suggested-trucks', 'suggestedTrucks');
        });

        // ====================== Activity Logs (admin / permission) ======================
        Route::prefix('activity-logs')->controller(ActivityLogController::class)->group(function () {
            Route::get('/', 'index');
            Route::get('/{id}', 'show');
        });
    });
});

// ====================== Webhook Routes (Public) ======================
Route::post('/payments/hubtel-callback', [PaymentController::class, 'hubtelCallback'])->middleware('throttle:webhook');
Route::post('/payments/paystack-callback', [PaymentController::class, 'paystackCallback'])->middleware('throttle:webhook');
