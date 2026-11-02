import 'package:sitedrop_core/core/utils/app_logger.dart';
// lib/data/repositories/cart_repository.dart
import 'package:sitedrop_core/data/models/cart_item.dart';
import 'package:sitedrop_core/data/services/cart_service.dart';
import 'package:sitedrop_core/data/services/storage_service.dart';

class CartRepository {
  static const String _cartCacheKey = 'cached_cart';

  // Get cart from server or cache
  static Future<List<CartItemModel>> getCart({
    bool forceRefresh = false,
  }) async {
    try {
      // Try to get from server
      final serverItems = await CartService.getCart();

      // Cache the result
      await _cacheCart(serverItems);

      return serverItems;
    } catch (e) {
      AppLogger.e('⚠️ Failed to fetch cart from server: $e');

      // If forceRefresh is true, don't use cache
      if (forceRefresh) {
        return [];
      }

      // Fallback to cached cart
      return _getCachedCart();
    }
  }

  // Get cached cart from local storage
  static Future<List<CartItemModel>> _getCachedCart() async {
    try {
      final cached = await StorageService.readSecure(_cartCacheKey);
      if (cached != null && cached.isNotEmpty) {
        // For now, return empty list - implement proper JSON serialization later
        return [];
      }
    } catch (e) {
      AppLogger.e('⚠️ Failed to get cached cart: $e');
    }
    return [];
  }

  // Cache cart to local storage
  static Future<void> _cacheCart(List<CartItemModel> items) async {
    try {
      // Store the count as a simple string for now
      await StorageService.saveSecure(_cartCacheKey, items.length.toString());
    } catch (e) {
      AppLogger.e('⚠️ Failed to cache cart: $e');
    }
  }

  // Add item to cart
  static Future<Map<String, dynamic>> addToCart({
    required String productId,
    required int quantity,
    Map<String, dynamic>? variations,
  }) async {
    final response = await CartService.addToCart(
      productId: productId,
      quantity: quantity,
      variations: variations,
    );

    // Refresh cache after adding
    await getCart(forceRefresh: true);

    return response;
  }

  // Update cart item quantity
  static Future<Map<String, dynamic>> updateQuantity({
    required String itemId,
    required int quantity,
  }) async {
    final response = await CartService.updateQuantity(
      itemId: itemId,
      quantity: quantity,
    );

    // Refresh cache after update
    await getCart(forceRefresh: true);

    return response;
  }

  // Remove item from cart
  static Future<Map<String, dynamic>> removeItem(String itemId) async {
    final response = await CartService.removeItem(itemId);

    // Refresh cache after removal
    await getCart(forceRefresh: true);

    return response;
  }

  // Clear cart
  static Future<Map<String, dynamic>> clearCart() async {
    final response = await CartService.clearCart();

    // Clear cache
    await StorageService.deleteSecure(_cartCacheKey);

    return response;
  }

  // Get cart summary
  static Future<Map<String, dynamic>> getCartSummary() async {
    return CartService.getCartSummary();
  }

  // Check if cart has items
  static Future<bool> hasItems() async {
    final items = await getCart();
    return items.isNotEmpty;
  }

  // Get total item count
  static Future<int> getItemCount() async {
    final items = await getCart();
    int count = 0;
    for (var item in items) {
      count += item.quantity;
    }
    return count;
  }

  // Get subtotal
  static Future<double> getSubtotal() async {
    final items = await getCart();
    double total = 0.0;
    for (var item in items) {
      total += item.lineTotal;
    }
    return total;
  }
}
