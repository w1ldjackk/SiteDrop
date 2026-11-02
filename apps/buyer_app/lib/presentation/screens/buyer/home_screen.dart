// lib/presentation/screens/buyer/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sitedrop_core/app/routes/route_names.dart';
import 'package:sitedrop_core/app/theme/colors.dart';
import 'package:sitedrop_core/core/constants/app_constants.dart';
import '../../providers/product_provider.dart';
import '../../providers/main_tab_provider.dart';
import '../../providers/cart_provider.dart';
import '../../widgets/buyer/product_card.dart';
import '../../widgets/buyer/product_search_bar.dart';
import '../../widgets/common/buyer_bottom_nav.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/notification_bell_button.dart';
import '../../widgets/common/responsive_scaffold_body.dart';
import 'cart_screen.dart';
import 'categories_screen.dart';
import 'wishlist_screen.dart';
import '../profile/role_profile_screen.dart';

// ============================================================
// MAIN HOME SCREEN WITH BOTTOM NAVIGATION
// ============================================================
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    // Session data (cart/wishlist/notifications/FCM) is loaded once via
    // SessionBootstrap from auth — do not re-fetch here.
    _pages = [
      const HomeContent(),
      const CategoriesScreen(),
      const CartScreenWrapper(),
      const WishlistScreen(),
      const ProfileScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final selectedIndex = ref.watch(mainTabIndexProvider).clamp(0, 4);
    // Watch cart so the bottom nav badge rebuilds when items are added/removed.
    ref.watch(cartProvider);

    return Scaffold(
      backgroundColor: p.background,
      body: IndexedStack(
        index: selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BuyerBottomNav(embeddedInShell: true),
    );
  }
}

// ============================================================
// HOME CONTENT
// ============================================================
class HomeContent extends ConsumerWidget {
  const HomeContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final productsAsync = ref.watch(productsProvider);
    final featuredProductsAsync = ref.watch(featuredProductsProvider);

    // First paint / cold load — full-screen modern skeleton (global loader).
    final bootingHome = (productsAsync.isLoading && !productsAsync.hasValue) ||
        (featuredProductsAsync.isLoading && !featuredProductsAsync.hasValue);

    if (bootingHome) {
      return Scaffold(
        backgroundColor: p.background,
        body: const LoadingWidget(message: 'Loading home…'),
      );
    }

    return Scaffold(
      backgroundColor: p.background,
      body: Column(
        children: [
          // Sticky header
          Container(
            color: p.surface,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
              bottom: 4,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'SiteDrop',
                  style: TextStyle(
                    color: p.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
                const NotificationBellButton(
                  iconSize: 28,
                  useGo: true,
                ),
              ],
            ),
          ),

          // Search
          Container(
            color: p.background,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: ProductSearchBar(
              fillColor: p.inputFill,
              borderColor: p.inputBorder,
            ),
          ),

          // Categories chips
          Container(
            color: p.background,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: AppConstants.productCategories.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final category = AppConstants.productCategories[index];
                  return FilterChip(
                    label: Text(
                      category,
                      style: TextStyle(color: p.textSecondary, fontSize: 12),
                    ),
                    selected: false,
                    onSelected: (_) {
                      context.go(
                        '${RouteNames.products}?category=${Uri.encodeComponent(category)}',
                      );
                    },
                    backgroundColor: p.surface,
                    selectedColor: p.primarySoft,
                    side: BorderSide(color: p.borderStrong, width: 1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  );
                },
              ),
            ),
          ),

          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () => _handleRefresh(ref),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(context, 'Featured'),
                  const SizedBox(height: 12),
                  featuredProductsAsync.when(
                    data: (featuredProducts) {
                      if (featuredProducts.isEmpty) {
                        return productsAsync.when(
                          data: (products) {
                            final productsToShow = products.take(6).toList();
                            if (productsToShow.isEmpty) {
                              return _buildEmptyState(context);
                            }
                            return _buildCarousel(context, productsToShow);
                          },
                          loading: () => const SizedBox(
                            height: 200,
                            child: LoadingWidget.compact(),
                          ),
                          error: (error, stack) => _buildErrorState(
                            context: context,
                            onRetry: () =>
                                ref.invalidate(featuredProductsProvider),
                          ),
                        );
                      }
                      return _buildCarousel(context, featuredProducts);
                    },
                    loading: () => const SizedBox(
                      height: 200,
                      child: LoadingWidget.compact(),
                    ),
                    error: (error, stack) => _buildErrorState(
                      context: context,
                      onRetry: () => ref.invalidate(featuredProductsProvider),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSectionHeader(context, 'Popular Materials'),
                  const SizedBox(height: 12),
                  productsAsync.when(
                    data: (products) {
                      final featuredIds =
                          featuredProductsAsync.value
                              ?.map((p) => p.id)
                              .toSet() ??
                          {};
                      final regularProducts = products
                          .where((p) => !featuredIds.contains(p.id))
                          .take(6)
                          .toList();
                      if (regularProducts.isEmpty) {
                        return _buildEmptyState(context);
                      }
                      return _buildProductGrid(context, regularProducts);
                    },
                    loading: () => const SizedBox(
                      height: 220,
                      child: LoadingWidget.compact(),
                    ),
                    error: (error, stack) => _buildErrorState(
                      context: context,
                      onRetry: () => ref.invalidate(productsProvider),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ),
        ],
      ),
    );
  }

  /// Pull-to-refresh: re-fetch products + featured, awaiting fresh values so
  /// the indicator only completes once new data is in.
  Future<void> _handleRefresh(WidgetRef ref) async {
    ref.invalidate(productsProvider);
    ref.invalidate(featuredProductsProvider);
    await Future.wait([
      ref.read(productsProvider.future),
      ref.read(featuredProductsProvider.future),
    ]);
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final p = context.palette;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: p.textPrimary,
          ),
        ),
        TextButton(
          onPressed: () => context.go(RouteNames.products),
          style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          child: const Row(
            children: [
              Text(
                'See All',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              SizedBox(width: 4),
              Icon(CupertinoIcons.forward, size: 14, color: AppColors.primary),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCarousel(BuildContext context, List products) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    // Keep card readable on narrow phones; show more on tablets.
    final itemWidth = (screenWidth / (screenWidth >= 900
            ? 4.2
            : screenWidth >= 600
                ? 3.4
                : 2.8))
        .clamp(140.0, 220.0);
    const double itemHeight = 210;

    return SizedBox(
      height: itemHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: products.length,
        itemBuilder: (context, index) {
          return SizedBox(
            width: itemWidth,
            height: itemHeight,
            child: Padding(
              padding: const EdgeInsets.only(right: 10),
              child: ProductCard(
                product: products[index],
                showAddToCart: true,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductGrid(BuildContext context, List products) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: responsiveProductGridCount(context),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.7,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        return ProductCard(product: products[index], showAddToCart: true);
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: p.iconMuted),
          const SizedBox(height: 16),
          Text(
            'No products available',
            style: TextStyle(color: p.textMuted, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState({
    required BuildContext context,
    required VoidCallback onRetry,
  }) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.error_outline, size: 64, color: AppColors.error),
          const SizedBox(height: 16),
          Text(
            'Error loading products',
            style: TextStyle(color: p.textMuted, fontSize: 16),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            child: Text('Retry'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// CART SCREEN WRAPPER
// ============================================================
class CartScreenWrapper extends StatelessWidget {
  const CartScreenWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return const CartScreen();
  }
}
