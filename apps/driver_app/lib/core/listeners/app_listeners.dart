// lib/core/listeners/app_listeners.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_listener.dart';
import 'push_listener.dart';

class AppListeners {
  static void setup(WidgetRef ref) {
    // Setup all listeners
    AuthListener.setup(ref);
    PushListener.setup(ref);
  }
}
