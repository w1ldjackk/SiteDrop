// Buyer bottom-nav tab index.
// 0 Home · 1 Categories · 2 Cart · 3 Wishlist · 4 Profile
import 'package:flutter_riverpod/flutter_riverpod.dart';

final buyerTabIndexProvider =
    NotifierProvider<BuyerTabIndexNotifier, int>(BuyerTabIndexNotifier.new);

class BuyerTabIndexNotifier extends Notifier<int> {
  static const int tabCount = 5;

  @override
  int build() => 0;

  void setIndex(int index) {
    state = index.clamp(0, tabCount - 1);
  }

  void goHome() => setIndex(0);
}
