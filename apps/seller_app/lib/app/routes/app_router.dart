// Seller router — auth required; home = SellerHomeShell
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sitedrop_core/app/routes/route_names.dart';
import 'package:sitedrop_core/config/auth_role_guard.dart';

import '../../presentation/providers/auth_provider.dart';
import '../../presentation/screens/shared/splash_screen.dart' as shared;
import '../../presentation/screens/shared/notifications_screen.dart' as shared;
import '../../presentation/screens/auth/login_screen.dart' as auth;
import '../../presentation/screens/auth/register_screen.dart' as auth;
import '../../presentation/screens/auth/otp_verification_screen.dart' as auth;
import '../../presentation/screens/auth/forgot_password_screen.dart' as auth;
import '../../presentation/screens/seller/seller_home_shell.dart' as seller;
import '../../presentation/screens/seller/add_product_screen.dart' as seller;
import '../../presentation/screens/seller/product_management_screen.dart'
    as seller;
import '../../presentation/screens/seller/order_management_screen.dart'
    as seller;
import '../../presentation/screens/seller/earnings_screen.dart' as seller;
import '../../presentation/screens/seller/seller_order_detail_screen.dart' as seller;
import '../../presentation/screens/seller/seller_track_order_screen.dart' as seller;
import '../../presentation/screens/seller/seller_onboarding_screen.dart' as seller;
import '../../presentation/screens/site/sites_management_screen.dart' as seller;
import '../../presentation/screens/site/site_detail_screen.dart' as seller;
import '../../presentation/screens/site/add_edit_site_screen.dart' as seller;
import '../../presentation/screens/site/add_material_screen.dart' as seller;
import '../../presentation/screens/site/add_staff_screen.dart' as seller;
import '../../presentation/screens/site/add_visit_screen.dart' as seller;
import '../../presentation/screens/site/add_document_screen.dart' as seller;
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

class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Ref ref) {
    _sub = ref.listen(authProvider, (previous, next) => notifyListeners());
  }

  late final ProviderSubscription<AsyncValue<AuthState>> _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefresh(ref);
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
        path: RouteNames.login,
        builder: (context, state) => const auth.LoginScreen(),
      ),
      GoRoute(
        path: RouteNames.register,
        builder: (context, state) => const auth.RegisterScreen(),
      ),
      GoRoute(
        path: RouteNames.otpVerification,
        builder: (context, state) =>
            auth.OtpVerificationScreen(phone: state.extra as String? ?? ''),
      ),
      GoRoute(
        path: RouteNames.forgotPassword,
        builder: (context, state) => const auth.ForgotPasswordScreen(),
      ),
      GoRoute(
        path: RouteNames.sellerDashboard,
        builder: (context, state) => const seller.SellerHomeShell(),
      ),
      GoRoute(
        path: RouteNames.home,
        redirect: (context, state) => RouteNames.sellerDashboard,
      ),
      GoRoute(
        path: RouteNames.addProduct,
        builder: (context, state) => const seller.AddProductScreen(),
      ),
      GoRoute(
        path: RouteNames.editProduct,
        builder: (context, state) =>
            seller.AddProductScreen(productId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: RouteNames.productManagement,
        builder: (context, state) => const seller.ProductManagementScreen(),
      ),
      GoRoute(
        path: RouteNames.orderManagement,
        builder: (context, state) => const seller.OrderManagementScreen(),
      ),
      GoRoute(
        path: RouteNames.sellerOrderDetail,
        builder: (context, state) =>
            seller.SellerOrderDetailScreen(orderId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: RouteNames.trackOrder,
        builder: (context, state) =>
            seller.SellerTrackOrderScreen(orderId: state.pathParameters['orderId'] ?? ''),
      ),
      GoRoute(
        path: RouteNames.earnings,
        builder: (context, state) => const seller.EarningsScreen(),
      ),
      GoRoute(
        path: RouteNames.sellerOnboarding,
        builder: (context, state) => const seller.SellerOnboardingScreen(),
      ),
      GoRoute(
        path: RouteNames.sitesManagement,
        builder: (context, state) => const seller.SitesManagementScreen(),
      ),
      GoRoute(
        path: RouteNames.addSite,
        builder: (context, state) => const seller.AddEditSiteScreen(),
      ),
      GoRoute(
        path: RouteNames.editSite,
        builder: (context, state) =>
            seller.AddEditSiteScreen(siteId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: RouteNames.siteDetail,
        builder: (context, state) =>
            seller.SiteDetailScreen(siteId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: RouteNames.addSiteMaterial,
        builder: (context, state) =>
            seller.AddMaterialScreen(siteId: state.pathParameters['siteId'] ?? ''),
      ),
      GoRoute(
        path: RouteNames.addSiteStaff,
        builder: (context, state) =>
            seller.AddStaffScreen(siteId: state.pathParameters['siteId'] ?? ''),
      ),
      GoRoute(
        path: RouteNames.addSiteVisit,
        builder: (context, state) =>
            seller.AddVisitScreen(siteId: state.pathParameters['siteId'] ?? ''),
      ),
      GoRoute(
        path: RouteNames.addSiteDocument,
        builder: (context, state) =>
            seller.AddDocumentScreen(siteId: state.pathParameters['siteId'] ?? ''),
      ),
      GoRoute(
        path: RouteNames.notifications,
        builder: (context, state) => const shared.NotificationsScreen(),
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
    ],
    redirect: (context, state) {
      final authAsync = ref.read(authProvider);
      final authState = authAsync.asData?.value;
      final loading = authAsync.isLoading && authAsync.asData == null;
      final loc = state.matchedLocation;
      final isAuth = loc.startsWith('/login') ||
          loc.startsWith('/register') ||
          loc.startsWith('/otp') ||
          loc.startsWith('/forgot');

      if (loading && !isAuth && loc != RouteNames.splash) {
        return RouteNames.login;
      }

      if (authState is AuthAuthenticated) {
        if (!AuthRoleGuard.isAllowed(authState.user) && !isAuth) {
          return RouteNames.login;
        }
        if (isAuth) return RouteNames.sellerDashboard;
      }

      if (authState is AuthUnauthenticated &&
          !isAuth &&
          loc != RouteNames.splash) {
        return RouteNames.login;
      }

      if (loc == RouteNames.splash) {
        if (loading) return null;
        if (authState is AuthAuthenticated &&
            AuthRoleGuard.isAllowed(authState.user)) {
          return RouteNames.sellerDashboard;
        }
        return RouteNames.login;
      }

      // Wallet removed – redirect to dashboard
      if (loc == RouteNames.wallet) {
        return RouteNames.sellerDashboard;
      }

      return null;
    },
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Page not found'),
            if (kDebugMode) Text(state.uri.toString()),
            ElevatedButton(
              onPressed: () => context.go(RouteNames.sellerDashboard),
              child: const Text('Dashboard'),
            ),
          ],
        ),
      ),
    ),
  );
});
