// lib/core/listeners/auth_listener.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sitedrop_core/core/utils/app_logger.dart';
import 'package:sitedrop_core/data/services/notification_service.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../presentation/providers/cart_provider.dart';
import '../../presentation/providers/session_bootstrap_provider.dart';
import '../../presentation/providers/wishlist_provider.dart';

class AuthListener {
  static void setup(WidgetRef ref) {
    ref.listen<AsyncValue<AuthState>>(authProvider, (previous, next) {
      if (next is AsyncData && next.value is AuthAuthenticated) {
        final wasUnauthenticated =
            previous != null &&
            previous is AsyncData &&
            previous.value is AuthUnauthenticated;

        // Cold start (previous null) or fresh login — join SessionBootstrap.
        // AuthNotifier also schedules it; run() is idempotent / coalesced.
        if (wasUnauthenticated || previous == null) {
          final user = (next.value as AuthAuthenticated).user;
          AppLogger.d(
            '🔄 Auth → authenticated — joining SessionBootstrap (deduped)',
          );
          ref.read(sessionBootstrapProvider).run(
                force: wasUnauthenticated,
                userKey: user.id,
              );
        }
      }

      if (next is AsyncData && next.value is AuthUnauthenticated) {
        AppLogger.d('🔄 Auth → unauthenticated — clearing session caches');
        ref.read(sessionBootstrapProvider).reset();
        NotificationService.clearRegistrationCache();
        ref.read(cartProvider.notifier).clearCart();
        ref.invalidate(wishlistProvider);
      }
    });
  }
}
