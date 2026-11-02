// lib/presentation/screens/buyer/wishlist_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sitedrop_core/app/routes/route_names.dart';
import 'package:sitedrop_core/app/theme/colors.dart';
import 'package:sitedrop_core/core/utils/helpers.dart';
import '../../providers/wishlist_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/recently_viewed_provider.dart';
import '../../widgets/buyer/product_card.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/responsive_scaffold_body.dart';

class WishlistScreen extends ConsumerStatefulWidget {
  const WishlistScreen({super.key});

  @override
  ConsumerState<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends ConsumerState<WishlistScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wishlistAsync = ref.watch(wishlistProvider);
    final productsAsync = ref.watch(productsProvider);
    final wishlist = wishlistAsync.value ?? const [];

    // Filter wishlist based on search query
    final filteredWishlist = _searchQuery.isEmpty
        ? wishlist
        : wishlist
              .where(
                (product) =>
                    product.name.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ) ||
                    product.category.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ),
              )
              .toList();

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        backgroundColor: context.palette.surface,
        elevation: 0,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Text(
            'Wishlist',
            style: TextStyle(
              color: context.palette.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
        ),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(72),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Container(
              decoration: BoxDecoration(
                color: context.palette.inputFill,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: context.palette.borderStrong,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(
                        fontSize: 16,
                        color: context.palette.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search your wishlist...',
                        hintStyle: TextStyle(
                          color: context.palette.textMuted,
                          fontSize: 15,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: context.palette.textMuted,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear,
                                  color: context.palette.textMuted,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _searchController.clear();
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 30,
                    color: context.palette.divider,
                  ),
                  IconButton(
                    onPressed: () {
                      Helpers.showInfoToast('Camera search coming soon!');
                    },
                    icon: Icon(
                      Icons.camera_alt_outlined,
                      color: AppColors.primary,
                      size: 26,
                    ),
                    style: IconButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: wishlistAsync.isLoading && wishlist.isEmpty
          ? const LoadingWidget(message: 'Loading wishlist…')
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  // Wishlist Section
                  if (wishlist.isEmpty)
                    _buildEmptyWishlist(context)
                  else
                    _buildWishlistItems(context, filteredWishlist, wishlist),

                  // Recently Viewed Section
                  _buildRecentlyViewed(context),

                  // Recommended Products Section (always visible)
                  _buildRecommendedProducts(context, productsAsync),
                ],
              ),
            ),
    );
  }

  // ============================================================
  // EMPTY WISHLIST
  // ============================================================
  Widget _buildEmptyWishlist(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: context.palette.surfaceMuted,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.favorite_outline,
              size: 50,
              color: context.palette.iconMuted,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Your Wishlist is Empty',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: context.palette.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Save your favorite items here',
            style: TextStyle(color: context.palette.textMuted, fontSize: 15),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 40,
            child: ElevatedButton(
              onPressed: () => context.go(RouteNames.home),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              child: Text('Start Shopping'),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ============================================================
  // WISHLIST ITEMS
  // ============================================================
  Widget _buildWishlistItems(
    BuildContext context,
    List filteredWishlist,
    List wishlist,
  ) {
    return Column(
      children: [
        // Wishlist count
        if (filteredWishlist.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    '${filteredWishlist.length} items',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.palette.textMuted,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  Flexible(
                    child: Text(
                      'Showing ${filteredWishlist.length} of ${wishlist.length}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        color: context.palette.iconMuted,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        // Wishlist Grid
        filteredWishlist.isEmpty
            ? Container(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_off,
                      size: 64,
                      color: context.palette.iconMuted,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No results found',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: context.palette.icon,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Try adjusting your search terms',
                      style: TextStyle(
                        color: context.palette.textMuted,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text('Clear Search'),
                    ),
                  ],
                ),
              )
            : GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: responsiveProductGridCount(context),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.7,
                ),
                itemCount: filteredWishlist.length,
                itemBuilder: (context, index) {
                  final product = filteredWishlist[index];
                  return Stack(
                    children: [
                      ProductCard(product: product, showAddToCart: true),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          decoration: BoxDecoration(
                            color: context.palette.surface,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.favorite,
                              color: AppColors.error,
                              size: 20,
                              semanticLabel: 'Remove ${product.name} from wishlist',
                            ),
                            tooltip: 'Remove from wishlist',
                            onPressed: () async {
                              try {
                                await ref
                                    .read(wishlistProvider.notifier)
                                    .removeFromWishlist(product.id);
                                Helpers.showSuccessToast('Removed from wishlist');
                              } catch (_) {
                                Helpers.showErrorToast(
                                  'Could not remove from wishlist',
                                );
                              }
                            },
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(
                              minWidth: 44,
                              minHeight: 44,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
        const SizedBox(height: 16),
      ],
    );
  }

  // ============================================================
  // RECENTLY VIEWED
  // ============================================================
  Widget _buildRecentlyViewed(BuildContext context) {
    final recentlyViewed = ref.watch(recentlyViewedProductsProvider(null));
    if (recentlyViewed.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recently Viewed',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: context.palette.textPrimary,
                  ),
                ),
                TextButton(
                  onPressed: () => context.go(RouteNames.products),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                  ),
                  child: Text(
                    'See All',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: recentlyViewed.length.clamp(0, 6),
              itemBuilder: (context, index) {
                final product = recentlyViewed[index];
                return Container(
                  width: 140,
                  margin: const EdgeInsets.only(right: 12),
                  child: ProductCard(product: product, showAddToCart: true),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // RECOMMENDED PRODUCTS
  // ============================================================
  Widget _buildRecommendedProducts(
    BuildContext context,
    AsyncValue<List> productsAsync,
  ) {
    return productsAsync.when(
      data: (products) {
        final shuffled = List.of(products)..shuffle();
        final recommended = shuffled.take(6).toList();

        if (recommended.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recommended for you',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: context.palette.textPrimary,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go(RouteNames.products),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                      ),
                      child: Text(
                        'See All',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 220,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: recommended.length,
                  itemBuilder: (context, index) {
                    final product = recommended[index];
                    return Container(
                      width: 140,
                      margin: const EdgeInsets.only(right: 12),
                      child: ProductCard(product: product, showAddToCart: true),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
      loading: () => Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recommended for you',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: context.palette.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            const SizedBox(height: 120, child: LoadingWidget.compact()),
          ],
        ),
      ),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }
}
