// lib/data/services/connectivity_service.dart
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Wraps [connectivity_plus] for online/offline checks and stream updates.
class ConnectivityService {
  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  final _controller = StreamController<bool>.broadcast();

  /// Emits `true` when any network interface is available.
  Stream<bool> get onStatusChanged => _controller.stream;

  Future<bool> get isOnline async {
    final results = await _connectivity.checkConnectivity();
    return _hasConnection(results);
  }

  /// Start listening for connectivity changes.
  void start() {
    _subscription?.cancel();
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      if (!_controller.isClosed) {
        _controller.add(_hasConnection(results));
      }
    });
  }

  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }

  static bool _hasConnection(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return results.any((r) => r != ConnectivityResult.none);
  }
}
