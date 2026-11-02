// Live dashboard stats for seller shell tab 0
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sitedrop_core/app/routes/route_names.dart';
import 'package:sitedrop_core/app/theme/colors.dart';
import 'package:sitedrop_core/core/utils/formatters.dart';
import 'package:sitedrop_core/data/models/order.dart';
import 'package:sitedrop_core/data/models/product.dart';
import 'package:sitedrop_core/data/services/order_service.dart';
import 'package:sitedrop_core/data/services/product_service.dart';

import '../../providers/main_tab_provider.dart';

final _sellerDashProvider = FutureProvider.autoDispose((ref) async {
  final products = await ProductService.fetchSellerProducts();
  final lowStockProducts = products
      .where((p) => p.stockQuantity <= (p.minQuantity > 0 ? p.minQuantity : 5))
      .toList();
  final lowStock = lowStockProducts.length;
  var pending = 0;
  var sales = 0.0;
  var totalProducts = products.length;
  var activeProducts = products.where((p) => p.inStock).length;
  var recentOrders = <OrderModel>[];
  try {
    final orders = await OrderService.fetchSellerOrders();
    pending = orders
        .where(
          (o) =>
              o.status == OrderStatus.pending ||
              o.status == OrderStatus.confirmed ||
              o.status == OrderStatus.processing,
        )
        .length;
    sales = orders
        .where(
          (o) =>
              o.status == OrderStatus.completed ||
              o.status == OrderStatus.delivered,
        )
        .fold(0.0, (s, o) => s + o.totalAmount);
    recentOrders = orders.take(5).toList();
  } catch (_) {}
  return _DashboardData(
    sales: sales,
    pending: pending,
    lowStock: lowStock,
    totalProducts: totalProducts,
    activeProducts: activeProducts,
    lowStockProducts: lowStockProducts,
    recentOrders: recentOrders,
  );
});

class _DashboardData {
  final double sales;
  final int pending;
  final int lowStock;
  final int totalProducts;
  final int activeProducts;
  final List<ProductModel> lowStockProducts;
  final List<OrderModel> recentOrders;

  _DashboardData({
    required this.sales,
    required this.pending,
    required this.lowStock,
    required this.totalProducts,
    required this.activeProducts,
    required this.lowStockProducts,
    required this.recentOrders,
  });
}

class SellerDashboardTab extends ConsumerWidget {
  const SellerDashboardTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final async = ref.watch(_sellerDashProvider);

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Dashboard',
          style: TextStyle(fontWeight: FontWeight.w700, color: p.textPrimary),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add_circle_outline, color: AppColors.primary),
            tooltip: 'Add product',
            onPressed: () => context.push(RouteNames.addProduct),
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: p.iconMuted),
            onPressed: () => ref.invalidate(_sellerDashProvider),
          ),
        ],
      ),
      body: async.when(
        loading: () => _buildLoadingState(context),
        error: (e, _) => _buildErrorState(context, e, ref),
        data: (data) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(_sellerDashProvider),
          color: AppColors.primary,
          child: CustomScrollView(
            slivers: [
              // Stats Grid
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: _buildStatsGrid(context, ref, data),
                ),
              ),
              // Quick Actions
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: _buildQuickActions(context, ref, data),
                ),
              ),
              // Low Stock Alert
              if (data.lowStock > 0)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: _buildLowStockAlert(context, ref, data),
                  ),
                ),
              // Recent Orders
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: _buildRecentOrders(context, ref, data),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildShimmerCard(context),
        const SizedBox(height: 12),
        _buildShimmerCard(context),
        const SizedBox(height: 12),
        _buildShimmerCard(context),
        const SizedBox(height: 24),
        _buildShimmerCard(context, height: 120),
      ],
    );
  }

  Widget _buildShimmerCard(BuildContext context, {double height = 100}) {
    final p = context.palette;
    return Card(
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [p.surfaceMuted, p.surfaceMuted.withValues(alpha: 0.5)],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error, WidgetRef ref) {
    final p = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              'Failed to load dashboard',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: p.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(color: p.textMuted),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => ref.invalidate(_sellerDashProvider),
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context, WidgetRef ref, _DashboardData data) {
    final stats = [
      _StatItem(
        label: 'Total Sales',
        value: Formatters.formatCurrency(data.sales),
        icon: Icons.trending_up_rounded,
        gradient: const LinearGradient(
          colors: [Color(0xFF00C9A7), Color(0xFF00BF9B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        iconColor: Colors.white,
        onTap: () =>
            ref.read(mainTabIndexProvider.notifier).setIndex(3),
      ),
      _StatItem(
        label: 'Pending Orders',
        value: data.pending.toString(),
        icon: Icons.pending_actions_rounded,
        gradient: const LinearGradient(
          colors: [Color(0xFFFFB800), Color(0xFFFFA500)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        iconColor: Colors.white,
        onTap: () =>
            ref.read(mainTabIndexProvider.notifier).setIndex(2),
      ),
      _StatItem(
        label: 'Total Products',
        value: data.totalProducts.toString(),
        icon: Icons.inventory_2_rounded,
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        iconColor: Colors.white,
        onTap: () =>
            ref.read(mainTabIndexProvider.notifier).setIndex(1),
      ),
      _StatItem(
        label: 'Active Products',
        value: data.activeProducts.toString(),
        icon: Icons.check_circle_rounded,
        gradient: const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF059669)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        iconColor: Colors.white,
        onTap: () =>
            ref.read(mainTabIndexProvider.notifier).setIndex(1),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.1,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) => _StatCard(stat: stats[index]),
    );
  }

  Widget _buildQuickActions(BuildContext context, WidgetRef ref, _DashboardData data) {
    final p = context.palette;
    final actions = [
      _QuickAction(
        label: 'Add Product',
        icon: Icons.add_rounded,
        color: AppColors.primary,
        onTap: () => context.push(RouteNames.addProduct),
      ),
      _QuickAction(
        label: 'Manage Orders',
        icon: Icons.receipt_long_rounded,
        color: const Color(0xFF6366F1),
        onTap: () => ref.read(mainTabIndexProvider.notifier).setIndex(2),
        badge: data.pending > 0 ? data.pending.toString() : null,
      ),
      _QuickAction(
        label: 'View Products',
        icon: Icons.inventory_rounded,
        color: const Color(0xFF10B981),
        onTap: () => ref.read(mainTabIndexProvider.notifier).setIndex(1),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: p.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            // Responsive columns: 2 on narrow, 3 on medium, 4 on wide
            final crossAxisCount = constraints.maxWidth < 400
                ? 2
                : constraints.maxWidth < 600
                    ? 3
                    : 4;
            final childAspectRatio = constraints.maxWidth < 400 ? 0.9 : 0.85;

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: childAspectRatio,
              ),
              itemCount: actions.length,
              itemBuilder: (context, index) =>
                  _QuickActionCard(action: actions[index]),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLowStockAlert(BuildContext context, WidgetRef ref, _DashboardData data) {
    final p = context.palette;
    final displayProducts = data.lowStockProducts.take(3).toList();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      color: AppColors.warning.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Low Stock Alert',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: p.textPrimary,
                        ),
                      ),
                      Text(
                        '${data.lowStock} product${data.lowStock == 1 ? '' : 's'} need restocking',
                        style: TextStyle(fontSize: 12, color: p.textMuted),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => ref.read(mainTabIndexProvider.notifier).setIndex(1),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...displayProducts.map((product) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _LowStockItem(product: product),
            )),
            if (data.lowStockProducts.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '+ ${data.lowStockProducts.length - 3} more...',
                  style: TextStyle(fontSize: 12, color: p.textMuted),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentOrders(BuildContext context, WidgetRef ref, _DashboardData data) {
    final p = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Recent Orders',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: p.textPrimary,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => ref.read(mainTabIndexProvider.notifier).setIndex(2),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (data.recentOrders.isEmpty)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: p.divider),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.receipt_long_outlined, size: 48, color: p.iconMuted),
                  const SizedBox(height: 12),
                  Text(
                    'No orders yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: p.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Orders from buyers will appear here',
                    style: TextStyle(fontSize: 13, color: p.textMuted),
                  ),
                ],
              ),
            ),
          )
        else
          ...data.recentOrders.map((order) => _RecentOrderCard(order: order)),
      ],
    );
  }
}

class _StatItem {
  final String label;
  final String value;
  final IconData icon;
  final Gradient gradient;
  final Color iconColor;
  final VoidCallback? onTap;

  _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.gradient,
    required this.iconColor,
    this.onTap,
  });
}

class _StatCard extends StatelessWidget {
  final _StatItem stat;

  const _StatCard({required this.stat});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: stat.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(gradient: stat.gradient),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(stat.icon, color: stat.iconColor, size: 24),
              ),
              const Spacer(),
              Text(
                stat.value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: stat.iconColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                stat.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: stat.iconColor.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAction {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? badge;

  _QuickAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.badge,
  });
}

class _QuickActionCard extends StatelessWidget {
  final _QuickAction action;

  const _QuickActionCard({required this.action});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: p.divider),
      ),
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: action.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(action.icon, color: action.color, size: 24),
                  ),
                  if (action.badge != null)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(minWidth: 18),
                        child: Text(
                          action.badge!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                action.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: p.textPrimary,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LowStockItem extends StatelessWidget {
  final ProductModel product;

  const _LowStockItem({required this.product});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isOutOfStock = product.stockQuantity == 0;

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: p.surfaceMuted,
            borderRadius: BorderRadius.circular(8),
          ),
          child: product.imageUrl.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    product.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Icon(Icons.local_shipping_outlined, color: p.iconMuted, size: 20),
                  ),
                )
              : Icon(Icons.local_shipping_outlined, color: p.iconMuted, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: p.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                'Stock: ${product.stockQuantity} ${product.unit}',
                style: TextStyle(
                  fontSize: 11,
                  color: isOutOfStock ? AppColors.error : AppColors.warning,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isOutOfStock
                ? AppColors.error.withValues(alpha: 0.12)
                : AppColors.warning.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isOutOfStock
                  ? AppColors.error.withValues(alpha: 0.4)
                  : AppColors.warning.withValues(alpha: 0.4),
            ),
          ),
          child: Text(
            isOutOfStock ? 'Out of Stock' : 'Low Stock',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isOutOfStock ? AppColors.error : AppColors.warning,
            ),
          ),
        ),
      ],
    );
  }
}

class _RecentOrderCard extends StatelessWidget {
  final OrderModel order;

  const _RecentOrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final earnings = order.sellerEarnings > 0
        ? order.sellerEarnings
        : order.totalAmount - order.commissionAmount;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: p.divider),
      ),
      child: InkWell(
        onTap: () => context.push(RouteNames.sellerOrderDetailWithId(order.id)),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Status indicator
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _getStatusColor(order.status),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              // Order info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.orderNumber,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: p.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      order.items.firstOrNull?.product.name ?? 'Products',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: p.textMuted),
                    ),
                  ],
                ),
              ),
              // Earnings + status
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      Formatters.formatCurrency(earnings),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getStatusColor(order.status).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _getStatusLabel(order.status),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _getStatusColor(order.status),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return AppColors.warning;
      case OrderStatus.confirmed:
        return const Color(0xFF3B82F6);
      case OrderStatus.processing:
        return AppColors.primary;
      case OrderStatus.readyForDelivery:
        return const Color(0xFF8B5CF6);
      case OrderStatus.dispatched:
      case OrderStatus.inTransit:
        return const Color(0xFF06B6D4);
      case OrderStatus.delivered:
      case OrderStatus.completed:
        return AppColors.success;
      case OrderStatus.cancelled:
      case OrderStatus.refunded:
        return AppColors.error;
    }
  }

  String _getStatusLabel(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.confirmed:
        return 'Confirmed';
      case OrderStatus.processing:
        return 'Processing';
      case OrderStatus.readyForDelivery:
        return 'Ready';
      case OrderStatus.dispatched:
        return 'Dispatched';
      case OrderStatus.inTransit:
        return 'In Transit';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.completed:
        return 'Completed';
      case OrderStatus.cancelled:
        return 'Cancelled';
      case OrderStatus.refunded:
        return 'Refunded';
    }
  }
}