// lib/presentation/providers/main_tab_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bottom-nav tab index for the main buyer shell (HomeScreen).
/// 0 Home · 1 Categories · 2 Cart · 3 Wishlist · 4 Account
final mainTabIndexProvider =
    NotifierProvider<MainTabIndexNotifier, int>(MainTabIndexNotifier.new);

class MainTabIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setIndex(int index) {
    state = index.clamp(0, 4);
  }
}
