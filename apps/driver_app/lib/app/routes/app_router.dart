// Driver router — auth required; home = DriverHomeShell
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sitedrop_core/app/routes/route_names.dart';
import 'package:sitedrop_core/config/auth_role_guard.dart';
import 'package:sitedrop_core/data/models/truck.dart';

import '../../presentation/providers/auth_provider.dart';
import '../../presentation/screens/shared/splash_screen.dart' as shared;
import '../../presentation/screens/shared/notifications_screen.dart' as shared;
import '../../presentation/screens/shared/wallet_screen.dart' as shared;
import '../../presentation/screens/auth/login_screen.dart' as auth;
import '../../presentation/screens/auth/register_screen.dart' as auth;
import '../../presentation/screens/auth/otp_verification_screen.dart' as auth;
import '../../presentation/screens/auth/forgot_password_screen.dart' as auth;
import '../../presentation/screens/driver/driver_home_shell.dart' as driver;
import '../../presentation/screens/driver/delivery_assignment_screen.dart'
    as driver;
import '../../presentation/screens/driver/delivery_tracking_screen.dart'
    as driver;
import '../../presentation/screens/driver/driver_earnings_screen.dart'
    as driver;
import '../../presentation/screens/driver/my_trucks_screen.dart'
    as driver;
import '../../presentation/screens/driver/truck_detail_screen.dart'
    as driver;
import '../../presentation/screens/driver/truck_setup_screen.dart'
    as driver;
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
        path: RouteNames.driverDashboard,
        builder: (context, state) => const driver.DriverHomeShell(),
      ),
      GoRoute(
        path: RouteNames.home,
        redirect: (context, state) => RouteNames.driverDashboard,
      ),
      GoRoute(
        path: RouteNames.deliveryAssignments,
        builder: (context, state) => const driver.DeliveryAssignmentScreen(),
      ),
      GoRoute(
        path: RouteNames.driverEarnings,
        builder: (context, state) => const driver.DriverEarningsScreen(),
      ),
      GoRoute(
        path: RouteNames.driverTruckSetup,
        builder: (context, state) {
          final truck = state.extra is TruckModel
              ? state.extra as TruckModel
              : null;
          return driver.TruckSetupScreen(truck: truck);
        },
      ),
      GoRoute(
        path: RouteNames.driverTrucks,
        builder: (context, state) => const driver.MyTrucksScreen(),
      ),
      GoRoute(
        path: RouteNames.driverTruckDetail,
        builder: (context, state) {
          final truck = state.extra is TruckModel
              ? state.extra as TruckModel
              : null;
          if (truck == null) {
            return const driver.MyTrucksScreen();
          }
          return driver.TruckDetailScreen(truck: truck);
        },
      ),
      GoRoute(
        path: RouteNames.deliveryTracking,
        builder: (context, state) => driver.DeliveryTrackingScreen(
          deliveryId: state.pathParameters['id'] ?? '',
        ),
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
        if (isAuth) return RouteNames.driverDashboard;
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
          return RouteNames.driverDashboard;
        }
        return RouteNames.login;
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
              onPressed: () => context.go(RouteNames.driverDashboard),
              child: const Text('Home'),
            ),
          ],
        ),
      ),
    ),
  );
});
