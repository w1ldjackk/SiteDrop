// lib/presentation/screens/seller/order_management_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sitedrop_core/app/routes/route_names.dart';
import 'package:sitedrop_core/app/theme/colors.dart';
import 'package:sitedrop_core/core/utils/display_names.dart';
import 'package:sitedrop_core/core/utils/formatters.dart';
import 'package:sitedrop_core/core/utils/helpers.dart';
import 'package:sitedrop_core/data/models/order.dart';
import 'package:sitedrop_core/data/services/order_service.dart';
import 'package:sitedrop_core/presentation/widgets/cards/order_status_chip.dart';
import '../../widgets/common/app_back_button.dart';
import '../../widgets/common/loading_widget.dart';
import '../../providers/order_provider.dart';

class OrderManagementScreen extends ConsumerWidget {
  const OrderManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(sellerOrdersProvider);

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        backgroundColor: context.palette.surface,
        elevation: 0,
        title: appBarTitle(context, 'Manage Orders'),
        leading: const AppBackButton(fallbackRoute: RouteNames.sellerDashboard),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(sellerOrdersProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ordersAsync.when(
        data: (orders) {
          if (orders.isEmpty) {
            return _buildEmptyState(context);
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(sellerOrdersProvider),
            color: AppColors.primary,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final order = orders[index];
                return _OrderManagementCard(order: order);
              },
            ),
          );
        },
        loading: () => const LoadingWidget(message: 'Loading orders…'),
        error: (error, stack) => _buildErrorState(context, error, ref),
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
                Icons.receipt_long_outlined,
                size: 60,
                color: p.iconMuted,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No orders yet',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: p.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Orders from buyers will appear here',
              style: TextStyle(color: p.textMuted, fontSize: 15),
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
              onPressed: () => ref.invalidate(sellerOrdersProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderManagementCard extends ConsumerWidget {
  final OrderModel order;

  const _OrderManagementCard({required this.order});

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
        onTap: () => context.push(RouteNames.sellerOrderDetailWithId(order.id)),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Order number, status, earnings
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.orderNumber,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: p.textPrimary,
                      ),
                    ),
                  ),
                  OrderStatusChip(status: order.status),
                ],
              ),
              const SizedBox(height: 8),
              // Buyer info
              Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 16,
                    color: p.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      order.items.firstOrNull?.product.name ?? 'Products',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: p.textSecondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Earnings + date
              Row(
                children: [
                  Flexible(
                    child: EarningsChip(amount: order.sellerEarnings > 0
                        ? order.sellerEarnings
                        : order.totalAmount - order.commissionAmount),
                  ),
                  const Spacer(),
                  Flexible(
                    child: Text(
                      Formatters.formatDate(order.createdAt),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: p.textMuted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Action buttons based on status
              _buildActions(context, ref),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context, WidgetRef ref) {
    final actions = _getAvailableActions(context, order.status);

    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: actions.map((action) {
        return ActionButton(
          label: action.label,
          icon: action.icon,
          color: action.color,
          isDestructive: action.isDestructive,
          onPressed: () => _handleAction(context, ref, action.value),
        );
      }).toList(),
    );
  }

  List<_OrderAction> _getAvailableActions(BuildContext context, OrderStatus status) {
    final p = context.palette;
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
      case OrderStatus.completed:
        return [
          _OrderAction('View Details', Icons.info_outline, p.iconMuted, 'view'),
        ];
      case OrderStatus.cancelled:
      case OrderStatus.refunded:
        return [
          _OrderAction('View Details', Icons.info_outline, p.iconMuted, 'view'),
        ];
    }
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    String action,
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
        await _confirmCancel(context, ref);
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
        orderId: order.id,
        status: newStatus.name,
      );
      if (!context.mounted) return;
      if (result['success'] == true) {
        Helpers.showSuccessToast('Order ${DisplayNames.deliveryStatusLabel(newStatus.name)}');
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

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
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
          orderId: order.id,
          reason: reason,
        );
        if (!context.mounted) return;
        if (result['success'] == true) {
          Helpers.showSuccessToast('Order cancelled');
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
}

class EarningsChip extends StatelessWidget {
  final double amount;

  const EarningsChip({super.key, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.account_balance_wallet_outlined, size: 14, color: AppColors.success),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              'You earn: ${Formatters.formatCurrency(amount)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.success,
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