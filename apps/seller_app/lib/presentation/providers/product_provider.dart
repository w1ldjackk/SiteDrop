// lib/presentation/providers/product_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sitedrop_core/data/models/product.dart';
import 'package:sitedrop_core/data/models/review.dart';
import 'package:sitedrop_core/data/services/product_service.dart';

/// Shared product listings for home (keeps one network call for list + featured).
final productListingsProvider = FutureProvider<List<ProductModel>>((ref) {
  return ProductService.fetchProducts(perPage: 50);
});

// Products list provider — shares [productListingsProvider] (no second GET).
final productsProvider = FutureProvider.autoDispose<List<ProductModel>>((ref) {
  return ref.watch(productListingsProvider.future);
});

// Products by category provider
final productsByCategoryProvider = FutureProvider.autoDispose
    .family<List<ProductModel>, String>((ref, category) {
      return ProductService.getProductsByCategory(category);
    });

// Featured products — filter shared listings (no second /products/listings call).
final featuredProductsProvider = FutureProvider.autoDispose<List<ProductModel>>(
  (ref) async {
    final all = await ref.watch(productListingsProvider.future);
    return all.where((p) => p.isFeatured).take(10).toList();
  },
);

// Product details provider
final productDetailsProvider = FutureProvider.autoDispose
    .family<ProductModel?, String>((ref, productId) {
      return ProductService.fetchProduct(productId);
    });

// Search products provider
final searchProductsProvider = FutureProvider.autoDispose
    .family<List<ProductModel>, String>((ref, query) {
      if (query.isEmpty) {
        return ProductService.fetchProducts();
      }
      return ProductService.searchProducts(query);
    });

// Seller's own products (authenticated seller dashboard)
final sellerProductsProvider = FutureProvider.autoDispose<List<ProductModel>>((
  ref,
) {
  return ProductService.fetchSellerProducts();
});

/// Public products for a given seller id (buyer product detail "More from seller").
/// [sellerId] may be `sellerId` or `sellerId|excludeProductId`.
final productsBySellerProvider = FutureProvider.autoDispose
    .family<List<ProductModel>, String>((ref, key) {
  final parts = key.split('|');
  final sellerId = parts.isNotEmpty ? parts[0] : '';
  final excludeId = parts.length > 1 ? parts[1] : null;
  return ProductService.getProductsBySeller(
    sellerId,
    excludeProductId: excludeId,
    perPage: 20,
  );
});

/// Published reviews for a product (list + summary).
final productReviewsProvider = FutureProvider.autoDispose
    .family<({List<ReviewModel> reviews, ReviewSummary summary}), String>((
  ref,
  productId,
) async {
  return ProductService.getProductReviews(productId);
});
