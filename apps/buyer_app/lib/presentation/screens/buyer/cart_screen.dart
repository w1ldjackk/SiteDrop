import 'package:sitedrop_core/core/utils/app_logger.dart';
// lib/presentation/screens/buyer/cart_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sitedrop_core/app/routes/route_names.dart';
import 'package:sitedrop_core/app/theme/colors.dart';
import '../../../core/utils/auth_gate.dart';
import 'package:sitedrop_core/core/utils/helpers.dart';
import '../../providers/cart_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/recently_viewed_provider.dart';
import '../../widgets/cart/cart_card.dart';
import '../../widgets/buyer/product_card.dart';
import 'package:sitedrop_core/presentation/widgets/buttons/primary_button.dart';
import '../../widgets/common/buyer_bottom_nav.dart';
import '../../widgets/common/loading_widget.dart';

class CartScreen extends ConsumerStatefulWidget {
  /// When true (standalone `/cart` route), show bottom nav.
  /// Shell tab keeps this false — [HomeScreen] already has the bar.
  final bool showBottomNav;

  const CartScreen({super.key, this.showBottomNav = false});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeCart();
  }

  Future<void> _initializeCart() async {
    setState(() => _isLoading = true);
    try {
      // Idempotent: joins SessionBootstrap cart load if already in flight /
      // skips network when cart was already loaded this session.
      if (AuthGate.isAuthenticated(ref)) {
        await ref.read(cartProvider.notifier).ensureLoaded();
      }
    } catch (e) {
      AppLogger.e('❌ Error initializing cart: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ============================================================
  // SHOW CLEAR CART CONFIRMATION
  // ============================================================
  void _showClearCartDialog(BuildContext context, VoidCallback onClear) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 0,
        backgroundColor: context.palette.surface,
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.errorSurface,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.delete_outline,
                  color: AppColors.error,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              // Title
              Text(
                'Clear Cart?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: context.palette.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              // Content
              Text(
                'Are you sure you want to remove all items from your cart?',
                style: TextStyle(
                  fontSize: 15,
                  color: context.palette.textMuted,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.grey700,
                        side: BorderSide(color: context.palette.borderStrong),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        onClear();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: Text('Clear All'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartItems = ref.watch(cartProvider);
    final cartNotifier = ref.read(cartProvider.notifier);
    final productsAsync = ref.watch(productsProvider);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: context.palette.background,
        appBar: AppBar(
          backgroundColor: context.palette.surface,
          elevation: 0,
          titleSpacing: 0,
          title: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Text(
              'My Cart',
              style: TextStyle(
                color: context.palette.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
          ),
          centerTitle: false,
        ),
        body: const LoadingWidget(message: 'Loading cart…'),
        bottomNavigationBar:
            widget.showBottomNav ? const BuyerBottomNav() : null,
      );
    }

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        backgroundColor: context.palette.surface,
        elevation: 0,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Text(
            'My Cart',
            style: TextStyle(
              color: context.palette.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
        ),
        centerTitle: false,
        actions: [
          if (cartItems.isNotEmpty)
            TextButton(
              onPressed: () {
                _showClearCartDialog(context, () {
                  cartNotifier.clearCart();
                  Helpers.showSuccessToast('Cart cleared');
                });
              },
              style: TextButton.styleFrom(
                foregroundColor: AppColors.error,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: const Size(64, 48),
              ),
              child: Text(
                'Clear',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
        ],
      ),
      bottomNavigationBar:
          widget.showBottomNav ? const BuyerBottomNav() : null,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // Cart Items Section
            if (cartItems.isEmpty)
              _buildEmptyCart(context)
            else
              _buildCartItems(context, cartItems, cartNotifier),

            // Recently Viewed Section
            _buildRecentlyViewed(context),

            // Recommended Products Section (always visible)
            _buildRecommendedProducts(context, productsAsync, cartItems),

            // Related Products Section (visible when cart has items)
            if (cartItems.isNotEmpty)
              _buildRelatedProducts(context, productsAsync, cartItems),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY CART
  // ============================================================
  Widget _buildEmptyCart(BuildContext context) {
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
              Icons.shopping_cart_outlined,
              size: 50,
              color: context.palette.iconMuted,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Your cart is empty',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: context.palette.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Start shopping to add items',
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
                textStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: Text('Browse Products'),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ============================================================
  // CART ITEMS WITH SUMMARY
  // ============================================================
  Widget _buildCartItems(
    BuildContext context,
    List cartItems,
    dynamic cartNotifier,
  ) {
    // Calculate totals
    final subtotal = cartNotifier.subtotal;
    final itemCount = cartNotifier.itemCount;
    final deliveryFee = _calculateDeliveryFee(cartItems);
    final serviceFee = _calculateServiceFee(subtotal);
    final total = subtotal + deliveryFee + serviceFee;

    return Column(
      children: [
        // Cart Items List
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: cartItems.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: CartCard(item: cartItems[index]),
            );
          },
        ),
        // Cart Summary
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.palette.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Summary Details
              _buildSummaryRow('Subtotal', Helpers.formatPrice(subtotal)),
              const SizedBox(height: 8),
              _buildSummaryRow(
                'Delivery Fee',
                deliveryFee > 0 ? Helpers.formatPrice(deliveryFee) : 'Free',
                isDelivery: true,
              ),
              const SizedBox(height: 8),
              _buildSummaryRow(
                'Service Fee (10%)',
                Helpers.formatPrice(serviceFee),
                isService: true,
              ),
              Divider(color: context.palette.divider, height: 24, thickness: 1),
              // Total
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'Total',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: context.palette.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      Helpers.formatPrice(total),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Checkout Button
              PrimaryButton(
                onPressed: () async {
                  final ok = await AuthGate.require(
                    context,
                    ref,
                    action: 'proceed to checkout',
                  );
                  if (!ok || !context.mounted) return;
                  context.go(RouteNames.checkout);
                },
                text: 'Proceed to Checkout',
                height: 52,
                fontSize: 16,
              ),
              const SizedBox(height: 8),
              Text(
                '$itemCount ${itemCount > 1 ? 'items' : 'item'} in your cart',
                style: TextStyle(color: context.palette.textMuted, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // ============================================================
  // SUMMARY ROW
  // ============================================================
  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isDelivery = false,
    bool isService = false,
  }) {
    // All fee amounts share the same readable palette color in light + dark.
    // "Free" delivery stays green as an accent.
    final Color valueColor = (isDelivery && value == 'Free')
        ? AppColors.success
        : context.palette.textSecondary;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14, color: context.palette.textMuted),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // FEE CALCULATIONS
  // ============================================================
  double _calculateDeliveryFee(List cartItems) {
    // Free delivery for orders above GHS 500
    final subtotal = cartItems.fold(0.0, (sum, item) => sum + item.lineTotal);
    return subtotal >= 500 ? 0 : 20.0;
  }

  double _calculateServiceFee(double subtotal) {
    // 10% platform fee
    return subtotal * 0.10;
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
    List cartItems,
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
                    if (cartItems.any(
                      (item) => item.product.id == product.id,
                    )) {
                      return const SizedBox.shrink();
                    }
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
            const SizedBox(
              height: 120,
              child: LoadingWidget.compact(),
            ),
          ],
        ),
      ),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }

  // ============================================================
  // RELATED PRODUCTS (based on cart items)
  // ============================================================
  Widget _buildRelatedProducts(
    BuildContext context,
    AsyncValue<List> productsAsync,
    List cartItems,
  ) {
    return productsAsync.when(
      data: (products) {
        final cartCategories = cartItems
            .map((item) => item.product.category)
            .toSet()
            .toList();

        final relatedProducts = products
            .where(
              (p) =>
                  cartCategories.contains(p.category) &&
                  !cartItems.any((item) => item.product.id == p.id),
            )
            .take(6)
            .toList();

        if (relatedProducts.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Related Products',
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
                  itemCount: relatedProducts.length,
                  itemBuilder: (context, index) {
                    final product = relatedProducts[index];
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
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }
}
