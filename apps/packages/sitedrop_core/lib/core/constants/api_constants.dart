// lib/core/constants/api_constants.dart
import 'package:flutter/foundation.dart';
import '../../config/app_config.dart';

class ApiConstants {
  // ============================================================
  // BASE URLS - Direct usage from AppConfig
  // ============================================================
  static String get baseUrl {
    if (kIsWeb) {
      return AppConfig.webApiUrl;
    }
    return AppConfig.apiBaseUrl;
  }

  static String get baseUrlAlt => AppConfig.apiBaseUrl;

  // ============================================================
  // ASSET URLS
  // ============================================================
  /// Origin (scheme + host + port) of the API server, e.g.
  /// `http://10.0.2.2:8000` on the Android emulator or
  /// `http://localhost:8000` elsewhere. The backend stores uploads as
  /// relative `/assets/...` (or legacy `/storage/...`) paths, so the apps
  /// must resolve them against this origin to display images.
  static String get serverOrigin {
    final base = baseUrl.replaceAll(RegExp(r'/+$'), '');
    const suffix = '/api/$apiVersion';
    if (base.endsWith(suffix)) {
      return base.substring(0, base.length - suffix.length);
    }
    const fallback = '/api';
    if (base.endsWith(fallback)) {
      return base.substring(0, base.length - fallback.length);
    }
    return base;
  }

  /// Turn a backend file reference into a loadable absolute URL.
  /// Absolute http(s)/data/blob/file URLs pass through untouched; relative
  /// `/assets/...` and `/storage/...` paths are resolved via [serverOrigin].
  ///
  /// On web the URL points at `GET /api/v1/files/...` instead of the file
  /// directly: Flutter web (CanvasKit) refuses cross-origin images without
  /// CORS headers, and `php artisan serve` never sends any for static files.
  /// The file endpoint streams the same `public/assets/...` bytes through
  /// the API middleware stack (which does send CORS).
  static String resolveAssetUrl(String? url) {
    final u = (url ?? '').trim();
    if (u.isEmpty) {
      return '';
    }
    if (u.startsWith('http://') ||
        u.startsWith('https://') ||
        u.startsWith('data:') ||
        u.startsWith('blob:') ||
        u.startsWith('file://')) {
      return u;
    }
    final path = u.startsWith('/') ? u : '/$u';
    if (kIsWeb) {
      const assetsPrefix = '/assets/';
      const storagePrefix = '/storage/';
      if (path.startsWith(assetsPrefix)) {
        return '$serverOrigin/api/$apiVersion/files${path.substring(assetsPrefix.length - 1)}';
      }
      if (path.startsWith(storagePrefix)) {
        return '$serverOrigin/api/$apiVersion/files${path.substring(storagePrefix.length - 1)}';
      }
    }
    return '$serverOrigin$path';
  }

  /// Inverse of [resolveAssetUrl]: strip [serverOrigin] back to the stored
  /// `/assets/...` path when echoing URLs to the backend (e.g.
  /// `existing_images`, where the server diffs against stored values).
  /// Web file-endpoint URLs (`/api/v1/files/...`) map back to `/assets/...`
  /// (product images have only ever lived there).
  static String toStoragePath(String? url) {
    final u = (url ?? '').trim();
    if (u.isEmpty) {
      return '';
    }
    final origin = serverOrigin;
    var path = u;
    if (u.startsWith('$origin/')) {
      path = u.substring(origin.length);
    }
    const filePrefix = '/api/$apiVersion/files/';
    if (path.startsWith(filePrefix)) {
      return '/assets/${path.substring(filePrefix.length)}';
    }
    return path;
  }

  // ============================================================
  // API VERSION
  // ============================================================
  static const String apiVersion = 'v1';
  static const String apiPrefix = '/api/$apiVersion';

  // ============================================================
  // AUTH ENDPOINTS
  // ============================================================
  static const String auth = '/auth';
  static const String login = '/auth/login';
  static const String loginOtp = '/auth/login-otp';
  static const String register = '/auth/register';
  static const String logout = '/auth/logout';
  static const String otpSend = '/auth/otp/send';
  static const String otpVerify = '/auth/otp/verify';
  static const String user = '/user';
  static const String profile = '/profile';
  static const String profileAvatar = '/profile/avatar';
  static const String profilePreferences =
      '/profile/preferences';

  // ============================================================
  // ACCOUNT SECURITY (password + two-factor)
  // ============================================================
  static const String profilePassword = '/profile/password';
  static const String twoFactorStatus = '/profile/2fa/status';
  static const String twoFactorEnable = '/profile/2fa/enable';
  static const String twoFactorConfirm = '/profile/2fa/confirm';
  static const String twoFactorDisable = '/profile/2fa';
  static const String changePassword = '/auth/change-password';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';

  // ============================================================
  // USER SETTINGS (appearance / theme)
  // ============================================================
  static const String settings = '/settings';
  static const String settingsAppearance = '/settings/appearance';
  static String settingKey(String key) => '/settings/$key';

  // ============================================================
  // PRODUCT ENDPOINTS
  // ============================================================
  static const String products = '/products';
  static const String productListings = '/products/listings';
  static const String productCategories = '/products/categories';

  static String productDetail(String id) => '/products/$id';
  static String productToggleAvailability(String id) =>
      '/products/$id/toggle-availability';
  static String productReviews(String id) => '/products/$id/reviews';

  // ============================================================
  // REVIEW ENDPOINTS (mine + order/trip ratings)
  // ============================================================
  static const String reviewsMine = '/reviews/mine';

  static String orderReview(String orderId) => '/orders/$orderId/review';

  // ============================================================
  // SAVED INSTRUMENTS (MoMo / card / bank)
  // ============================================================
  static const String paymentInstruments = '/payments/instruments';

  static String paymentInstrument(String id) =>
      '/payments/instruments/$id';

  static String paymentInstrumentDefault(String id) =>
      '/payments/instruments/$id/default';

  // ============================================================
  // ORDER ENDPOINTS
  // ============================================================
  static const String orders = '/orders';
  static const String orderTimeline = '/orders/{id}/timeline';
  static const String orderAnalytics = '/orders/analytics';
  static const String orderMetrics = '/orders/metrics';

  static String orderDetail(String id) => '/orders/$id';
  static String orderStatusUpdate(String id) => '/orders/$id/status';
  static String orderCancelUrl(String id) => '/orders/$id/cancel';

  // ============================================================
  // CART ENDPOINTS
  // ============================================================
  static const String cart = '/cart';
  static const String cartAdd = '/cart/add';
  static const String cartClear = '/cart/clear';

  static String cartItem(String itemId) => '/cart/items/$itemId';

  // ============================================================
  // CHECKOUT ENDPOINTS - NEW
  // ============================================================
  static const String checkoutSummary = '/checkout/summary';
  static const String checkoutValidate = '/checkout/validate';
  static const String checkoutPlaceOrder = '/checkout/place-order';
  static const String checkoutPaymentMethods = '/checkout/payment-methods';

  // ============================================================
  // DELIVERY ENDPOINTS
  // ============================================================
  static const String deliveries = '/deliveries';
  static const String deliveryLocation = '/deliveries/{id}/location';
  static const String deliveryStatus = '/deliveries/{id}/status';
  static const String deliveryAssign = '/deliveries/assign-driver';
  static const String deliveryStatistics = '/deliveries/statistics';

  static String deliveryDetail(String id) => '/deliveries/$id';

  static String deliveryAccept(String id) => '/deliveries/$id/accept';

  static String deliveryDecline(String id) => '/deliveries/$id/decline';

  // SiteDrop-style dispatch (broadcast offers, first-accept wins).
  static const String deliveryOffers = '/deliveries/offers';
  static const String deliveryPresence = '/deliveries/presence';

  static String deliveryOfferAccept(String offerId) =>
      '/deliveries/offers/$offerId/accept';

  static String deliveryOfferDecline(String offerId) =>
      '/deliveries/offers/$offerId/decline';

  static String deliveryDispatch(String deliveryId) =>
      '/deliveries/$deliveryId/dispatch';

  // ============================================================
  // SELLER ENDPOINTS
  // ============================================================
  static const String seller = '/seller';
  static const String sellerOnboarding = '/seller/onboarding';
  static const String sellerDocuments = '/seller/documents';
  static const String sellerStatus = '/seller/status';
  static const String sellerSubmitForReview = '/seller/submit-for-review';

  // ============================================================
  // BUYER ENDPOINTS
  // ============================================================
  static const String wishlist = '/wishlist';
  static const String wishlistAdd = '/wishlist/add';
  static const String wishlistRemove = '/wishlist/remove';
  static const String wishlistToggle = '/wishlist/toggle';
  static const String wishlistCheck = '/wishlist/check';

  // ============================================================
  // PROFILE STATS
  // ============================================================
  static const String profileStats = '/profile/stats';

  // ============================================================
  // WALLET
  // ============================================================
  static const String wallet = '/wallet';
  static const String walletTransactions = '/wallet/transactions';
  static const String walletDeposit = '/wallet/deposit';
  static const String walletWithdraw = '/wallet/withdraw';
  static const String walletTransfer = '/wallet/transfer';
  static const String walletLookup = '/wallet/lookup';

  // ============================================================
  // PAYMENT ENDPOINTS (Laravel Api\PaymentController)
  // Paths are relative to baseUrl which already includes /api/v1
  // ============================================================
  static const String payments = '/payments';
  static const String paymentMethods = '/payments/methods';
  /// POST /api/v1/payments/initiate
  static const String paymentInitiate = '/payments/initiate';
  /// @deprecated use [paymentInitiate]
  static const String paymentInitialize = '/payments/initiate';
  /// GET /api/v1/payments/verify?payment_reference=
  static const String paymentVerify = '/payments/verify';
  /// GET /api/v1/payments/history
  static const String paymentHistory = '/payments/history';
  /// GET /api/v1/payments/order/{orderId}
  static String paymentByOrder(String orderId) => '/payments/order/$orderId';

  // ============================================================
  // ADDRESS ENDPOINTS (UserProfile address book)
  // ============================================================
  static const String addresses = '/addresses';
  static String addressDetail(String id) => '/addresses/$id';
  static String addressSetDefault(String id) => '/addresses/$id/default';

  // ============================================================
  // NOTIFICATION ENDPOINTS
  // ============================================================
  static const String notifications = '/notifications';
  static const String notificationUnreadCount = '/notifications/unread-count';
  static const String notificationMarkRead = '/notifications/{id}/read';
  static const String notificationMarkAllRead = '/notifications/read-all';
  static const String notificationRegisterToken =
      '/notifications/register-token';

  // ============================================================
  // SUPPORT ENDPOINTS
  // ============================================================
  static const String support = '/support';

  // ============================================================
  // SITE ENDPOINTS
  // ============================================================
  static const String sites = '/sites';
  static const String sitesNearby = '/sites/nearby';
  static const String sitesMaterials = '/sites/{id}/materials';
  static const String sitesStaff = '/sites/{id}/staff';
  static const String sitesDocuments = '/sites/{id}/documents';
  static const String sitesStatus = '/sites/{id}/status';
  static const String sitesVisits = '/sites/{siteId}/visits';
  static const String sitesCheckIn =
      '/sites/{siteId}/visits/{visitId}/check-in';
  static const String sitesCheckOut =
      '/sites/{siteId}/visits/{visitId}/check-out';

  static String siteDetail(String id) => '/sites/$id';

  // ============================================================
  // TRUCK ENDPOINTS
  // ============================================================
  static const String trucks = '/trucks';
  static const String trucksAvailable = '/trucks/available';
  static const String trucksNearby = '/trucks/nearby';
  static const String trucksStatus = '/trucks/{id}/status';
  static const String trucksLocation = '/trucks/{id}/location';
  static const String trucksAssignDriver = '/trucks/{id}/assign-driver';
  static const String trucksDocuments = '/trucks/{truckId}/documents';
  static const String trucksInsurance = '/trucks/{truckId}/insurance';
  static const String trucksMaintenance = '/trucks/{truckId}/maintenance';

  static String truckDetail(String id) => '/trucks/$id';
  static String truckLogs(String truckId) => '/trucks/$truckId/logs';

  // ============================================================
  // TRIP ENDPOINTS
  // ============================================================
  static const String trips = '/trips';
  static const String tripsStart = '/trips/{id}/start';
  static const String tripsEnd = '/trips/{id}/end';
  static const String tripsLocation = '/trips/{id}/location';
  static const String tripsStatistics = '/trips/statistics';

  static String tripDetail(String id) => '/trips/$id';

  // ============================================================
  // STATIC ENDPOINTS
  // ============================================================
  // (removed: no backend exposes /static/*; categories come from
  // GET /products/categories.)

  // ============================================================
  // PUBLIC APP CONFIG (SystemSettingController::publicConfig)
  // ============================================================
  /// GET /api/v1/config?platform=android|ios|web
  static const String publicConfig = '/config';
  static const String systemSettingsPublic = '/system-settings/public';

  // ============================================================
  // HEALTH CHECK
  // ============================================================
  static const String health = '/health';

  // ============================================================
  // HEADERS
  // ============================================================
  static const String authorization = 'Authorization';
  static const String bearer = 'Bearer';
  static const String contentType = 'Content-Type';
  static const String applicationJson = 'application/json';
  static const String accept = 'Accept';
  static const String xApiKey = 'X-API-Key';
  static const String xPlatform = 'X-Platform';
  static const String xAppVersion = 'X-App-Version';

  // ============================================================
  // PLATFORM HEADERS
  // ============================================================
  static String get platformHeader {
    if (kIsWeb) return 'web';
    return 'mobile';
  }

  static String get appVersionHeader => AppConfig.appVersion;

  // ============================================================
  // TIMEOUTS
  // ============================================================
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);

  static const Duration uploadTimeout = Duration(minutes: 5);

  // ============================================================
  // PAGINATION
  // ============================================================
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;
  static const int minPageSize = 1;

  // ============================================================
  // UTILITY METHODS
  // ============================================================
  static String buildUrl(String endpoint, {Map<String, String>? params}) {
    String url = endpoint;
    if (params != null) {
      params.forEach((key, value) {
        url = url.replaceAll('{$key}', value);
      });
    }
    return url;
  }

  static String buildQueryUrl(
    String endpoint,
    Map<String, dynamic>? queryParams,
  ) {
    if (queryParams == null || queryParams.isEmpty) {
      return endpoint;
    }
    final uri = Uri.parse(endpoint).replace(
      queryParameters: queryParams.map(
        (key, value) => MapEntry(key, value.toString()),
      ),
    );
    return uri.toString();
  }

  static String getFullUrl(String endpoint) {
    return '$baseUrl$endpoint';
  }

  // ============================================================
  // HTTP STATUS CODES
  // ============================================================
  static const int statusOk = 200;
  static const int statusCreated = 201;
  static const int statusAccepted = 202;
  static const int statusNoContent = 204;
  static const int statusBadRequest = 400;
  static const int statusUnauthorized = 401;
  static const int statusForbidden = 403;
  static const int statusNotFound = 404;
  static const int statusMethodNotAllowed = 405;
  static const int statusConflict = 409;
  static const int statusUnprocessableEntity = 422;
  static const int statusTooManyRequests = 429;
  static const int statusInternalServerError = 500;
  static const int statusBadGateway = 502;
  static const int statusServiceUnavailable = 503;
  static const int statusGatewayTimeout = 504;
}
