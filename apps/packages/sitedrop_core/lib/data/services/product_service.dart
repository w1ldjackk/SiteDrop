import '../../core/utils/app_logger.dart';
// lib/data/services/product_service.dart
import '../../core/constants/api_constants.dart';
import '../models/product.dart';
import '../models/review.dart';
import 'api_service.dart';

class ProductService {
  // ============================================================
  // GET PUBLIC PRODUCT LISTINGS (FOR BUYERS)
  // ============================================================
  static Future<List<ProductModel>> fetchProducts({
    String? category,
    String? search,
    String? sellerId,
    double? minPrice,
    double? maxPrice,
    String? sortBy = 'created_at',
    String? sortDirection = 'desc',
    int perPage = 20,
    int page = 1,
  }) async {
    final queryParams = <String, dynamic>{
      'per_page': perPage,
      'page': page,
      'sort_by': sortBy ?? 'created_at',
      'sort_direction': sortDirection ?? 'desc',
    };

    if (category != null && category.isNotEmpty) {
      queryParams['category'] = category;
    }
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }
    if (sellerId != null && sellerId.isNotEmpty) {
      queryParams['seller_id'] = sellerId;
    }
    if (minPrice != null) {
      queryParams['min_price'] = minPrice;
    }
    if (maxPrice != null) {
      queryParams['max_price'] = maxPrice;
    }

    final response = await ApiService.get<Map<String, dynamic>>(
      ApiConstants.productListings,
      queryParams: queryParams,
    );

    final data = response['data'] as Map<String, dynamic>? ?? {};
    final productsData = data['products'] as List<dynamic>? ?? [];

    return productsData
        .whereType<Map<String, dynamic>>()
        .map((item) => ProductModel.fromJson(item))
        .toList();
  }

  // ============================================================
  // GET SINGLE PRODUCT DETAILS
  // ============================================================
  static Future<ProductModel?> fetchProduct(String id) async {
    try {
      final response = await ApiService.get<Map<String, dynamic>>(
        ApiConstants.productDetail(id),
      );

      final data = response['data'] as Map<String, dynamic>?;
      if (data != null && data.isNotEmpty) {
        return ProductModel.fromJson(data);
      }
      return null;
    } catch (e) {
      AppLogger.e('Error fetching product $id: $e');
      return null;
    }
  }

  // ============================================================
  // GET FEATURED PRODUCTS - FIXED: Filter from listings
  // ============================================================
  static Future<List<ProductModel>> getFeaturedProducts({
    int limit = 10,
  }) async {
    try {
      // Fetch all products and filter featured ones
      final allProducts = await fetchProducts(perPage: 50);
      final featuredProducts = allProducts
          .where((p) => p.isFeatured)
          .take(limit)
          .toList();

      return featuredProducts;
    } catch (e) {
      AppLogger.e('Error fetching featured products: $e');
      return [];
    }
  }

  // ============================================================
  // SEARCH PRODUCTS
  // ============================================================
  static Future<List<ProductModel>> searchProducts(
    String query, {
    int perPage = 20,
  }) async {
    if (query.trim().isEmpty) {
      return fetchProducts(perPage: perPage);
    }

    return fetchProducts(search: query, perPage: perPage);
  }

  // ============================================================
  // GET PRODUCTS BY CATEGORY
  // ============================================================
  static Future<List<ProductModel>> getProductsByCategory(
    String category, {
    int perPage = 20,
  }) async {
    return fetchProducts(category: category, perPage: perPage);
  }

  // ============================================================
  // GET PRODUCTS BY SELLER (PUBLIC LISTINGS)
  // ============================================================
  static Future<List<ProductModel>> getProductsBySeller(
    String sellerId, {
    int perPage = 20,
    String? excludeProductId,
  }) async {
    if (sellerId.isEmpty) return [];
    final products = await fetchProducts(sellerId: sellerId, perPage: perPage);
    if (excludeProductId == null || excludeProductId.isEmpty) {
      return products;
    }
    return products.where((p) => p.id != excludeProductId).toList();
  }

  // ============================================================
  // GET PRODUCT CATEGORIES
  // ============================================================
  static Future<List<String>> getProductCategories() async {
    try {
      final response = await ApiService.get<Map<String, dynamic>>(
        ApiConstants.productCategories,
      );

      final data = response['data'] as Map<String, dynamic>? ?? {};
      final categories = data['categories'] as List<dynamic>? ?? [];

      return categories.map((e) => e.toString()).toList();
    } catch (e) {
      AppLogger.e('Error fetching categories: $e');
      // Return fallback categories
      return [
        'Sand',
        'Gravel',
        'Stones',
        'Quarry Materials',
        'Cement Blocks',
        'Cement',
        'Steel',
        'Lumber',
        'Paints',
        'Plumbing',
        'Electrical',
        'Tools',
        'Other',
      ];
    }
  }

  // ============================================================
  // GET SELLER'S PRODUCTS (FOR SELLER DASHBOARD)
  // ============================================================
  static Future<List<ProductModel>> fetchSellerProducts({
    int perPage = 20,
    int page = 1,
    String? status,
  }) async {
    final queryParams = <String, dynamic>{'per_page': perPage, 'page': page};

    if (status != null && status.isNotEmpty) {
      queryParams['status'] = status;
    }

    final response = await ApiService.get<Map<String, dynamic>>(
      ApiConstants.products,
      queryParams: queryParams,
    );

    final data = response['data'] as Map<String, dynamic>? ?? {};
    final productsData = data['products'] as List<dynamic>? ?? [];

    return productsData
        .whereType<Map<String, dynamic>>()
        .map((item) => ProductModel.fromJson(item))
        .toList();
  }

  // ============================================================
  // CREATE PRODUCT (SELLER)
  // ============================================================
  static Future<ProductModel?> createProduct(
    Map<String, dynamic> productData,
  ) async {
    try {
      final response = await ApiService.post<Map<String, dynamic>>(
        ApiConstants.products,
        data: productData,
      );

      final data = response['data'] as Map<String, dynamic>?;
      if (data != null && data.isNotEmpty) {
        final product = data['product'] as Map<String, dynamic>?;
        if (product != null) {
          return ProductModel.fromJson(product);
        }
      }
      return null;
    } catch (e) {
      AppLogger.e('Error creating product: $e');
      rethrow;
    }
  }

  // ============================================================
  // UPDATE PRODUCT (SELLER)
  // ============================================================
  static Future<ProductModel?> updateProduct(
    String id,
    Map<String, dynamic> productData,
  ) async {
    try {
      final response = await ApiService.put<Map<String, dynamic>>(
        ApiConstants.productDetail(id),
        data: productData,
      );

      final data = response['data'] as Map<String, dynamic>?;
      if (data != null && data.isNotEmpty) {
        final product = data['product'] as Map<String, dynamic>?;
        if (product != null) {
          return ProductModel.fromJson(product);
        }
      }
      return null;
    } catch (e) {
      AppLogger.e('Error updating product $id: $e');
      rethrow;
    }
  }

  // ============================================================
  // DELETE PRODUCT (SELLER)
  // ============================================================
  static Future<bool> deleteProduct(String id) async {
    try {
      await ApiService.delete<Map<String, dynamic>>(
        ApiConstants.productDetail(id),
      );
      return true;
    } catch (e) {
      AppLogger.e('Error deleting product $id: $e');
      return false;
    }
  }

  // ============================================================
  // TOGGLE PRODUCT AVAILABILITY (SELLER)
  // ============================================================
  static Future<bool> toggleProductAvailability(String id) async {
    try {
      final response = await ApiService.post<Map<String, dynamic>>(
        ApiConstants.productToggleAvailability(id),
      );
      final data = response['data'] as Map<String, dynamic>?;
      return data?['is_available'] as bool? ?? false;
    } catch (e) {
      AppLogger.e('Error toggling product availability $id: $e');
      return false;
    }
  }

  // ============================================================
  // GET PRODUCT REVIEWS
  // ============================================================
  static Future<({List<ReviewModel> reviews, ReviewSummary summary})>
      getProductReviews(
    String productId, {
    int perPage = 20,
    int page = 1,
  }) async {
    final response = await ApiService.get<Map<String, dynamic>>(
      ApiConstants.productReviews(productId),
      queryParams: {
        'per_page': perPage,
        'page': page,
      },
    );

    final data = response['data'] as Map<String, dynamic>? ?? {};
    final raw = data['reviews'] as List<dynamic>? ?? [];
    final reviews = raw
        .whereType<Map>()
        .map((e) => ReviewModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final summary = ReviewSummary.fromJson(
      data['summary'] is Map
          ? Map<String, dynamic>.from(data['summary'] as Map)
          : null,
    );

    return (reviews: reviews, summary: summary);
  }

  /// Submit or update the current user's product review.
  static Future<ReviewModel> submitProductReview(
    String productId, {
    required int rating,
    String? comment,
    String? orderId,
  }) async {
    final body = <String, dynamic>{
      'rating': rating,
      if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
      if (orderId != null && orderId.isNotEmpty) 'order_id': orderId,
    };

    final response = await ApiService.post<Map<String, dynamic>>(
      ApiConstants.productReviews(productId),
      data: body,
    );

    final data = response['data'] as Map<String, dynamic>? ?? {};
    final reviewJson = data['review'] as Map<String, dynamic>?;
    if (reviewJson == null) {
      throw Exception(response['message']?.toString() ?? 'Could not save review');
    }
    return ReviewModel.fromJson(reviewJson);
  }

  // ============================================================
  // GET RELATED PRODUCTS
  // ============================================================
  static Future<List<ProductModel>> getRelatedProducts(
    String productId, {
    int limit = 4,
  }) async {
    try {
      final response = await ApiService.get<Map<String, dynamic>>(
        '${ApiConstants.productDetail(productId)}/related',
        queryParams: {'limit': limit},
      );

      final data = response['data'] as Map<String, dynamic>? ?? {};
      final productsData = data['products'] as List<dynamic>? ?? [];

      return productsData
          .whereType<Map<String, dynamic>>()
          .map((item) => ProductModel.fromJson(item))
          .toList();
    } catch (e) {
      AppLogger.e('Error fetching related products: $e');
      return [];
    }
  }

  // ============================================================
  // GET PRODUCT STATISTICS (SELLER)
  // ============================================================
  static Future<Map<String, dynamic>> getProductStats(String productId) async {
    try {
      final response = await ApiService.get<Map<String, dynamic>>(
        '${ApiConstants.productDetail(productId)}/stats',
      );

      return response['data'] as Map<String, dynamic>? ?? {};
    } catch (e) {
      AppLogger.e('Error fetching product stats: $e');
      return {};
    }
  }
}
