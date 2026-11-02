// Lightweight session for buyer app (guest browse allowed).
// Replace with full auth_provider port from monolith when wiring login screens.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sitedrop_core/sitedrop_core.dart';

sealed class BuyerSession {
  const BuyerSession();
}

class BuyerGuest extends BuyerSession {
  const BuyerGuest();
}

class BuyerSignedIn extends BuyerSession {
  final User user;
  const BuyerSignedIn(this.user);
}

final buyerSessionProvider =
    NotifierProvider<BuyerSessionNotifier, BuyerSession>(
  BuyerSessionNotifier.new,
);

class BuyerSessionNotifier extends Notifier<BuyerSession> {
  @override
  BuyerSession build() {
    Future.microtask(_restore);
    return const BuyerGuest();
  }

  Future<void> _restore() async {
    try {
      final token = await StorageService.getAuthToken();
      if (token == null || token.isEmpty) {
        state = const BuyerGuest();
        return;
      }
      final user = await AuthService.getCurrentUser();
      // Buyer app: only buyer accounts may stay signed in.
      if (!AuthRoleGuard.isAllowed(user)) {
        await StorageService.clearAuthToken();
        state = const BuyerGuest();
        return;
      }
      state = BuyerSignedIn(user);
    } catch (_) {
      await StorageService.clearAuthToken();
      state = const BuyerGuest();
    }
  }

  bool get isSignedIn => state is BuyerSignedIn;

  Future<void> signInAs(User user) async {
    state = BuyerSignedIn(user);
  }

  Future<void> signOut() async {
    try {
      await AuthService.logout();
    } catch (_) {}
    await StorageService.clearAuthToken();
    state = const BuyerGuest();
  }
}
