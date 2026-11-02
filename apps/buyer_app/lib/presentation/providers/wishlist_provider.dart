// lib/presentation/providers/wishlist_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sitedrop_core/data/models/product.dart';
import 'package:sitedrop_core/data/services/storage_service.dart';
import 'package:sitedrop_core/data/services/wishlist_service.dart';

final wishlistProvider =
    AsyncNotifierProvider<WishlistNotifier, List<ProductModel>>(
  WishlistNotifier.new,
);

class WishlistNotifier extends AsyncNotifier<List<ProductModel>> {
  @override
  Future<List<ProductModel>> build() async {
    // Only hit API when a session token exists (avoids empty/errors on guest).
    final token = await StorageService.getAuthToken();
    if (token == null || token.isEmpty) {
      return const [];
    }
    try {
      return await WishlistService.fetchWishlist();
    } catch (_) {
      return const [];
    }
  }

  Future<void> refresh() async {
    final token = await StorageService.getAuthToken();
    if (token == null || token.isEmpty) {
      state = const AsyncData([]);
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(WishlistService.fetchWishlist);
  }

  bool isInWishlist(String productId) {
    final items = state.value ?? const [];
    return items.any((p) => p.id == productId);
  }

  Future<void> addToWishlist(ProductModel product) async {
    final current = state.value ?? const <ProductModel>[];
    if (current.any((p) => p.id == product.id)) return;

    // Optimistic update
    state = AsyncData([product, ...current]);
    try {
      await WishlistService.add(product.id);
    } catch (e) {
      state = AsyncData(current);
      rethrow;
    }
  }

  Future<void> removeFromWishlist(String productId) async {
    final current = state.value ?? const <ProductModel>[];
    final next = current.where((p) => p.id != productId).toList();
    state = AsyncData(next);
    try {
      await WishlistService.remove(productId);
    } catch (e) {
      state = AsyncData(current);
      rethrow;
    }
  }

  Future<bool> toggle(ProductModel product) async {
    final inList = isInWishlist(product.id);
    if (inList) {
      await removeFromWishlist(product.id);
      return false;
    }
    await addToWishlist(product);
    return true;
  }

  Future<void> clearWishlist() async {
    final current = state.value ?? const <ProductModel>[];
    state = const AsyncData([]);
    try {
      for (final p in current) {
        await WishlistService.remove(p.id);
      }
    } catch (e) {
      state = AsyncData(current);
      rethrow;
    }
  }
}

/// Convenience: current wishlist count (0 while loading/error).
final wishlistCountProvider = Provider<int>((ref) {
  return ref.watch(wishlistProvider).value?.length ?? 0;
});
