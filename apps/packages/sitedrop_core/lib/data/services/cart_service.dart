import '../../core/utils/app_logger.dart';
// lib/data/services/cart_service.dart
import '../../core/constants/api_constants.dart';
import '../models/cart_item.dart';
import 'api_service.dart';

class CartService {
  // Get cart with items
  static Future<List<CartItemModel>> getCart() async {
    try {
      AppLogger.d('🛒 Fetching cart from API...');
      final response = await ApiService.get<Map<String, dynamic>>(
        ApiConstants.cart,
      );

      // API returns: { status: 'success', data: { cart: { ... } } }
      final data = response['data'] as Map<String, dynamic>? ?? {};
      final cart = data['cart'] as Map<String, dynamic>? ?? {};
      final items = cart['items'] as List<dynamic>? ?? [];

      AppLogger.d('🛒 Cart items from API: ${items.length}');

      final cartItems = <CartItemModel>[];
      for (var item in items) {
        try {
          if (item is Map<String, dynamic>) {
            final cartItem = CartItemModel.fromJson(item);
            cartItems.add(cartItem);
            AppLogger.i('✅ Parsed: ${cartItem.product.name} - ${cartItem.quantity}');
          }
        } catch (e) {
          AppLogger.e('❌ Error parsing cart item: $e');
        }
      }

      AppLogger.i('✅ Total parsed cart items: ${cartItems.length}');
      return cartItems;
    } catch (e) {
      AppLogger.e('❌ Error fetching cart: $e');
      return [];
    }
  }

  // Get full cart summary
  static Future<Map<String, dynamic>> getCartSummary() async {
    try {
      final response = await ApiService.get<Map<String, dynamic>>(
        ApiConstants.cart,
      );
      final data = response['data'] as Map<String, dynamic>? ?? {};
      return data['cart'] as Map<String, dynamic>? ?? {};
    } catch (e) {
      AppLogger.e('❌ Error fetching cart summary: $e');
      return {};
    }
  }

  // Add item to cart
  static Future<Map<String, dynamic>> addToCart({
    required String productId,
    required int quantity,
    Map<String, dynamic>? variations,
  }) async {
    final response = await ApiService.post<Map<String, dynamic>>(
      ApiConstants.cartAdd,
      data: {
        'product_id': productId,
        'quantity': quantity,
        'variations': ?variations,
      },
    );
    return response;
  }

  // Update cart item quantity
  static Future<Map<String, dynamic>> updateQuantity({
    required String itemId,
    required int quantity,
  }) async {
    final response = await ApiService.put<Map<String, dynamic>>(
      ApiConstants.cartItem(itemId),
      data: {'quantity': quantity},
    );
    return response;
  }

  // Remove item from cart
  static Future<Map<String, dynamic>> removeItem(String itemId) async {
    final response = await ApiService.delete<Map<String, dynamic>>(
      ApiConstants.cartItem(itemId),
    );
    return response;
  }

  // Clear cart
  static Future<Map<String, dynamic>> clearCart() async {
    final response = await ApiService.delete<Map<String, dynamic>>(
      ApiConstants.cartClear,
    );
    return response;
  }
}
