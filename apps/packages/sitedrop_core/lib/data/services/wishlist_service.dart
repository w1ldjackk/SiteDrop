// lib/data/services/wishlist_service.dart
import '../../core/constants/api_constants.dart';
import '../models/product.dart';
import 'api_service.dart';

class WishlistService {
  /// GET /wishlist
  static Future<List<ProductModel>> fetchWishlist() async {
    final response = await ApiService.get<Map<String, dynamic>>(
      ApiConstants.wishlist,
    );

    final data = response['data'] as Map<String, dynamic>? ?? {};
    final productsData = data['products'] as List<dynamic>? ?? [];

    return productsData
        .whereType<Map<String, dynamic>>()
        .map((item) => ProductModel.fromJson(item))
        .toList();
  }

  /// POST /wishlist/add
  static Future<Map<String, dynamic>> add(String productId) async {
    final response = await ApiService.post<Map<String, dynamic>>(
      ApiConstants.wishlistAdd,
      data: {'product_id': int.tryParse(productId) ?? productId},
    );
    return response['data'] as Map<String, dynamic>? ?? {};
  }

  /// POST /wishlist/remove  (also supports DELETE)
  static Future<Map<String, dynamic>> remove(String productId) async {
    final response = await ApiService.post<Map<String, dynamic>>(
      ApiConstants.wishlistRemove,
      data: {'product_id': int.tryParse(productId) ?? productId},
    );
    return response['data'] as Map<String, dynamic>? ?? {};
  }

  /// POST /wishlist/toggle
  static Future<Map<String, dynamic>> toggle(String productId) async {
    final response = await ApiService.post<Map<String, dynamic>>(
      ApiConstants.wishlistToggle,
      data: {'product_id': int.tryParse(productId) ?? productId},
    );
    return response['data'] as Map<String, dynamic>? ?? {};
  }

  /// GET /wishlist/check?product_id=
  static Future<bool> check(String productId) async {
    final response = await ApiService.get<Map<String, dynamic>>(
      ApiConstants.wishlistCheck,
      queryParams: {
        'product_id': int.tryParse(productId) ?? productId,
      },
    );
    final data = response['data'] as Map<String, dynamic>? ?? {};
    return data['in_wishlist'] == true;
  }
}
