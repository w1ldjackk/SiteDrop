// lib/presentation/widgets/buyer/order_status_chip.dart
import 'package:flutter/material.dart';

import 'package:sitedrop_core/app/theme/colors.dart';
import 'package:sitedrop_core/data/models/order.dart';

class OrderStatusChip extends StatelessWidget {
  final OrderStatus status;

  const OrderStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      OrderStatus.pending => ('Pending', AppColors.warning),
      OrderStatus.confirmed => ('Confirmed', AppColors.info),
      OrderStatus.processing => ('Processing', AppColors.info),
      OrderStatus.readyForDelivery => ('Ready for delivery', AppColors.primary),
      OrderStatus.dispatched => ('Dispatched', AppColors.secondary),
      OrderStatus.inTransit => ('In transit', AppColors.primary),
      OrderStatus.delivered => ('Delivered', AppColors.success),
      OrderStatus.completed => ('Completed', AppColors.success),
      OrderStatus.cancelled => ('Cancelled', AppColors.error),
      OrderStatus.refunded => ('Refunded', AppColors.grey600),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
