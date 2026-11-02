// lib/presentation/screens/shared/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'package:sitedrop_core/app/routes/route_names.dart';
import 'package:sitedrop_core/app/theme/app_palette.dart';
import 'package:sitedrop_core/config/auth_role_guard.dart';
import 'package:sitedrop_core/data/services/startup_permissions.dart';
import '../../../gen/assets.gen.dart';
import '../../providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(milliseconds: 1200));

    if (!mounted) return;

    // Ensure session is resolved (token restore if any).
    final authAsync = ref.read(authProvider);
    if (authAsync.isLoading || authAsync.asData == null) {
      await ref.read(authProvider.notifier).checkAuth();
    }

    if (!mounted) return;

    final authState = ref.read(authProvider).asData?.value;

    // Ask-once first-launch gate: notifications only.
    // Seller doesn't use device GPS, so location is skipped here.
    // No-ops after the first run; never blocks navigation.
    await StartupPermissions.ensureAskedOnce(
      requestLocation: false,
      requestNotifications: true,
    );

    if (!mounted) return;

    final destination = _startDestination(authState);

    if (mounted) {
      context.go(destination);
    }
  }

  /// Sellers stay in; anything else (buyer/driver) → sign in.
  /// (Role is enforced at login/restore; this is a second layer.)
  String _startDestination(AuthState? authState) {
    if (authState is AuthAuthenticated &&
        AuthRoleGuard.isAllowed(authState.user)) {
      return RouteNames.sellerDashboard;
    }

    return RouteNames.login;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              Assets.icons.logo,
              width: 96,
              height: 96,
            ),
            const SizedBox(height: 24),
            Text(
              'SiteDrop',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: p.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Starting…',
              style: TextStyle(fontSize: 14, color: p.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
