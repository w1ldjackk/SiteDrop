// lib/presentation/screens/seller/product_management_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sitedrop_core/app/routes/route_names.dart';
import 'package:sitedrop_core/app/theme/colors.dart';
import 'package:sitedrop_core/core/utils/helpers.dart';
import 'package:sitedrop_core/data/models/product.dart';
import 'package:sitedrop_core/data/services/product_service.dart';
import '../../widgets/common/app_back_button.dart';
import '../../widgets/common/loading_widget.dart';
import '../../providers/product_provider.dart';

class ProductManagementScreen extends ConsumerWidget {
  const ProductManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(sellerProductsProvider);

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        backgroundColor: context.palette.surface,
        elevation: 0,
        title: appBarTitle(context, 'Manage Products'),
        leading: const AppBackButton(fallbackRoute: RouteNames.sellerDashboard),
        actions: [
          IconButton(
            tooltip: 'Add product',
            onPressed: () => context.push(RouteNames.addProduct),
            icon: const Icon(Icons.add),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(sellerProductsProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: productsAsync.when(
        data: (products) {
          if (products.isEmpty) {
            return _buildEmptyState(context);
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(sellerProductsProvider),
            color: AppColors.primary,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: products.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final product = products[index];
                return _ProductManagementCard(
                  product: product,
                  onTap: () => context.push(
                    RouteNames.addProductWithId(product.id),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const LoadingWidget(message: 'Loading products…'),
        error: (error, stack) => _buildErrorState(context, error, ref),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(RouteNames.addProduct),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final p = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: p.surfaceMuted,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                size: 60,
                color: p.iconMuted,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No products yet',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: p.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first product to start selling',
              style: TextStyle(color: p.textMuted, fontSize: 15),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.push(RouteNames.addProduct),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Add Product'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error.toString(), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => ref.invalidate(sellerProductsProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductManagementCard extends ConsumerWidget {
  final ProductModel product;
  final VoidCallback onTap;

  const _ProductManagementCard({
    required this.product,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: p.divider),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Product image placeholder
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: p.surfaceMuted,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: product.imageUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          product.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Icon(
                            Icons.local_shipping_outlined,
                            size: 28,
                            color: p.iconMuted,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.local_shipping_outlined,
                        size: 28,
                        color: p.iconMuted,
                      ),
              ),
              const SizedBox(width: 12),
              // Product info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: p.textPrimary,
                            ),
                          ),
                        ),
                        _StatusChip(product: product),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: p.textMuted),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'GHS ${product.price.toStringAsFixed(2)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'per ${product.unit}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: p.textMuted),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            'Stock: ${product.stockQuantity}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: product.stockQuantity <= 5
                                  ? AppColors.warning
                                  : p.textMuted,
                              fontWeight: product.stockQuantity <= 5
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (product.sku.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'SKU: ${product.sku}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: p.textMuted),
                      ),
                    ],
                  ],
                ),
              ),
              // Actions
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: p.iconMuted),
                onSelected: (value) => _handleAction(context, ref, value),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 18),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: product.inStock ? 'unpublish' : 'publish',
                    child: Row(
                      children: [
                        Icon(
                          product.inStock
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(product.inStock ? 'Unpublish' : 'Publish'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: AppColors.error)),
                      ],
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

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    String action,
  ) async {
    switch (action) {
      case 'edit':
        context.push(RouteNames.addProductWithId(product.id));
        break;
      case 'publish':
        await _toggleAvailability(context, ref, true);
        break;
      case 'unpublish':
        await _toggleAvailability(context, ref, false);
        break;
      case 'delete':
        await _confirmDelete(context, ref);
        break;
    }
  }

  Future<void> _toggleAvailability(
    BuildContext context,
    WidgetRef ref,
    bool publish,
  ) async {
    try {
      final result = await ProductService.toggleProductAvailability(product.id);
      if (!context.mounted) return;
      if (result) {
        Helpers.showSuccessToast(
          publish ? 'Product published' : 'Product unpublished',
        );
        ref.invalidate(sellerProductsProvider);
      } else {
        Helpers.showErrorToast('Failed to update product status');
      }
    } catch (e) {
      if (context.mounted) {
        Helpers.showErrorToast(Helpers.errorMessage(e));
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text('This will permanently delete "${product.name}".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final result = await ProductService.deleteProduct(product.id);
        if (!context.mounted) return;
        if (result) {
          Helpers.showSuccessToast('Product deleted');
          ref.invalidate(sellerProductsProvider);
        } else {
          Helpers.showErrorToast('Failed to delete product');
        }
      } catch (e) {
        if (context.mounted) {
          Helpers.showErrorToast(Helpers.errorMessage(e));
        }
      }
    }
  }
}

class _StatusChip extends StatelessWidget {
  final ProductModel product;

  const _StatusChip({required this.product});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isLowStock = product.stockQuantity > 0 && product.stockQuantity <= 5;
    final isOutOfStock = product.stockQuantity == 0;

    Color bgColor;
    Color textColor;
    String label;

    if (!product.inStock) {
      bgColor = p.surfaceMuted;
      textColor = p.textMuted;
      label = 'Unpublished';
    } else if (isOutOfStock) {
      bgColor = AppColors.error.withValues(alpha: 0.12);
      textColor = AppColors.error;
      label = 'Out of stock';
    } else if (isLowStock) {
      bgColor = AppColors.warning.withValues(alpha: 0.12);
      textColor = AppColors.warning;
      label = 'Low stock';
    } else {
      bgColor = AppColors.success.withValues(alpha: 0.12);
      textColor = AppColors.success;
      label = 'Active';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: textColor.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }
}