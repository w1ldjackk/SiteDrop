// lib/app/routes/route_names.dart
class RouteNames {
  // ============================================================
  // AUTH ROUTES
  // ============================================================
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String otpVerification = '/otp-verification';
  static const String otpVerifyLogin = '/otp-verification/login';
  static const String forgotPassword = '/forgot-password';

  // ============================================================
  // BUYER ROUTES
  // ============================================================
  static const String home = '/home';
  static const String products = '/products';
  static const String productDetail = '/products/:id';
  static const String cart = '/cart';
  static const String checkout = '/checkout';
  static const String payment = '/payment';
  static const String orderTracking = '/order-tracking/:orderId';
  static const String orderHistory = '/order-history';
  static const String trackOrders = '/track-orders';
  static const String trackOrder = '/track-order/:orderId';
  static const String reviews = '/reviews';
  static const String wishlist = '/wishlist';
  static const String categories = '/categories';

  // ============================================================
  // SITE ROUTES (Buyer — Construction Sites)
  // ============================================================
  static const String buyerSites = '/sites';
  static const String buyerAddSite = '/sites/add';
  static const String buyerEditSite = '/sites/:id/edit';
  static const String buyerSiteDetail = '/sites/:id';

// ============================================================
// SELLER ROUTES
// ============================================================
static const String sellerDashboard = '/seller/dashboard';
static const String addProduct = '/seller/products/add';
static const String editProduct = '/seller/products/:id/edit';
static const String productManagement = '/seller/products';
static const String orderManagement = '/seller/orders';
static const String sellerOrderDetail = '/seller/orders/:id';
static const String earnings = '/seller/earnings';
static const String sellerOnboarding = '/seller/onboarding';
static const String sellerVerificationDocuments =
    '/seller/verification-documents';

  // ============================================================
  // SITE ROUTES (Seller)
  // ============================================================
  static const String sitesManagement = '/seller/sites';
  static const String addSite = '/seller/sites/add';
  static const String editSite = '/seller/sites/:id/edit';
  static const String siteDetail = '/seller/sites/:id';

  // ============================================================
  // TRUCK ROUTES (Seller)
  // ============================================================
  static const String trucksManagement = '/seller/trucks';
  static const String addTruck = '/seller/trucks/add';
  static const String editTruck = '/seller/trucks/:id/edit';
  static const String truckDetail = '/seller/trucks/:id';
static const String addSiteMaterial = '/seller/sites/:siteId/materials/add';
static const String addSiteStaff = '/seller/sites/:siteId/staff/add';
static const String addSiteVisit = '/seller/sites/:siteId/visits/add';
static const String addSiteDocument = '/seller/sites/:siteId/documents/add';

  // ============================================================
  // DRIVER ROUTES
  // ============================================================
  static const String driverDashboard = '/driver/dashboard';
  static const String deliveryAssignments = '/driver/deliveries';
  static const String deliveryTracking = '/driver/delivery/:id';
  static const String driverEarnings = '/driver/earnings';
  static const String driverTruckSetup = '/driver/truck-setup';
  static const String driverTrucks = '/driver/trucks';
  static const String driverTruckDetail = '/driver/trucks/detail';

  // ============================================================
  // PROFILE ROUTES
  // ============================================================
  static const String profile = '/profile';
  static const String editProfile = '/profile/edit';
  static const String settings = '/settings';
  static const String notifications = '/notifications';
  static const String wallet = '/wallet';
  static const String helpSupport = '/help-support';
  static const String privacyPolicy = '/privacy-policy';
  static const String termsOfService = '/terms-of-service';

  // ============================================================
  // ADDRESSES & SAVED PAYMENT METHODS
  // ============================================================
  static const String addresses = '/addresses';
  static const String addAddress = '/addresses/add';
  static const String editAddress = '/addresses/:id/edit';
  static const String paymentMethods = '/payment-methods';

  // ============================================================
  // SHARED ROUTES
  // ============================================================
  static const String onboarding = '/onboarding';

  // ============================================================
  // UTILITY METHODS
  // ============================================================

  /// Build a route with parameters
  static String buildRoute(String route, Map<String, String> params) {
    String result = route;
    params.forEach((key, value) {
      result = result.replaceAll(':$key', value);
    });
    return result;
  }

  /// Build product detail route
  static String productDetailWithId(String id) {
    return productDetail.replaceAll(':id', id);
  }

  /// Build order tracking route
  static String orderTrackingWithId(String orderId) {
    return orderTracking.replaceAll(':orderId', orderId);
  }

  /// Build track order route (for seller/driver viewing delivery)
  static String trackOrderWithId(String orderId) {
    return trackOrder.replaceAll(':orderId', orderId);
  }

  /// Build edit product route
  static String editProductWithId(String id) {
    return editProduct.replaceAll(':id', id);
  }

  /// Build add/edit product route (same route, different params)
  static String addProductWithId(String id) {
    return editProduct.replaceAll(':id', id);
  }

  /// Build seller order detail route
  static String sellerOrderDetailWithId(String id) {
    return sellerOrderDetail.replaceAll(':id', id);
  }

  /// Build delivery tracking route
  static String deliveryTrackingWithId(String id) {
    return deliveryTracking.replaceAll(':id', id);
  }

  /// Payment screen path. Pass order details via `context.push(payment, extra: {...})`.
  static String paymentWithParams({
    required String orderId,
    required String paymentUrl,
    required double amount,
    required String reference,
    required String paymentMethod,
  }) {
    return payment;
  }

  /// Build edit address route
  static String editAddressWithId(String id) {
    return editAddress.replaceAll(':id', id);
  }

  /// Build site routes
  static String siteDetailWithId(String id) {
    return siteDetail.replaceAll(':id', id);
  }

  static String editSiteWithId(String id) {
    return editSite.replaceAll(':id', id);
  }

  static String addSiteMaterialWithId(String siteId) {
    return addSiteMaterial.replaceAll(':siteId', siteId);
  }

  static String addSiteStaffWithId(String siteId) {
    return addSiteStaff.replaceAll(':siteId', siteId);
  }

  static String addSiteVisitWithId(String siteId) {
    return addSiteVisit.replaceAll(':siteId', siteId);
  }

  static String addSiteDocumentWithId(String siteId) {
    return addSiteDocument.replaceAll(':siteId', siteId);
  }

  /// Build buyer site routes
  static String buyerSiteDetailWithId(String id) {
    return buyerSiteDetail.replaceAll(':id', id);
  }

  static String buyerEditSiteWithId(String id) {
    return buyerEditSite.replaceAll(':id', id);
  }
}
