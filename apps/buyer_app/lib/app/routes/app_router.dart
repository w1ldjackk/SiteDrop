// Buyer app router — marketplace + cart + profile (no seller/driver routes)
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sitedrop_core/app/routes/route_names.dart';
import 'package:sitedrop_core/config/auth_role_guard.dart';

import '../../presentation/providers/auth_provider.dart';
import '../../presentation/screens/shared/splash_screen.dart' as shared;
import '../../presentation/screens/shared/onboarding_screen.dart' as shared;
import '../../presentation/screens/shared/notifications_screen.dart' as shared;
import '../../presentation/screens/shared/wallet_screen.dart' as shared;
import '../../presentation/screens/auth/login_screen.dart' as auth;
import '../../presentation/screens/auth/register_screen.dart' as auth;
import '../../presentation/screens/auth/otp_verification_screen.dart' as auth;
import '../../presentation/screens/auth/forgot_password_screen.dart' as auth;
import '../../presentation/screens/buyer/home_screen.dart' as buyer;
import '../../presentation/screens/buyer/product_list_screen.dart' as buyer;
import '../../presentation/screens/buyer/sites_management_screen.dart' as buyer;
import '../../presentation/screens/buyer/add_edit_site_screen.dart' as buyer;
import '../../presentation/screens/buyer/product_detail_screen.dart' as buyer;
import '../../presentation/screens/buyer/cart_screen.dart' as buyer;
import '../../presentation/screens/buyer/checkout_screen.dart' as buyer;
import '../../presentation/screens/buyer/payment_screen.dart' as buyer;
import '../../presentation/screens/buyer/order_tracking_screen.dart' as buyer;
import '../../presentation/screens/buyer/order_history_screen.dart' as buyer;
import '../../presentation/screens/buyer/track_orders_screen.dart' as buyer;
import '../../presentation/screens/buyer/wishlist_screen.dart' as buyer;
import '../../presentation/screens/buyer/categories_screen.dart' as buyer;
import '../../presentation/screens/profile/role_profile_screen.dart' as profile;
import '../../presentation/screens/profile/role_edit_profile_screen.dart'
    as profile;
import '../../presentation/screens/profile/shared/settings_screen.dart'
    as profile;
import '../../presentation/screens/profile/shared/help_support_screen.dart'
    as profile;
import '../../presentation/screens/profile/shared/privacy_policy_screen.dart'
    as profile;
import '../../presentation/screens/profile/shared/terms_of_service_screen.dart'
    as profile;
import '../../presentation/screens/profile/user/addresses_screen.dart'
    as profile;
import '../../presentation/screens/profile/user/address_form_screen.dart'
    as profile;
import '../../presentation/screens/profile/user/payment_methods_screen.dart'
    as profile;
import '../../presentation/screens/profile/user/my_reviews_screen.dart'
    as profile;

class _AuthRouterRefresh extends ChangeNotifier {
  _AuthRouterRefresh(Ref ref) {
    _sub = ref.listen<AsyncValue<AuthState>>(authProvider, (context, state) {
      notifyListeners();
    });
  }

  late final ProviderSubscription<AsyncValue<AuthState>> _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: RouteNames.splash,
    refreshListenable: refresh,
    routes: [
      GoRoute(
        path: RouteNames.splash,
        builder: (context, state) => const shared.SplashScreen(),
      ),
      GoRoute(
        path: RouteNames.onboarding,
        builder: (context, state) => const shared.OnboardingScreen(),
      ),
      GoRoute(
        path: RouteNames.notifications,
        builder: (context, state) => const shared.NotificationsScreen(),
      ),
      GoRoute(
        path: RouteNames.wallet,
        builder: (context, state) => const shared.WalletScreen(),
      ),
      GoRoute(
        path: RouteNames.login,
        builder: (context, state) => const auth.LoginScreen(),
      ),
      GoRoute(
        path: RouteNames.register,
        builder: (context, state) => const auth.RegisterScreen(),
      ),
      GoRoute(
        path: RouteNames.otpVerification,
        builder: (context, state) {
          final phone = state.extra as String? ?? '';
          return auth.OtpVerificationScreen(phone: phone);
        },
      ),
      GoRoute(
        path: RouteNames.forgotPassword,
        builder: (context, state) => const auth.ForgotPasswordScreen(),
      ),
      GoRoute(
        path: RouteNames.home,
        builder: (context, state) => const buyer.HomeScreen(),
      ),
      GoRoute(
        path: RouteNames.products,
        builder: (context, state) => buyer.ProductListScreen(
          initialSearch: state.uri.queryParameters['search'],
          initialCategory: state.uri.queryParameters['category'],
        ),
      ),
      GoRoute(
        path: RouteNames.categories,
        builder: (context, state) => const buyer.CategoriesScreen(),
      ),
      GoRoute(
        path: RouteNames.productDetail,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return buyer.ProductDetailScreen(productId: id);
        },
      ),
      GoRoute(
        path: RouteNames.cart,
        builder: (context, state) => const buyer.CartScreen(showBottomNav: true),
      ),
      GoRoute(
        path: RouteNames.checkout,
        builder: (context, state) => const buyer.CheckoutScreen(),
      ),
      GoRoute(
        path: RouteNames.payment,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return buyer.PaymentScreen(
            orderId: extra['orderId']?.toString() ?? '',
            paymentUrl: extra['paymentUrl']?.toString() ?? '',
            amount: (extra['amount'] as num?)?.toDouble() ?? 0.0,
            reference: extra['reference']?.toString() ?? '',
            paymentMethod: extra['paymentMethod']?.toString() ?? '',
          );
        },
      ),
      GoRoute(
        path: RouteNames.orderTracking,
        builder: (context, state) {
          final orderId = state.pathParameters['orderId'] ?? '';
          return buyer.OrderTrackingScreen(orderId: orderId);
        },
      ),
      GoRoute(
        path: RouteNames.orderHistory,
        builder: (context, state) => const buyer.OrderHistoryScreen(),
      ),
      GoRoute(
        path: RouteNames.trackOrders,
        builder: (context, state) => const buyer.TrackOrdersScreen(),
      ),
      GoRoute(
        path: RouteNames.trackOrder,
        builder: (context, state) =>
            buyer.OrderTrackingScreen(orderId: state.pathParameters['orderId'] ?? ''),
      ),
      GoRoute(
        path: RouteNames.wishlist,
        builder: (context, state) => const buyer.WishlistScreen(),
      ),
      GoRoute(
        path: RouteNames.buyerSites,
        builder: (context, state) => const buyer.BuyerSitesManagementScreen(),
      ),
      GoRoute(
        path: RouteNames.buyerAddSite,
        builder: (context, state) => const buyer.BuyerAddEditSiteScreen(),
      ),
      GoRoute(
        path: RouteNames.buyerEditSite,
        builder: (context, state) =>
            buyer.BuyerAddEditSiteScreen(siteId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: RouteNames.profile,
        builder: (context, state) => const profile.ProfileScreen(),
      ),
      GoRoute(
        path: RouteNames.editProfile,
        builder: (context, state) => const profile.EditProfileScreen(),
      ),
      GoRoute(
        path: RouteNames.settings,
        builder: (context, state) => const profile.SettingsScreen(),
      ),
      GoRoute(
        path: RouteNames.helpSupport,
        builder: (context, state) => const profile.HelpSupportScreen(),
      ),
      GoRoute(
        path: RouteNames.privacyPolicy,
        builder: (context, state) => const profile.PrivacyPolicyScreen(),
      ),
      GoRoute(
        path: RouteNames.termsOfService,
        builder: (context, state) => const profile.TermsOfServiceScreen(),
      ),
      GoRoute(
        path: RouteNames.addresses,
        builder: (context, state) => const profile.AddressesScreen(),
      ),
      GoRoute(
        path: RouteNames.addAddress,
        builder: (context, state) => const profile.AddressFormScreen(),
      ),
      GoRoute(
        path: RouteNames.editAddress,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return profile.AddressFormScreen(addressId: id);
        },
      ),
      GoRoute(
        path: RouteNames.paymentMethods,
        builder: (context, state) => const profile.PaymentMethodsScreen(),
      ),
      GoRoute(
        path: RouteNames.reviews,
        builder: (context, state) => const profile.MyReviewsScreen(),
      ),
    ],
    redirect: (context, state) {
      final authAsync = ref.read(authProvider);
      final authState = authAsync.asData?.value;
      final isAuthLoading = authAsync.isLoading && authAsync.asData == null;
      final loc = state.matchedLocation;

      final isAuthRoute = loc.startsWith('/login') ||
          loc.startsWith('/register') ||
          loc.startsWith('/otp-verification') ||
          loc.startsWith('/forgot-password');

      final isPublicRoute = loc == RouteNames.splash ||
          loc == RouteNames.home ||
          loc.startsWith('/home') ||
          loc.startsWith('/products') ||
          loc.startsWith('/categories') ||
          loc.startsWith('/onboarding') ||
          loc.startsWith('/privacy') ||
          loc.startsWith('/terms') ||
          loc.startsWith('/help');

      final isProtected = loc.startsWith('/cart') ||
          loc.startsWith('/checkout') ||
          loc.startsWith('/payment') ||
          loc.startsWith('/order-tracking') ||
          loc.startsWith('/order-history') ||
          loc.startsWith('/track-orders') ||
          loc.startsWith('/profile') ||
          loc.startsWith('/wallet') ||
          loc.startsWith('/wishlist') ||
          loc.startsWith('/addresses') ||
          loc.startsWith('/payment-methods') ||
          loc.startsWith('/reviews') ||
          loc.startsWith('/settings') ||
          loc.startsWith('/notifications') ||
          loc.startsWith('/sites');

      // Wrong role (seller/driver account) → force login message path
      if (authState is AuthAuthenticated) {
        final u = authState.user;
        if (!AuthRoleGuard.isAllowed(u)) {
          // Stay signed out of buyer app for staff roles
          if (!isAuthRoute) return RouteNames.login;
        }
      }

      if (authState is AuthAuthenticated && isAuthRoute) {
        return RouteNames.home;
      }

      if (!isAuthLoading &&
          authState is AuthUnauthenticated &&
          isProtected) {
        return RouteNames.login;
      }

      if (loc == RouteNames.splash) {
        if (isAuthLoading) return null;
        if (authState is AuthAuthenticated &&
            AuthRoleGuard.isAllowed(authState.user)) {
          return RouteNames.home;
        }
        return RouteNames.home; // guest marketplace
      }

      if (isPublicRoute) return null;
      return null;
    },
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text('Page not found'),
            if (kDebugMode) Text(state.uri.toString()),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go(RouteNames.home),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
});
