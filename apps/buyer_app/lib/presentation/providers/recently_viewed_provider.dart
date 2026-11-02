// lib/presentation/providers/recently_viewed_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sitedrop_core/data/models/product.dart';
import 'package:sitedrop_core/data/services/product_service.dart';
import 'package:sitedrop_core/data/services/storage_service.dart';

const _kRecentlyViewedKey = 'recently_viewed_product_ids';
const _kMaxRecentlyViewed = 20;

/// Recently viewed products (most recent first). Keeps full models in memory
/// so the product-detail UI can render immediately without a network race.
final recentlyViewedProvider =
    NotifierProvider<RecentlyViewedNotifier, List<ProductModel>>(
  RecentlyViewedNotifier.new,
);

/// Backward-compatible ID list (for any callers that only need IDs).
final recentlyViewedIdsProvider = Provider<List<String>>((ref) {
  return ref.watch(recentlyViewedProvider).map((p) => p.id).toList();
});

class RecentlyViewedNotifier extends Notifier<List<ProductModel>> {
  bool _hydrated = false;

  @override
  List<ProductModel> build() {
    Future.microtask(_hydrate);
    return const [];
  }

  Future<void> _hydrate() async {
    if (_hydrated) return;
    _hydrated = true;

    final raw = await StorageService.readPref(_kRecentlyViewedKey);
    if (raw is! List || raw.isEmpty) return;

    final ids = raw
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toList();
    if (ids.isEmpty) return;

    // Merge with anything tracked before hydrate finished.
    final existingById = {for (final p in state) p.id: p};
    final resolved = <ProductModel>[];

    try {
      final all = await ProductService.fetchProducts(perPage: 50);
      final byId = {for (final p in all) p.id: p};
      for (final id in ids) {
        if (existingById.containsKey(id)) {
          resolved.add(existingById[id]!);
          continue;
        }
        final hit = byId[id];
        if (hit != null) {
          resolved.add(hit);
          continue;
        }
        final fetched = await ProductService.fetchProduct(id);
        if (fetched != null) resolved.add(fetched);
      }
    } catch (_) {
      // Keep whatever is already in state.
      return;
    }

    // Prefer live tracked order first, then hydrated.
    final merged = <ProductModel>[
      ...state,
      ...resolved.where((p) => !state.any((s) => s.id == p.id)),
    ];
    if (merged.length > _kMaxRecentlyViewed) {
      merged.removeRange(_kMaxRecentlyViewed, merged.length);
    }
    state = merged;
  }

  Future<void> track(ProductModel product) async {
    if (product.id.isEmpty) return;

    final next = <ProductModel>[
      product,
      ...state.where((p) => p.id != product.id),
    ];
    if (next.length > _kMaxRecentlyViewed) {
      next.removeRange(_kMaxRecentlyViewed, next.length);
    }
    state = next;

    final ids = next.map((p) => p.id).toList();
    await StorageService.savePref(_kRecentlyViewedKey, ids);
  }

  List<ProductModel> excluding(String? productId) {
    if (productId == null || productId.isEmpty) return state;
    return state.where((p) => p.id != productId).toList();
  }
}

/// Resolved list for a screen, optionally excluding the product currently open.
final recentlyViewedProductsProvider = Provider.autoDispose
    .family<List<ProductModel>, String?>((ref, excludeProductId) {
  final items = ref.watch(recentlyViewedProvider);
  if (excludeProductId == null || excludeProductId.isEmpty) {
    return items;
  }
  return items.where((p) => p.id != excludeProductId).toList();
});
