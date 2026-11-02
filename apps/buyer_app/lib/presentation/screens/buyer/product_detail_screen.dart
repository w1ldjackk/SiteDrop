// lib/presentation/screens/buyer/product_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import 'package:sitedrop_core/app/routes/route_names.dart';
import 'package:sitedrop_core/app/theme/colors.dart';
import 'package:sitedrop_core/config/app_config.dart';
import 'package:sitedrop_core/core/utils/display_names.dart';
import '../../../core/utils/auth_gate.dart';
import 'package:sitedrop_core/core/utils/helpers.dart';
import 'package:sitedrop_core/data/models/product.dart';
import 'package:sitedrop_core/data/models/review.dart';
import 'package:sitedrop_core/data/services/follow_service.dart';
import 'package:sitedrop_core/data/services/product_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/follow_provider.dart';
import '../../providers/recently_viewed_provider.dart';
import '../../providers/wishlist_provider.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/app_back_button.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  final String productId;

  const ProductDetailScreen({super.key, required this.productId});

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  int _quantity = 1;
  int _selectedTab = 0;
  int _currentImageIndex = 0;
  String? _trackedProductId;
  late final PageController _galleryController;
  final ScrollController _thumbStripController = ScrollController();

  @override
  void initState() {
    super.initState();
    _galleryController = PageController();
  }

  @override
  void dispose() {
    _galleryController.dispose();
    _thumbStripController.dispose();
    super.dispose();
  }

  /// Jump the main gallery to [index] (thumbnail taps, fullscreen return).
  void _goToGalleryPage(int index, int count) {
    if (count == 0) {
      return;
    }
    final target = index.clamp(0, count - 1);
    setState(() => _currentImageIndex = target);
    if (_galleryController.hasClients) {
      _galleryController.animateToPage(
        target,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
    _scrollThumbIntoView(target);
  }

  void _onGalleryPageChanged(int index) {
    setState(() => _currentImageIndex = index);
    _scrollThumbIntoView(index);
  }

  void _scrollThumbIntoView(int index) {
    if (!_thumbStripController.hasClients) {
      return;
    }
    // 50px thumb + 8px right margin.
    const extent = 58.0;
    final max = _thumbStripController.position.maxScrollExtent;
    _thumbStripController.animateTo(
      (index * extent - 100).clamp(0.0, max),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  /// Fullscreen swipeable gallery with pinch-zoom. Returns the last viewed
  /// index so the inline gallery can sync to it.
  Future<void> _openFullscreenGallery(List<String> images, int initial) async {
    if (images.isEmpty) {
      return;
    }
    final result = await showDialog<int>(
      context: context,
      barrierColor: Colors.black,
      builder: (ctx) =>
          _FullscreenGallery(images: images, initialIndex: initial),
    );
    if (result != null && mounted) {
      _goToGalleryPage(result, images.length);
    }
  }

  @override
  Widget build(BuildContext context) {
    final productAsync = ref.watch(productDetailsProvider(widget.productId));
    final wishlistAsync = ref.watch(wishlistProvider);
    final isWishlisted = wishlistAsync.maybeWhen(
      data: (items) => items.any((p) => p.id == widget.productId),
      orElse: () => false,
    );

    return Scaffold(
      backgroundColor: context.palette.background,
      body: productAsync.when(
        data: (product) {
          if (product == null) {
            return _buildProductNotFound();
          }
          // Track for "Recently Viewed" once per product open.
          if (_trackedProductId != product.id) {
            _trackedProductId = product.id;
            _currentImageIndex = 0;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              ref.read(recentlyViewedProvider.notifier).track(product);
              if (_galleryController.hasClients) {
                _galleryController.jumpToPage(0);
              }
            });
          }
          return _buildProductContent(product, isWishlisted: isWishlisted);
        },
        loading: () => const LoadingWidget(message: 'Loading product details…'),
        error: (error, stack) => _buildErrorState(error),
      ),
    );
  }

  // ============================================================
  // BUILD METHODS
  // ============================================================

  Widget _buildProductNotFound() {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 48,
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: context.palette.surfaceMuted,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.error_outline,
                        size: 60,
                        color: context.palette.iconMuted,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Product Not Found',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: context.palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The product you are looking for does not exist',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: context.palette.textMuted,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go(RouteNames.home);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorState(dynamic error) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 48,
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppColors.errorSurface,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.error_outline,
                        size: 60,
                        color: AppColors.error,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Something went wrong',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: context.palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Error loading product',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: context.palette.textMuted,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () {
                        ref.invalidate(
                          productDetailsProvider(widget.productId),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductContent(
    ProductModel product, {
    required bool isWishlisted,
  }) {
    // Original design: image fills remaining space; sheet is ~55% of screen.
    // Clamp sheet to available body height so safe areas never overflow.
    return LayoutBuilder(
      builder: (context, constraints) {
        final preferred = MediaQuery.sizeOf(context).height * 0.55;
        final sheetH = preferred.clamp(0.0, constraints.maxHeight * 0.55);

        return Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildProductImage(product),
                  // Decorative overlays must not eat gestures: the gradient
                  // container paints full-size (hit-testable) and the name
                  // overlay spans the bottom, which previously swallowed every
                  // swipe/tap meant for the gallery PageView beneath them.
                  // NOTE: _buildProductNameOverlay returns a Positioned, which
                  // must stay a direct Stack child — its IgnorePointer lives
                  // inside that method, around the content.
                  IgnorePointer(child: _buildGradientOverlay()),
                  _buildProductNameOverlay(product),
                  _buildTopBar(product, isWishlisted: isWishlisted),
                ],
              ),
            ),
            SizedBox(height: sheetH, child: _buildBottomSheet(product)),
          ],
        );
      },
    );
  }

  // ============================================================
  // IMAGE SECTION - Multiple Image Support with Thumbnails
  // ============================================================

  Widget _buildProductImage(ProductModel product) {
    // Get images list - use images if available, otherwise fallback to single imageUrl
    final List<String> imageList = product.images.isNotEmpty
        ? product.images
        : (product.imageUrl.isNotEmpty ? [product.imageUrl] : []);

    if (imageList.isEmpty) {
      return Container(
        color: context.palette.surfaceMuted,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_not_supported,
              size: 64,
              color: context.palette.iconMuted,
            ),
            const SizedBox(height: 8),
            Text(
              'No image available',
              style: TextStyle(color: context.palette.textMuted, fontSize: 14),
            ),
          ],
        ),
      );
    }

    // Single image - tap opens fullscreen zoom view.
    if (imageList.length == 1) {
      return GestureDetector(
        onTap: () => _openFullscreenGallery(imageList, 0),
        child: Container(
          height: double.infinity,
          width: double.infinity,
          color: context.palette.surfaceMuted,
          child: Image.network(
            imageList.first,
            key: ValueKey(imageList.first),
            fit: BoxFit.cover,
            width: double.infinity,
            placeholder: (context, url) =>
                Container(color: context.palette.surfaceMuted),
            errorBuilder: (context, error, stackTrace) => Container(
              color: context.palette.surfaceMuted,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.image_not_supported,
                    size: 64,
                    color: context.palette.iconMuted,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No image available',
                    style: TextStyle(
                      color: context.palette.textMuted,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Multiple images - gallery + thumbnails (Positioned must sit in a Stack)
    return Stack(
      fit: StackFit.expand,
      children: [
        Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _galleryController,
                itemCount: imageList.length,
                onPageChanged: _onGalleryPageChanged,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () => _openFullscreenGallery(imageList, index),
                    child: CachedNetworkImage(
                      imageUrl: imageList[index],
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: (context, url) =>
                          Container(color: context.palette.surfaceMuted),
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: context.palette.surfaceMuted,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.image_not_supported,
                              size: 64,
                              color: context.palette.iconMuted,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No image available',
                              style: TextStyle(
                                color: context.palette.textMuted,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              color: Colors.black.withValues(alpha: 0.3),
              child: ListView.builder(
                controller: _thumbStripController,
                scrollDirection: Axis.horizontal,
                itemCount: imageList.length,
                itemBuilder: (context, index) {
                  final isSelected = _currentImageIndex == index;
                  return GestureDetector(
                    onTap: () => _goToGalleryPage(index, imageList.length),
                    child: Container(
                      width: 50,
                      height: 50,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.white.withValues(alpha: 0.5),
                          width: isSelected ? 3 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: CachedNetworkImage(
                          imageUrl: imageList[index],
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              Container(color: context.palette.divider),
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: context.palette.divider,
                            child: Icon(
                              Icons.error,
                              size: 20,
                              color: context.palette.iconMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        // Dots above the thumbnail strip.
        Positioned(
          left: 0,
          right: 0,
          bottom: 68,
          child: IgnorePointer(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (
                  int i = 0;
                  i < imageList.length && i < 9;
                  i++
                )
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _currentImageIndex.clamp(0, imageList.length - 1)
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.45),
                      boxShadow: const [
                        BoxShadow(color: Colors.black45, blurRadius: 2),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_currentImageIndex.clamp(0, imageList.length - 1) + 1}/${imageList.length}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGradientOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.5)],
          stops: const [0.6, 1.0],
        ),
      ),
    );
  }

  // ============================================================
  // TOP BAR
  // ============================================================

  Widget _buildTopBar(ProductModel product, {required bool isWishlisted}) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildBackButton(),
              _buildTopRightButtons(product, isWishlisted: isWishlisted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return const AppBackButton(
      fallbackRoute: RouteNames.home,
      margin: EdgeInsets.zero,
    );
  }

  Widget _buildTopRightButtons(
    ProductModel product, {
    required bool isWishlisted,
  }) {
    final p = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Semi-opaque surface that stays readable over product images in both themes.
    final btnBg = isDark
        ? p.surface.withValues(alpha: 0.92)
        : Colors.white.withValues(alpha: 0.92);
    final iconColor = p.textPrimary;

    return Row(
      children: [
        // Wishlist Button
        Container(
          decoration: BoxDecoration(
            color: btnBg,
            shape: BoxShape.circle,
            border: Border.all(color: p.border),
            boxShadow: [BoxShadow(color: p.shadow, blurRadius: 8)],
          ),
          child: IconButton(
            icon: Icon(
              isWishlisted ? Icons.favorite : Icons.favorite_border,
              color: isWishlisted ? AppColors.error : iconColor,
            ),
            onPressed: () => _toggleWishlist(product),
          ),
        ),
        const SizedBox(width: 8),
        // Share Button
        Container(
          decoration: BoxDecoration(
            color: btnBg,
            shape: BoxShape.circle,
            border: Border.all(color: p.border),
            boxShadow: [BoxShadow(color: p.shadow, blurRadius: 8)],
          ),
          child: IconButton(
            icon: Icon(Icons.share_outlined, color: iconColor),
            onPressed: () => _shareProduct(product),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // PRODUCT NAME OVERLAY - WITH RATINGS
  // ============================================================

  Widget _buildProductNameOverlay(ProductModel product) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Text(
              product.name,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            // Rating left · price right with clear breathing room.
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(Icons.star, size: 16, color: AppColors.warning),
                const SizedBox(width: 4),
                Text(
                  product.rating > 0
                      ? product.rating.toStringAsFixed(1)
                      : '0.0',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '(${product.reviewCount} reviews)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    Helpers.formatPrice(product.price),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '/ ${product.unit}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }

  // ============================================================
  // BOTTOM SHEET
  // ============================================================

  Widget _buildBottomSheet(ProductModel product) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildDragHandle(),
          _buildTabs(),
          Expanded(
            child: IndexedStack(
              index: _selectedTab,
              children: [
                _buildDetailsTab(product),
                _buildReviewsTab(product),
                _buildSellerTab(product),
              ],
            ),
          ),
          _buildBottomActionBar(product),
        ],
      ),
    );
  }

  Widget _buildDragHandle() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: context.palette.borderStrong,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  // ============================================================
  // TABS
  // ============================================================

  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildTab('Details', 0),
            const SizedBox(width: 16),
            _buildTab('Reviews', 1),
            const SizedBox(width: 16),
            _buildTab('Seller', 2),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String title, int index) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? AppColors.primary : AppColors.grey500,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 24,
            height: 3,
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DETAILS TAB
  // ============================================================

  Widget _buildDetailsTab(ProductModel product) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tags
          _buildTags(product),
          const SizedBox(height: 20),

          // Service Commitment
          _buildServiceCommitment(product),
          const SizedBox(height: 20),

          // Description
          _buildDescription(product),
          const SizedBox(height: 20),

          // Specifications
          if (product.specifications != null &&
              product.specifications!.isNotEmpty) ...[
            _buildSpecifications(product),
            const SizedBox(height: 20),
          ],

          // Report Product
          _buildReportRow(product),
          const SizedBox(height: 16),

          // Recently Viewed
          _buildRecentlyViewed(excludeProductId: product.id),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildTags(ProductModel product) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: context.palette.primarySoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            product.category,
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: product.inStock
                ? AppColors.successSurface
                : AppColors.errorSurface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            product.inStock ? 'In Stock' : 'Out of Stock',
            style: TextStyle(
              color: product.inStock ? AppColors.success : AppColors.error,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: context.palette.surfaceMuted,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Min: ${product.minQuantity} ${product.unit}',
            style: TextStyle(
              color: context.palette.textMuted,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ),
        // Mirrors the seller "Cash on Delivery" toggle.
        if (product.isCodAvailable)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.successSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Cash on Delivery',
              style: TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  /// Service row synced with the seller toggles: delivery availability comes
  /// from the product, refund/privacy are static store policies.
  Widget _buildServiceCommitment(ProductModel product) {
    final showPickup = product.siteName.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.palette.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildServiceItem(
                icon: product.isDeliveryAvailable
                    ? Icons.local_shipping_outlined
                    : Icons.remove_shopping_cart_outlined,
                label: 'Delivery',
                subLabel: product.isDeliveryAvailable
                    ? 'Available'
                    : 'Unavailable',
              ),
              _buildServiceItem(
                icon: Icons.verified_outlined,
                label: 'Refund',
                subLabel: 'Policy',
              ),
              _buildServiceItem(
                icon: Icons.privacy_tip_outlined,
                label: 'Privacy',
                subLabel: 'Protected',
              ),
            ],
          ),
          if (showPickup) ...[
            const SizedBox(height: 12),
            Divider(color: context.palette.border, height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.store_outlined, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Pickup at:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: context.palette.textSecondary,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    product.siteName,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.palette.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildServiceItem({
    required IconData icon,
    required String label,
    required String subLabel,
  }) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 24),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: context.palette.textSecondary,
          ),
        ),
        Text(
          subLabel,
          style: TextStyle(fontSize: 11, color: context.palette.textMuted),
        ),
      ],
    );
  }

  Widget _buildDescription(ProductModel product) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Description',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: context.palette.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          product.description.isNotEmpty
              ? product.description
              : 'No description available',
          style: TextStyle(
            color: context.palette.textMuted,
            fontSize: 15,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildSpecifications(ProductModel product) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Specifications',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: context.palette.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        ...product.specifications!.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 100,
                  child: Text(
                    DisplayNames.titleCase(entry.key),
                    style: TextStyle(
                      color: context.palette.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    _humanizeSpecValue(entry.value),
                    style: TextStyle(
                      color: context.palette.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  /// Backend spec values are raw slugs ("galvanized_steel") — show words.
  String _humanizeSpecValue(dynamic value) {
    if (value is String) {
      final v = value.trim();
      if (v.isEmpty) return '—';
      return DisplayNames.titleCase(v);
    }
    if (value is List) {
      return value.map((e) => _humanizeSpecValue(e)).join(', ');
    }
    return '${value ?? '—'}';
  }

  static const _reportReasons = <String, String>{
    'counterfeit': 'Counterfeit / fake item',
    'misleading': 'Misleading description',
    'prohibited': 'Prohibited item',
    'wrong_price': 'Wrong price',
    'spam': 'Spam or scam',
    'other': 'Other',
  };

  Future<void> _openReportSheet(ProductModel product) async {
    final ok = await AuthGate.require(
      context,
      ref,
      action: 'report this product',
    );
    if (!ok || !mounted) return;

    String reason = 'misleading';
    // NOTE: intentionally no TextEditingController here — disposing a
    // sheet-owned controller at close races the exit animation rebuild
    // (keyboard dismissal) and crashes with "used after dispose".
    // Text is captured via onChanged instead.
    var detailsText = '';
    var submitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheet) => StatefulBuilder(
        builder: (sheetContext, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom:
                MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          // Bounded + scrollable: keyboard / small screens can never
          // overflow the sheet (was a red-screen source).
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight:
                  MediaQuery.of(sheetContext).size.height * 0.85,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              const Text(
                'Report this product',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'Our team reviews every report.',
                style: TextStyle(
                  fontSize: 13,
                  color: context.palette.textMuted,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _reportReasons.entries.map((e) {
                  final selected = reason == e.key;
                  return FilterChip(
                    label: Text(e.value),
                    selected: selected,
                    onSelected: (_) =>
                        setSheet(() => reason = e.key),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                enabled: !submitting,
                maxLines: 3,
                maxLength: 2000,
                onChanged: (v) => detailsText = v,
                decoration: const InputDecoration(
                  hintText: 'Details (optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(14)),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: submitting
                    ? null
                    : () async {
                        setSheet(() => submitting = true);
                        try {
                          final (sent, message) =
                              await FollowService.reportProduct(
                            product.id,
                            reason: reason,
                            details: detailsText,
                          );
                          if (!mounted) return;
                          Navigator.pop(sheet);
                          if (sent) {
                            Helpers.showSuccessToast(message);
                          } else {
                            Helpers.showErrorToast(message);
                          }
                        } catch (_) {
                          if (mounted) {
                            Helpers.showErrorToast(
                              'Could not submit report',
                            );
                          }
                        } finally {
                          if (sheetContext.mounted) {
                            setSheet(() => submitting = false);
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Submit report',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ],
          ),
        ),
        ),
        ),
      ),
    );
  }

  Widget _buildReportRow(ProductModel product) {
    return GestureDetector(
      onTap: () => _openReportSheet(product),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(
              Icons.flag_outlined,
              size: 18,
              color: context.palette.textMuted,
            ),
            const SizedBox(width: 8),
            Text(
              'Report this product',
              style: TextStyle(color: context.palette.textMuted, fontSize: 14),
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: context.palette.iconMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentlyViewed({required String excludeProductId}) {
    final products = ref.watch(
      recentlyViewedProductsProvider(excludeProductId),
    );

    if (products.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recently Viewed',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: context.palette.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return GestureDetector(
                onTap: () {
                  context.push(
                    RouteNames.productDetail.replaceAll(':id', product.id),
                  );
                },
                child: Container(
                  width: 80,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: context.palette.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: context.palette.divider,
                      width: 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      Expanded(
                        child: product.imageUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: product.imageUrl,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                placeholder: (_, _) => ColoredBox(
                                  color: context.palette.surfaceMuted,
                                  child: Icon(
                                    Icons.image_outlined,
                                    color: context.palette.iconMuted,
                                    size: 24,
                                  ),
                                ),
                                errorWidget: (_, _, _) => ColoredBox(
                                  color: context.palette.surfaceMuted,
                                  child: Icon(
                                    Icons.image_outlined,
                                    color: context.palette.iconMuted,
                                    size: 24,
                                  ),
                                ),
                              )
                            : ColoredBox(
                                color: context.palette.surfaceMuted,
                                child: Center(
                                  child: Icon(
                                    Icons.image_outlined,
                                    color: context.palette.iconMuted,
                                    size: 24,
                                  ),
                                ),
                              ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        child: Text(
                          product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            color: context.palette.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ============================================================
  // REVIEWS TAB
  // ============================================================

  Widget _buildReviewsTab(ProductModel product) {
    final reviewsAsync = ref.watch(productReviewsProvider(product.id));
    // Rebuild when auth changes so Write → Edit Review updates correctly.
    ref.watch(authProvider);

    return reviewsAsync.when(
      loading: () => Container(color: context.palette.surfaceMuted),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 40, color: AppColors.error),
              const SizedBox(height: 12),
              Text(
                'Could not load reviews',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: context.palette.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                Helpers.errorMessage(error),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.palette.textMuted,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () =>
                    ref.invalidate(productReviewsProvider(product.id)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (payload) {
        final reviews = payload.reviews;
        final summary = payload.summary;
        final myReview = _findMyReview(reviews);
        final isEditing = myReview != null;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(child: _buildReviewSummaryHeader(summary, product)),
                  // Slim CTA — matches bottom-bar Add To Cart density.
                  if (reviews.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    Material(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        onTap: () =>
                            _openWriteReviewSheet(product, existing: myReview),
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isEditing
                                    ? Icons.edit_outlined
                                    : Icons.rate_review_outlined,
                                size: 16,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isEditing ? 'Edit Review' : 'Write',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  height: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: reviews.isEmpty
                  ? _buildEmptyReviewsState(product)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      itemCount: reviews.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        return _buildReviewCard(reviews[index]);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  /// Current user's review for this product, if any.
  ReviewModel? _findMyReview(List<ReviewModel> reviews) {
    // asData?.value — .value throws while auth is loading (red screen).
    final auth = ref.read(authProvider).asData?.value;
    if (auth is! AuthAuthenticated) return null;
    final uid = auth.user.id.toString();
    if (uid.isEmpty) return null;
    for (final r in reviews) {
      if (r.reviewerId.toString() == uid) return r;
    }
    return null;
  }

  Widget _buildReviewSummaryHeader(
    ReviewSummary summary,
    ProductModel product,
  ) {
    final avg = summary.total > 0 ? summary.averageRating : product.rating;
    final total = summary.total > 0 ? summary.total : product.reviewCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              avg > 0 ? avg.toStringAsFixed(1) : '—',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: context.palette.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStarRow(avg.round().clamp(0, 5), size: 16),
                  const SizedBox(height: 2),
                  Text(
                    total == 1 ? '1 review' : '$total reviews',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.palette.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyReviewsState(ProductModel product) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.star_outline,
              size: 56,
              color: context.palette.iconMuted,
            ),
            const SizedBox(height: 12),
            Text(
              'No Reviews Yet',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: context.palette.icon,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Be the first to review this product',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.palette.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _openWriteReviewSheet(product),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Write a Review'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewCard(ReviewModel review) {
    final dateLabel = review.createdAt != null
        ? DateFormat.yMMMd().format(review.createdAt!.toLocal())
        : '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.palette.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                backgroundImage:
                    (review.reviewerAvatar != null &&
                        review.reviewerAvatar!.isNotEmpty)
                    ? NetworkImage(review.reviewerAvatar!)
                    : null,
                child:
                    (review.reviewerAvatar == null ||
                        review.reviewerAvatar!.isEmpty)
                    ? Text(
                        review.initials,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.reviewerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: context.palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        _buildStarRow(review.rating, size: 14),
                        if (dateLabel.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              dateLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: context.palette.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (review.isVerifiedPurchase)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.successSurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Verified',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.success,
                    ),
                  ),
                ),
            ],
          ),
          if (review.comment.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              review.comment,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: context.palette.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStarRow(int filled, {double size = 18}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return Icon(
          i < filled ? Icons.star_rounded : Icons.star_border_rounded,
          size: size,
          color: i < filled ? AppColors.warning : context.palette.iconMuted,
        );
      }),
    );
  }

  Future<void> _openWriteReviewSheet(
    ProductModel product, {
    ReviewModel? existing,
  }) async {
    final ok = await AuthGate.require(
      context,
      ref,
      action: existing != null
          ? 'edit your product review'
          : 'write a product review',
    );
    if (!ok || !mounted) return;

    // Re-resolve after login in case auth changed.
    final reviews =
        ref.read(productReviewsProvider(product.id)).asData?.value.reviews ??
        const <ReviewModel>[];
    existing ??= _findMyReview(reviews);
    final isEditing = existing != null;

    int selectedRating = existing?.rating.clamp(1, 5) ?? 5;
    // NOTE: no TextEditingController — disposing a sheet-owned controller
    // at close races the exit animation rebuild (keyboard dismissal) and
    // crashes with "used after dispose". TextFormField owns its own.
    var commentText = existing?.comment ?? '';
    var submitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
            final p = context.palette;

            Future<void> submit() async {
              if (selectedRating < 1) {
                Helpers.showErrorToast('Please select a star rating');
                return;
              }
              setSheetState(() => submitting = true);
              try {
                await ProductService.submitProductReview(
                  product.id,
                  rating: selectedRating,
                  comment: commentText,
                );
                if (!mounted) return;
                ref.invalidate(productReviewsProvider(product.id));
                ref.invalidate(productDetailsProvider(product.id));
                if (sheetContext.mounted) Navigator.pop(sheetContext);
                Helpers.showSuccessToast(
                  isEditing ? 'Review updated' : 'Thanks for your review!',
                );
              } catch (e) {
                Helpers.showErrorToast(e);
              } finally {
                if (sheetContext.mounted) {
                  setSheetState(() => submitting = false);
                }
              }
            }

            return Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Container(
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: p.borderStrong,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isEditing ? 'Edit Review' : 'Write a Review',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: p.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: p.textMuted),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Your rating',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: p.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (i) {
                          final star = i + 1;
                          return IconButton(
                            onPressed: submitting
                                ? null
                                : () => setSheetState(
                                    () => selectedRating = star,
                                  ),
                            iconSize: 36,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            constraints: const BoxConstraints(),
                            icon: Icon(
                              star <= selectedRating
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              color: star <= selectedRating
                                  ? AppColors.warning
                                  : p.iconMuted,
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Comment (optional)',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: p.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        initialValue: commentText,
                        enabled: !submitting,
                        maxLines: 4,
                        maxLength: 2000,
                        textInputAction: TextInputAction.newline,
                        onChanged: (v) => commentText = v,
                        decoration: InputDecoration(
                          hintText: 'Share your experience with this product…',
                          filled: true,
                          fillColor: p.inputFill,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: p.inputBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: p.inputBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: submitting ? null : submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: submitting
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  isEditing ? 'Save Changes' : 'Submit Review',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ============================================================
  // SELLER TAB
  // ============================================================

  Widget _buildSellerTab(ProductModel product) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSellerInfo(product),
          const SizedBox(height: 16),
          _buildSellerProducts(product),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _toggleFollow(ProductModel product) async {
    if (product.sellerId.isEmpty) return;
    final ok = await AuthGate.require(
      context,
      ref,
      action: 'follow this seller',
    );
    if (!ok || !mounted) return;
    try {
      final (success, message) =
          await toggleSellerFollow(ref, product.sellerId);
      if (!mounted) return;
      if (success) {
        Helpers.showSuccessToast(message);
      } else {
        Helpers.showErrorToast(message);
      }
    } catch (e) {
      if (mounted) Helpers.showErrorToast('Could not update follow');
    }
  }

  Widget _followButton(ProductModel product, {bool compact = false}) {
    if (product.sellerId.isEmpty) return const SizedBox.shrink();
    final follow = ref
        .watch(sellerFollowProvider(product.sellerId))
        .asData
        ?.value;
    final following = follow?.following ?? false;
    final label = following ? 'Following' : 'Follow';
    if (compact) {
      return IconButton(
        tooltip: label,
        onPressed: () => _toggleFollow(product),
        icon: Icon(
          following ? Icons.how_to_reg : Icons.person_add_outlined,
          color: following ? AppColors.primary : context.palette.icon,
          size: 26,
        ),
        padding: const EdgeInsets.all(4),
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      );
    }
    return OutlinedButton.icon(
      onPressed: () => _toggleFollow(product),
      icon: Icon(
        following ? Icons.check : Icons.person_add_outlined,
        size: 18,
      ),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor:
            following ? AppColors.success : AppColors.primary,
        side: BorderSide(
          color: following ? AppColors.success : AppColors.primary,
        ),
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildSellerInfo(ProductModel product) {
    final sellerKey = product.sellerId.isNotEmpty
        ? '${product.sellerId}|${product.id}'
        : '';
    final sellerProductsAsync = sellerKey.isNotEmpty
        ? ref.watch(productsBySellerProvider(sellerKey))
        : null;
    final productCount = sellerProductsAsync?.maybeWhen(
      data: (list) => list.length + 1, // include current product
      orElse: () => null,
    );
    final followersCount = product.sellerId.isNotEmpty
        ? ref
            .watch(sellerFollowProvider(product.sellerId))
            .asData
            ?.value
            .followersCount
        : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.palette.divider),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: AppColors.primary,
            child: Text(
              product.sellerName.isNotEmpty
                  ? product.sellerName[0].toUpperCase()
                  : 'S',
              style: const TextStyle(
                fontSize: 20,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.sellerName.isNotEmpty ? product.sellerName : 'Seller',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: context.palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.star, size: 14, color: AppColors.warning),
                    const SizedBox(width: 4),
                    Text(
                      product.rating > 0
                          ? product.rating.toStringAsFixed(1)
                          : 'New',
                      style: TextStyle(
                        color: context.palette.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _statText(
                      context,
                      Icons.shopping_bag_outlined,
                      productCount != null
                          ? '$productCount product${productCount == 1 ? '' : 's'}'
                          : '…',
                    ),
                    if (followersCount != null)
                      _statText(
                        context,
                        Icons.people_outline,
                        '$followersCount follower${followersCount == 1 ? '' : 's'}',
                      ),
                  ],
                ),
              ],
            ),
          ),
          _followButton(product),
        ],
      ),
    );
  }

  /// Icon + text stat that wraps safely (never a nested Row that can
  /// overflow on narrow screens).
  Widget _statText(BuildContext context, IconData icon, String text) {
    return Text.rich(
      TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Icon(
              icon,
              size: 14,
              color: context.palette.textMuted,
            ),
          ),
          const TextSpan(text: '  '),
          TextSpan(
            text: text,
            style: TextStyle(
              color: context.palette.textMuted,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSellerProducts(ProductModel product) {
    if (product.sellerId.isEmpty) {
      return const SizedBox.shrink();
    }

    final key = '${product.sellerId}|${product.id}';
    final sellerAsync = ref.watch(productsBySellerProvider(key));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'More from this seller',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: context.palette.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        sellerAsync.when(
          data: (products) {
            if (products.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No other products from this seller yet.',
                  style: TextStyle(
                    color: context.palette.textMuted,
                    fontSize: 13,
                  ),
                ),
              );
            }
            return SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final item = products[index];
                  return GestureDetector(
                    onTap: () {
                      context.push(
                        RouteNames.productDetail.replaceAll(':id', item.id),
                      );
                    },
                    child: Container(
                      width: 140,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: context.palette.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: context.palette.divider,
                          width: 1,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: 100,
                            width: double.infinity,
                            child: item.imageUrl.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: item.imageUrl,
                                    fit: BoxFit.cover,
                                    placeholder: (_, _) => ColoredBox(
                                      color: context.palette.surfaceMuted,
                                      child: Icon(
                                        Icons.image_outlined,
                                        color: context.palette.iconMuted,
                                      ),
                                    ),
                                    errorWidget: (_, _, _) => ColoredBox(
                                      color: context.palette.surfaceMuted,
                                      child: Icon(
                                        Icons.image_outlined,
                                        color: context.palette.iconMuted,
                                      ),
                                    ),
                                  )
                                : ColoredBox(
                                    color: context.palette.surfaceMuted,
                                    child: Center(
                                      child: Icon(
                                        Icons.image_outlined,
                                        color: context.palette.iconMuted,
                                      ),
                                    ),
                                  ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                    color: context.palette.textSecondary,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  Helpers.formatPrice(item.price),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
          loading: () =>
              const SizedBox(height: 120, child: LoadingWidget.compact()),
          error: (_, _) => Text(
            'Could not load seller products.',
            style: TextStyle(color: context.palette.textMuted, fontSize: 13),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // BOTTOM ACTION BAR - Original design (integrated qty + CTAs)
  // ============================================================

  Widget _buildBottomActionBar(ProductModel product) {
    // Keep original single-row layout. FittedBox only scales the CTA group
    // slightly on very narrow widths (~29px overflow) without redesigning.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.palette.surface,
        border: Border(
          top: BorderSide(color: context.palette.divider, width: 1),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.go(RouteNames.home),
            icon: Icon(
              Icons.home_outlined,
              color: context.palette.icon,
              size: 26,
            ),
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          _followButton(product, compact: true),
          Builder(
            builder: (context) {
              final cartItems = ref.watch(cartProvider);
              final cartCount = cartItems.fold<int>(0, (sum, item) => sum + item.quantity);
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    onPressed: () async {
                      final ok = await AuthGate.require(
                        context,
                        ref,
                        action: 'view your cart',
                      );
                      if (!ok || !mounted) return;
                      context.go(RouteNames.cart);
                    },
                    icon: Icon(
                      Icons.shopping_cart_outlined,
                      color: context.palette.icon,
                      size: 26,
                    ),
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                  if (cartCount > 0)
                    Positioned(
                      right: 2,
                      top: 2,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          cartCount > 9 ? '9+' : '$cartCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Add to Cart with Integrated Quantity Selector
                    Container(
                      decoration: BoxDecoration(
                        color: product.inStock
                            ? AppColors.primary
                            : AppColors.grey400,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_quantity > 1)
                            InkWell(
                              onTap: product.inStock
                                  ? () {
                                      setState(() {
                                        _quantity--;
                                      });
                                    }
                                  : null,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 10,
                                ),
                                child: const Icon(
                                  Icons.remove,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              '$_quantity',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: product.inStock
                                ? () {
                                    setState(() {
                                      _quantity++;
                                    });
                                  }
                                : null,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 10,
                              ),
                              child: const Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                          if (_quantity > 0)
                            InkWell(
                              onTap: product.inStock
                                  ? () async {
                                      final ok = await AuthGate.require(
                                        context,
                                        ref,
                                        action: 'add items to your cart',
                                      );
                                      if (!ok || !mounted) return;
                                      ref
                                          .read(cartProvider.notifier)
                                          .addProduct(
                                            product,
                                            quantity: _quantity,
                                          );
                                      Helpers.showSuccessToast(
                                        'Added $_quantity ${product.unit}(s) to cart',
                                      );
                                    }
                                  : null,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: const BoxDecoration(
                                  color: AppColors.primaryDark,
                                  borderRadius: BorderRadius.only(
                                    topRight: Radius.circular(12),
                                    bottomRight: Radius.circular(12),
                                  ),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.shopping_cart_outlined,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Add To Cart',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: product.inStock
                          ? () async {
                              final ok = await AuthGate.require(
                                context,
                                ref,
                                action: 'buy this product',
                              );
                              if (!ok || !mounted) return;
                              ref
                                  .read(cartProvider.notifier)
                                  .addProduct(product, quantity: _quantity);
                              if (!mounted) return;
                              context.go(RouteNames.checkout);
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        minimumSize: const Size(70, 44),
                      ),
                      child: const Text(
                        'Buy Now',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
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

  // ============================================================
  // ACTION METHODS
  // ============================================================

  Future<void> _toggleWishlist(ProductModel product) async {
    final ok = await AuthGate.require(
      context,
      ref,
      action: 'save items to your wishlist',
    );
    if (!ok || !mounted) return;

    try {
      final nowInList = await ref
          .read(wishlistProvider.notifier)
          .toggle(product);
      Helpers.showInfoToast(nowInList ? 'Added to wishlist' : 'Removed from wishlist');
    } catch (e) {
      Helpers.showErrorToast('Could not update wishlist');
    }
  }

  Future<void> _shareProduct(ProductModel product) async {
    final price = Helpers.formatPrice(product.price);
    final unit = product.unit.trim().isEmpty ? '' : ' / ${product.unit}';
    final url = AppConfig.productShareUrl(product.id);
    final ratingLine = product.rating > 0
        ? '⭐ ${product.rating.toStringAsFixed(1)}'
              '${product.reviewCount > 0 ? ' (${product.reviewCount} reviews)' : ''}\n'
        : '';
    final sellerLine = product.sellerName.trim().isNotEmpty
        ? 'Seller: ${product.sellerName}\n'
        : '';

    final text = StringBuffer()
      ..writeln('${product.name} on ${AppConfig.appName}')
      ..writeln('$price$unit')
      ..write(ratingLine)
      ..write(sellerLine)
      ..writeln()
      ..writeln(url)
      ..writeln()
      ..write('Shared via ${AppConfig.appName}');

    try {
      final box = context.findRenderObject() as RenderBox?;
      final origin = box != null
          ? box.localToGlobal(Offset.zero) & box.size
          : null;

      await SharePlus.instance.share(
        ShareParams(
          text: text.toString().trim(),
          subject: '${product.name} · ${AppConfig.appName}',
          title: product.name,
          sharePositionOrigin: origin,
        ),
      );
    } catch (e) {
      Helpers.showErrorToast('Could not open share sheet');
    }
  }
}

/// Fullscreen swipeable gallery with pinch-zoom. Popping returns the last
/// viewed page index (null when dismissed without an explicit close).
class _FullscreenGallery extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const _FullscreenGallery({required this.images, required this.initialIndex});

  @override
  State<_FullscreenGallery> createState() => _FullscreenGalleryState();
}

class _FullscreenGalleryState extends State<_FullscreenGallery> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.images.length - 1);
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop(_index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: _close,
          icon: const Icon(Icons.close, color: Colors.white),
        ),
        title: Text(
          '${_index + 1} / ${widget.images.length}',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        centerTitle: true,
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.images.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, i) {
          return InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: Center(
              child: CachedNetworkImage(
                imageUrl: widget.images[i],
                fit: BoxFit.contain,
                placeholder: (context, url) =>
                    Container(color: context.palette.surfaceMuted),
                errorWidget: (context, url, error) => const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.image_not_supported,
                      size: 64,
                      color: Colors.white54,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'No image available',
                      style: TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
