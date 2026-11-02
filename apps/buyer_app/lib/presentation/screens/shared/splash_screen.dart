// lib/presentation/screens/shared/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'package:sitedrop_core/app/routes/route_names.dart';
import 'package:sitedrop_core/app/theme/app_palette.dart';
import 'package:sitedrop_core/data/services/startup_permissions.dart';
import '../../../core/utils/biometric_helper.dart';
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
    // Buyer doesn't use device GPS, so location is skipped here
    // (requesting it would risk a store-policy rejection).
    // No-ops after the first run; never blocks navigation.
    await StartupPermissions.ensureAskedOnce(
      requestLocation: false,
      requestNotifications: true,
    );

    if (!mounted) return;

    // Biometric launch gate (Settings → Security). Guests never gated.
    if (authState is AuthAuthenticated &&
        await BiometricHelper.localEnabled() &&
        await BiometricHelper.isAvailable()) {
      final ok = await BiometricHelper.authenticate();
      if (!ok) {
        // Fail closed → sign-in screen (no partial session).
        if (mounted) context.go(RouteNames.login);
        return;
      }
      if (!mounted) return;
    }

    final destination = _startDestination(authState);

    if (mounted) {
      context.go(destination);
    }
  }

  /// Buyers and guests land on the marketplace.
  /// (Wrong-role sessions are cleared during restore, so anything else is
  /// treated as guest — never a cross-app dashboard route.)
  String _startDestination(AuthState? authState) {
    return RouteNames.home;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        child: Center(
          child: Semantics(
            label: 'Loading SiteDrop',
            liveRegion: true,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset(
                  Assets.icons.logo,
                  width: 96,
                  height: 96,
                  semanticsLabel: 'SiteDrop logo',
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
                const SizedBox(height: 16),
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                const SizedBox(height: 12),
                Text(
                  'Starting…',
                  style: TextStyle(fontSize: 14, color: p.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
