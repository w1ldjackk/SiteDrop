// lib/presentation/screens/seller/seller_order_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sitedrop_core/app/routes/route_names.dart';
import 'package:sitedrop_core/app/theme/colors.dart';
import 'package:sitedrop_core/core/utils/display_names.dart';
import 'package:sitedrop_core/core/utils/formatters.dart';
import 'package:sitedrop_core/core/utils/helpers.dart';
import 'package:sitedrop_core/data/models/cart_item.dart';
import 'package:sitedrop_core/data/models/order.dart';
import 'package:sitedrop_core/data/models/tracking.dart';
import 'package:sitedrop_core/data/services/order_service.dart';
import 'package:sitedrop_core/presentation/widgets/cards/order_status_chip.dart';
import '../../widgets/common/app_back_button.dart';
import '../../widgets/common/loading_widget.dart';
import '../../providers/order_provider.dart';

class SellerOrderDetailScreen extends ConsumerWidget {
  final String orderId;

  const SellerOrderDetailScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderDetailsProvider(orderId));

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        backgroundColor: context.palette.surface,
        elevation: 0,
        title: appBarTitle(context, 'Order Detail'),
        leading: const AppBackButton(fallbackRoute: RouteNames.orderManagement),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(orderDetailsProvider(orderId)),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: orderAsync.when(
        data: (order) {
          if (order == null) {
            return _buildNotFound(context);
          }
          return _buildOrderDetail(context, ref, order);
        },
        loading: () => const LoadingWidget(message: 'Loading order…'),
        error: (error, stack) => _buildErrorState(context, error, ref),
      ),
    );
  }

  Widget _buildNotFound(BuildContext context) {
    final p = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined, size: 64, color: p.iconMuted),
            const SizedBox(height: 16),
            Text(
              'Order not found',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: p.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This order may have been removed',
              style: TextStyle(color: p.textMuted, fontSize: 15),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.go(RouteNames.orderManagement),
              child: const Text('Back to Orders'),
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
              onPressed: () => ref.invalidate(orderDetailsProvider(orderId)),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderDetail(BuildContext context, WidgetRef ref, OrderModel order) {
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(orderDetailsProvider(orderId)),
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStatusCard(context, order),
          const SizedBox(height: 16),
          _buildInfoCard(context, order),
          const SizedBox(height: 16),
          _buildItemsCard(context, order),
          const SizedBox(height: 16),
          _buildFinancialCard(context, order),
          const SizedBox(height: 16),
          if (order.deliveryAddress.isNotEmpty) ...[
            _buildDeliveryCard(context, order),
            const SizedBox(height: 16),
          ],
          if (order.timeline.isNotEmpty) ...[
            _buildTimelineCard(context, order),
            const SizedBox(height: 16),
          ],
          _buildActions(context, ref, order),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, OrderModel order) {
    final p = context.palette;
    final earnings = order.sellerEarnings > 0
        ? order.sellerEarnings
        : order.totalAmount - order.commissionAmount;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: p.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.orderNumber,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: p.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  OrderStatusChip(status: order.status),
                  const SizedBox(height: 8),
                  Text(
                    'Placed ${Formatters.formatDateTime(order.createdAt)}',
                    style: TextStyle(fontSize: 12, color: p.textMuted),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
              ),
              child: Column(
                children: [
                  Text(
                    'Your Earnings',
                    style: TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    Formatters.formatCurrency(earnings),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, OrderModel order) {
    final p = context.palette;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: p.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order Information', style: _sectionStyle(p)),
            const SizedBox(height: 12),
            _infoRow(p, 'Payment Method', order.paymentMethod),
            _infoRow(p, 'Payment Status', order.paymentStatus.toUpperCase()),
            _infoRow(p, 'Order ID', order.id),
            if (order.notes.isNotEmpty) _infoRow(p, 'Notes', order.notes),
            if (order.specialInstructions?.isNotEmpty == true)
              _infoRow(p, 'Special Instructions', order.specialInstructions!),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsCard(BuildContext context, OrderModel order) {
    final p = context.palette;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: p.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Items (${order.items.length})', style: _sectionStyle(p)),
            const SizedBox(height: 12),
            for (int i = 0; i < order.items.length; i++) ...[
              _buildItemRow(context, order.items[i]),
              if (i != order.items.length - 1) const Divider(height: 24),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildItemRow(BuildContext context, CartItemModel item) {
    final p = context.palette;
    final product = item.product;

    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: p.surfaceMuted,
            borderRadius: BorderRadius.circular(10),
          ),
          child: product.imageUrl.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    product.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Icon(Icons.inventory_2_outlined, color: p.iconMuted),
                  ),
                )
              : Icon(Icons.inventory_2_outlined, color: p.iconMuted),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w600, color: p.textPrimary),
              ),
              Text(
                '${product.category} • ${Formatters.formatCurrency(product.price)} per ${product.unit}',
                style: TextStyle(fontSize: 12, color: p.textMuted),
              ),
              const SizedBox(height: 4),
              Text(
                'Qty: ${item.quantity} • Subtotal: ${Formatters.formatCurrency(item.quantity * product.price)}',
                style: TextStyle(fontSize: 12, color: p.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFinancialCard(BuildContext context, OrderModel order) {
    final p = context.palette;
    final earnings = order.sellerEarnings > 0
        ? order.sellerEarnings
        : order.totalAmount - order.commissionAmount;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: p.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Financial Breakdown', style: _sectionStyle(p)),
            const SizedBox(height: 12),
            _financialRow(p, 'Order Total', Formatters.formatCurrency(order.totalAmount)),
            _financialRow(p, 'Delivery Fee', Formatters.formatCurrency(order.deliveryFee)),
            _financialRow(p, 'Service Fee', Formatters.formatCurrency(order.serviceFee)),
            const Divider(height: 16),
            _financialRow(p, 'Platform Commission', Formatters.formatCurrency(order.commissionAmount)),
            const Divider(height: 16),
            _financialRow(
              p,
              'Your Earnings',
              Formatters.formatCurrency(earnings),
              isTotal: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryCard(BuildContext context, OrderModel order) {
    final p = context.palette;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: p.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Delivery Details', style: _sectionStyle(p)),
                const Spacer(),
                if (order.deliveryLatitude != null && order.deliveryLongitude != null)
                  TextButton.icon(
                    onPressed: () {
                      // Could open map
                    },
                    icon: const Icon(Icons.map_outlined, size: 16),
                    label: const Text('View on Map'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _infoRow(p, 'Address', order.deliveryAddress),
            _infoRow(p, 'Phone', order.deliveryPhone),
            if (order.deliveryScheduledAt != null)
              _infoRow(p, 'Scheduled', Formatters.formatDateTime(order.deliveryScheduledAt!)),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineCard(BuildContext context, OrderModel order) {
    final p = context.palette;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: p.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Timeline', style: _sectionStyle(p)),
            const SizedBox(height: 12),
            for (int i = 0; i < order.timeline.length; i++) ...[
              _TimelineTile(
                event: order.timeline[i],
                isFirst: i == 0,
                isLast: i == order.timeline.length - 1,
                isCurrent: order.timeline[i].status == order.status.name,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context, WidgetRef ref, OrderModel order) {
    final actions = _getAvailableActions(context, order.status);

    if (actions.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: context.palette.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Actions', style: _sectionStyle(context.palette)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: actions.map((action) {
                return ActionButton(
                  label: action.label,
                  icon: action.icon,
                  color: action.color,
                  isDestructive: action.isDestructive,
                  onPressed: () => _handleAction(context, ref, action.value, order),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  List<_OrderAction> _getAvailableActions(BuildContext context, OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return [
          _OrderAction('Confirm', Icons.check_circle_outline, AppColors.success, 'confirm'),
          _OrderAction('Cancel', Icons.cancel_outlined, AppColors.error, 'cancel', isDestructive: true),
        ];
      case OrderStatus.confirmed:
        return [
          _OrderAction('Start Processing', Icons.inventory_2_outlined, AppColors.primary, 'process'),
          _OrderAction('Cancel', Icons.cancel_outlined, AppColors.error, 'cancel', isDestructive: true),
        ];
      case OrderStatus.processing:
        return [
          _OrderAction('Mark Ready for Delivery', Icons.local_shipping_outlined, AppColors.primary, 'ready'),
          _OrderAction('Cancel', Icons.cancel_outlined, AppColors.error, 'cancel', isDestructive: true),
        ];
      case OrderStatus.readyForDelivery:
        return [
          _OrderAction('View in Delivery', Icons.directions_car_outlined, AppColors.primary, 'view_delivery'),
        ];
      case OrderStatus.dispatched:
      case OrderStatus.inTransit:
      case OrderStatus.delivered:
        return [
          _OrderAction('View Delivery', Icons.directions_car_outlined, AppColors.primary, 'view_delivery'),
        ];
      default:
        return [];
    }
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    String action,
    OrderModel order,
  ) async {
    switch (action) {
      case 'confirm':
        await _updateStatus(context, ref, OrderStatus.confirmed);
        break;
      case 'process':
        await _updateStatus(context, ref, OrderStatus.processing);
        break;
      case 'ready':
        await _updateStatus(context, ref, OrderStatus.readyForDelivery);
        break;
      case 'cancel':
        await _confirmCancel(context, ref, order);
        break;
      case 'view_delivery':
        context.push(RouteNames.trackOrderWithId(order.id));
        break;
      case 'view':
        context.push(RouteNames.sellerOrderDetailWithId(order.id));
        break;
    }
  }

  Future<void> _updateStatus(
    BuildContext context,
    WidgetRef ref,
    OrderStatus newStatus,
  ) async {
    try {
      final result = await OrderService.updateOrderStatus(
        orderId: orderId,
        status: newStatus.name,
      );
      if (!context.mounted) return;
      if (result['success'] == true) {
        Helpers.showSuccessToast('Order ${DisplayNames.deliveryStatusLabel(newStatus.name)}');
        ref.invalidate(orderDetailsProvider(orderId));
        ref.invalidate(sellerOrdersProvider);
      } else {
        Helpers.showErrorToast(result['message'] ?? 'Failed to update order');
      }
    } catch (e) {
      if (context.mounted) {
        Helpers.showErrorToast(Helpers.errorMessage(e));
      }
    }
  }

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref, OrderModel order) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Cancel order?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('This will notify the buyer and release the items.'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Reason (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Keep order'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('Cancel order'),
            ),
          ],
        );
      },
    );

    if (reason != null && context.mounted) {
      try {
        final result = await OrderService.cancelOrder(
          orderId: orderId,
          reason: reason,
        );
        if (!context.mounted) return;
        if (result['success'] == true) {
          Helpers.showSuccessToast('Order cancelled');
          ref.invalidate(orderDetailsProvider(orderId));
          ref.invalidate(sellerOrdersProvider);
        } else {
          Helpers.showErrorToast(result['message'] ?? 'Failed to cancel order');
        }
      } catch (e) {
        if (context.mounted) {
          Helpers.showErrorToast(Helpers.errorMessage(e));
        }
      }
    }
  }

  TextStyle _sectionStyle(AppPalette p) => TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w800,
    color: p.textPrimary,
  );

  Widget _infoRow(AppPalette p, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: p.textMuted, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: p.textPrimary, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _financialRow(AppPalette p, String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: isTotal ? 15 : 13,
                fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
                color: isTotal ? p.textPrimary : p.textSecondary,
              ),
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
                fontSize: isTotal ? 16 : 13,
                fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
                color: isTotal ? AppColors.success : p.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isDestructive;
  final VoidCallback onPressed;

  const ActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    this.isDestructive = false,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16, color: color),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

class _OrderAction {
  final String label;
  final IconData icon;
  final Color color;
  final String value;
  final bool isDestructive;

  _OrderAction(
    this.label,
    this.icon,
    this.color,
    this.value, {
    this.isDestructive = false,
  });
}

class _TimelineTile extends StatelessWidget {
  final OrderTimelineEvent event;
  final bool isFirst;
  final bool isLast;
  final bool isCurrent;

  const _TimelineTile({
    required this.event,
    required this.isFirst,
    required this.isLast,
    this.isCurrent = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    // IntrinsicHeight bounds the vertical axis so the Expanded connector
    // line below gets finite constraints even inside a ListView.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: isCurrent ? AppColors.primary : p.textMuted,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isCurrent ? AppColors.primary : p.divider,
                    width: 2,
                  ),
                ),
                child: isCurrent
                    ? const Icon(Icons.check, size: 12, color: Colors.white)
                    : null,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isCurrent ? AppColors.primary : p.divider,
                    margin: const EdgeInsets.only(left: 9),
                  ),
                ),
            ],
          ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 14,
                    color: isCurrent ? p.textPrimary : p.textSecondary,
                  ),
                ),
                if (event.description.isNotEmpty && event.description != event.label) ...[
                  const SizedBox(height: 2),
                  Text(
                    event.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: p.textMuted),
                  ),
                ],
                if (event.createdAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    Formatters.formatDateTime(event.createdAt!),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: p.textMuted),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
      ),
    );
  }
}