// Seller session bootstrap: notifications + theme + FCM (no cart/wishlist)
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sitedrop_core/core/utils/app_logger.dart';
import 'package:sitedrop_core/data/services/notification_service.dart';
import 'package:sitedrop_core/data/services/storage_service.dart';

import 'notification_provider.dart';
import 'theme_provider.dart';

final sessionBootstrapProvider = Provider<SessionBootstrapController>((ref) {
  return SessionBootstrapController(ref);
});

class SessionBootstrapController {
  SessionBootstrapController(this._ref);
  final Ref _ref;
  String? _bootstrappedUserKey;
  Future<void>? _inFlight;

  Future<void> run({bool force = false, String? userKey}) async {
    final token = await StorageService.getAuthToken();
    if (token == null || token.isEmpty) return;
    final key = (userKey != null && userKey.isNotEmpty) ? userKey : 'session';
    if (!force && _bootstrappedUserKey == key && _inFlight == null) return;
    if (_inFlight != null) {
      await _inFlight;
      if (!force || _bootstrappedUserKey == key) return;
    }
    _inFlight = _bootstrap(key);
    try {
      await _inFlight;
      _bootstrappedUserKey = key;
    } finally {
      _inFlight = null;
    }
  }

  Future<void> _bootstrap(String userKey) async {
    AppLogger.i('🚀 Seller SessionBootstrap for $userKey');
    await Future.wait<void>([
      _safe('notifications', () => _ref.read(notificationsProvider.notifier).refresh()),
      _safe('theme', () => _ref.read(themeModeProvider.notifier).syncFromServer()),
      _safe('fcm', () => NotificationService.syncTokenWithBackend()),
    ]);
    AppLogger.i('✅ Seller SessionBootstrap complete');
  }

  Future<void> _safe(String label, Future<void> Function() fn) async {
    try {
      await fn();
    } catch (e) {
      AppLogger.w('SessionBootstrap[$label]: $e');
    }
  }

  void reset() {
    _bootstrappedUserKey = null;
    _inFlight = null;
  }
}
