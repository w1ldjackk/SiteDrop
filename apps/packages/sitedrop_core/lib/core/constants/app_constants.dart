// lib/core/constants/app_constants.dart

class AppConstants {
  static const String appName = 'SiteDrop';
  static const String appVersion = '1.0.0';

  // Storage Keys
  static const String authTokenKey = 'auth_token';
  static const String userKey = 'user';
  static const String rememberMeKey = 'remember_me';
  static const String themeModeKey = 'theme_mode';
  static const String languageKey = 'language';

  // Hive Box Names
  static const String cartBox = 'cart_box';
  static const String userBox = 'user_box';
  static const String settingsBox = 'settings_box';
  static const String ordersBox = 'orders_box';
  static const String productsBox = 'products_box';

  // Google Maps
  static const String googleMapsAndroidKey = 'YOUR_ANDROID_KEY';
  static const String googleMapsIosKey = 'YOUR_IOS_KEY';

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // Ghana Phone
  static const String ghanaCountryCode = '+233';
  static const String ghanaCountryCodePrefix = '233';
  static const int ghanaPhoneLength = 10;

  // Payment Methods (Display Names)
  static const List<String> paymentMethods = [
    'Mobile Money',
    'Paystack',
    'Cash on Delivery',
    'Bank Transfer',
    'Wallet Balance',
  ];

  // Payment Method API Mapping (Display Name -> API Value)
  static const Map<String, String> paymentMethodApiMap = {
    'Mobile Money': 'mobile_money',
    'Paystack': 'card',
    'Cash on Delivery': 'cash_on_delivery',
    'Bank Transfer': 'bank_transfer',
    'Wallet Balance': 'wallet',
  };

  // Payment Method Display Mapping (API Value -> Display Name)
  static const Map<String, String> paymentMethodDisplayMap = {
    'mobile_money': 'Mobile Money',
    'card': 'Paystack',
    'cash_on_delivery': 'Cash on Delivery',
    'bank_transfer': 'Bank Transfer',
    'wallet': 'Wallet Balance',
  };

  // Mobile Money Networks (Ghana)
  static const List<String> mobileMoneyNetworks = [
    'MTN Mobile Money',
    'Vodafone Cash',
    'AirtelTigo Money',
  ];

  /// Display network → API value (`CheckoutRequest` only accepts these).
  static const Map<String, String> mobileMoneyNetworkApiMap = {
    'MTN Mobile Money': 'MTN',
    'MTN': 'MTN',
    'Vodafone Cash': 'Vodafone',
    'Vodafone': 'Vodafone',
    'AirtelTigo Money': 'AirtelTigo',
    'AirtelTigo': 'AirtelTigo',
  };

  /// Guess the network from a Ghanaian phone prefix (fallback only).
  static String? networkForPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    final local = digits.startsWith('233') && digits.length == 12
        ? '0${digits.substring(3)}'
        : digits;
    if (local.length != 10) return null;
    const mtn = {'024', '025', '053', '054', '055', '059'};
    const voda = {'020', '050'};
    const aft = {'026', '027', '056', '057'};
    final prefix = local.substring(0, 3);
    if (mtn.contains(prefix)) return 'MTN';
    if (voda.contains(prefix)) return 'Vodafone';
    if (aft.contains(prefix)) return 'AirtelTigo';
    return null;
  }

  // Order Status
  static const List<String> orderStatuses = [
    'pending',
    'confirmed',
    'dispatched',
    'delivered',
    'cancelled',
  ];

  // Product Categories
  static const List<String> productCategories = [
    'Sand',
    'Gravel',
    'Stones',
    'Quarry Materials',
    'Cement Blocks',
    'Cement',
    'Steel',
    'Lumber',
    'Paints',
    'Plumbing',
    'Electrical',
    'Tools',
    'Other',
  ];

  /// Display label → backend category slug (`GET /products?category=` uses
  /// exact match against these slugs). Labels without an entry fall back
  /// to a `?search=` query instead of an empty category result.
  static const Map<String, String> productCategorySlugs = {
    'Sand': 'sand',
    'Gravel': 'gravel',
    'Stones': 'stones',
    'Cement Blocks': 'blocks',
    'Cement': 'cement',
    'Steel': 'steel',
    'Paints': 'paint',
    'Plumbing': 'plumbing',
  };

  /// Backend slug → display label (for screen titles).
  static String categoryLabel(String slug) {
    for (final entry in productCategorySlugs.entries) {
      if (entry.value == slug) return entry.key;
    }
    return slug;
  }

  // Units
  static const List<String> units = [
    'trip',
    'ton',
    'kg',
    'bag',
    'piece',
    'cubic meter',
    'square meter',
    'roll',
    'litre',
  ];
}
