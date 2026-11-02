// lib/presentation/widgets/buyer/product_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:sitedrop_core/app/routes/route_names.dart';
import 'package:sitedrop_core/app/theme/colors.dart';
import '../../../core/utils/auth_gate.dart';
import 'package:sitedrop_core/core/utils/helpers.dart';
import 'package:sitedrop_core/data/models/product.dart';
import '../../providers/cart_provider.dart';
import '../common/loading_widget.dart';

class ProductCard extends ConsumerWidget {
  final ProductModel product;
  final bool showAddToCart;

  const ProductCard({
    super.key,
    required this.product,
    this.showAddToCart = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;

    return GestureDetector(
      onTap: () {
        context.go(RouteNames.productDetail.replaceAll(':id', product.id));
      },
      child: Card(
        elevation: 0,
        color: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: p.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: product.imageUrl.isNotEmpty
                    ? Image.network(
                        product.imageUrl,
                        key: ValueKey(product.imageUrl),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        gaplessPlayback: true,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(color: p.surfaceMuted);
                        },
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: p.surfaceMuted,
                          child: Icon(
                            Icons.image_not_supported,
                            color: p.iconMuted,
                            size: 48,
                          ),
                        ),
                      )
                    : Container(
                        color: p.surfaceMuted,
                        child: Icon(
                          Icons.image_not_supported,
                          color: p.iconMuted,
                          size: 48,
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: p.textPrimary,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.star, size: 12, color: AppColors.warning),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          product.rating > 0
                              ? product.rating.toStringAsFixed(1)
                              : '0.0',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: p.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: p.surfaceMuted,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '(${product.reviewCount})',
                            style: TextStyle(fontSize: 10, color: p.textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          Helpers.formatPrice(product.price),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (showAddToCart)
                        InkWell(
                          onTap: () async {
                            final ok = await AuthGate.require(
                              context,
                              ref,
                              action: 'add items to your cart',
                            );
                            if (!ok) return;
                            try {
                              ref
                                  .read(cartProvider.notifier)
                                  .addProduct(product);
                              Helpers.showSuccessToast('Added to cart');
                            } catch (e) {
                              Helpers.showErrorToast('Could not add to cart');
                            }
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.add,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
