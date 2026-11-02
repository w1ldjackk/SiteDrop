import 'package:sitedrop_core/core/utils/app_logger.dart';
// lib/presentation/providers/cart_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sitedrop_core/data/models/cart_item.dart';
import 'package:sitedrop_core/data/models/product.dart';
import '../../data/repositories/cart_repository.dart';
import 'package:sitedrop_core/data/services/storage_service.dart';
import 'auth_provider.dart';

final cartProvider = NotifierProvider<CartNotifier, List<CartItemModel>>(
  CartNotifier.new,
);

// Cart summary provider — only hits API when a session exists
final cartSummaryProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final token = await StorageService.getAuthToken();
  if (token == null || token.isEmpty) return {};
  return CartRepository.getCartSummary();
});

class CartNotifier extends Notifier<List<CartItemModel>> {
  bool _isInitialized = false;
  bool _isSyncing = false;
  Future<void>? _syncFuture;

  @override
  List<CartItemModel> build() {
    // Do not auto-fetch here — SessionBootstrap / ensureLoaded own init.
    // Avoids racing auth restore + home + listener + cart_screen.
    _isInitialized = false;
    // React to auth changes so the cart (and bottom-nav badge) refresh
    // promptly when a user signs in after browsing as a guest.
    ref.listen(authProvider, (prev, next) {
      final wasAuth = prev is AsyncData && prev.value is AuthAuthenticated;
      final isAuth = next is AsyncData && next.value is AuthAuthenticated;
      if (isAuth && !wasAuth) {
        _isInitialized = false;
        ensureLoaded();
      } else if (!isAuth && wasAuth) {
        state = const [];
        _isInitialized = false;
      }
    });
    return const [];
  }

  /// True when auth state is signed-in *and* a bearer token is present.
  Future<bool> _hasServerSession() async {
    final authState = ref.read(authProvider);
    final isAuthenticated =
        authState is AsyncData && authState.value is AuthAuthenticated;
    if (!isAuthenticated) return false;
    final token = await StorageService.getAuthToken();
    return token != null && token.isNotEmpty;
  }

  /// Load cart once if not already loaded (idempotent). Prefer this over [syncCart]
  /// for init paths; use [syncCart] for pull-to-refresh / mutations.
  Future<void> ensureLoaded() async {
    if (_isInitialized && !_isSyncing) return;
    await _syncWithServer();
  }

  // Initialize and sync cart
  Future<void> initialize() async {
    await ensureLoaded();
  }

  // Sync with server - uses repository (no-op for guests)
  Future<void> _syncWithServer() async {
    if (_syncFuture != null) {
      await _syncFuture;
      return;
    }
    if (!await _hasServerSession()) {
      AppLogger.d('ℹ️ Skipping cart sync — no auth session');
      return;
    }

    _isSyncing = true;
    AppLogger.d('🔄 Syncing cart with server...');

    _syncFuture = () async {
      try {
        final serverItems = await CartRepository.getCart();
        AppLogger.d('📦 Server returned ${serverItems.length} items');
        state = serverItems;
        _isInitialized = true;
      } catch (e) {
        AppLogger.e('❌ Error syncing cart: $e');
      } finally {
        _isSyncing = false;
        _syncFuture = null;
      }
    }();

    await _syncFuture;
  }

  void addProduct(ProductModel product, {int quantity = 1}) {
    AppLogger.d('➕ Adding product to cart: ${product.name} x $quantity');

    final index = state.indexWhere((item) => item.product.id == product.id);

    if (index >= 0) {
      final updated = [...state];
      final newQuantity = updated[index].quantity + quantity;
      final maxQty = updated[index].maxQuantity ?? 100;

      if (newQuantity > maxQty) {
        AppLogger.w('⚠️ Max quantity reached: $maxQty');
        return;
      }

      updated[index] = updated[index].copyWith(quantity: newQuantity);
      state = updated;

      if (updated[index].id != null) {
        _updateOnServer(updated[index].id!, newQuantity);
      }
      return;
    }

    final newItem = CartItemModel(
      product: product,
      quantity: quantity,
      price: product.price,
      productId: product.id,
      maxQuantity: product.maxQuantity,
      unit: product.unit,
      sellerId: product.sellerId,
      sellerName: product.sellerName,
    );
    state = [...state, newItem];
    _addToServer(product.id, quantity);
  }

  void updateQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      removeProduct(productId);
      return;
    }

    final item = state.firstWhere((item) => item.product.id == productId);
    final maxQty = item.maxQuantity ?? 100;

    if (quantity > maxQty) {
      AppLogger.w('⚠️ Max quantity reached: $maxQty');
      return;
    }

    AppLogger.d('🔄 Updating quantity for ${item.product.name}: $quantity');

    state = state
        .map(
          (item) => item.product.id == productId
              ? item.copyWith(quantity: quantity)
              : item,
        )
        .toList();

    if (item.id != null) {
      _updateOnServer(item.id!, quantity);
    }
  }

  void removeProduct(String productId) {
    final item = state.firstWhere((item) => item.product.id == productId);
    AppLogger.d('🗑️ Removing product from cart: ${item.product.name}');

    state = state.where((item) => item.product.id != productId).toList();

    if (item.id != null) {
      _removeFromServer(item.id!);
    }
  }

  void clearCart() {
    AppLogger.d('🗑️ Clearing all cart items');
    state = const [];
    _isInitialized = false;
    _clearOnServer();
  }

  double get subtotal => state.fold(0, (sum, item) => sum + item.lineTotal);

  int get itemCount => state.fold(0, (sum, item) => sum + item.quantity);

  // ============================================================
  // SERVER SYNC METHODS - Using repository
  // ============================================================
  Future<void> _addToServer(String productId, int quantity) async {
    if (!await _hasServerSession()) {
      AppLogger.d('ℹ️ Guest cart — keep local only (skip server add)');
      return;
    }
    try {
      AppLogger.d('📤 Adding to server: productId=$productId, quantity=$quantity');
      final response = await CartRepository.addToCart(
        productId: productId,
        quantity: quantity,
      );

      final data = response['data'] as Map<String, dynamic>? ?? {};
      final cart = data['cart'] as Map<String, dynamic>? ?? {};
      final items = cart['items'] as List<dynamic>? ?? [];

      // Update item IDs from server response
      for (var serverItem in items) {
        final item = serverItem as Map<String, dynamic>;
        final serverId = item['id']?.toString();
        final productIdFromServer = item['product_id']?.toString();

        if (serverId != null && productIdFromServer != null) {
          final index = state.indexWhere(
            (i) => i.product.id == productIdFromServer,
          );
          if (index >= 0) {
            AppLogger.i(
              '✅ Updated item ID: $serverId for product $productIdFromServer',
            );
            state = [
              ...state.sublist(0, index),
              state[index].copyWith(id: serverId),
              ...state.sublist(index + 1),
            ];
          }
        }
      }
    } catch (e) {
      AppLogger.e('❌ Error adding to cart on server: $e');
    }
  }

  Future<void> _updateOnServer(String itemId, int quantity) async {
    if (!await _hasServerSession()) return;
    try {
      AppLogger.d('📤 Updating on server: itemId=$itemId, quantity=$quantity');
      await CartRepository.updateQuantity(itemId: itemId, quantity: quantity);
      AppLogger.i('✅ Updated on server successfully');
    } catch (e) {
      AppLogger.e('❌ Error updating cart on server: $e');
    }
  }

  Future<void> _removeFromServer(String itemId) async {
    if (!await _hasServerSession()) return;
    try {
      AppLogger.d('📤 Removing from server: itemId=$itemId');
      await CartRepository.removeItem(itemId);
      AppLogger.i('✅ Removed from server successfully');
    } catch (e) {
      AppLogger.e('❌ Error removing from cart on server: $e');
    }
  }

  Future<void> _clearOnServer() async {
    if (!await _hasServerSession()) {
      AppLogger.d('ℹ️ User not authenticated, skipping server clear');
      return;
    }
    try {
      AppLogger.d('📤 Clearing cart on server');
      await CartRepository.clearCart();
      AppLogger.i('✅ Cleared on server successfully');
    } catch (e) {
      AppLogger.e('❌ Error clearing cart on server: $e');
    }
  }

  /// Force sync with server (pull-to-refresh / after mutations). No-op for guests.
  Future<void> syncCart() async {
    _isInitialized = false;
    await _syncWithServer();
  }
}
