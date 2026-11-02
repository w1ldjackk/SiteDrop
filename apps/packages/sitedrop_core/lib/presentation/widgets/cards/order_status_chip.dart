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
      OrderStatus.confirmed => ('Confirmed', AppColors.primary),
      OrderStatus.processing => ('Processing', AppColors.info),
      OrderStatus.readyForDelivery => ('Ready for delivery', AppColors.primary),
      OrderStatus.dispatched => ('On the way', const Color(0xFF7C3AED)),
      OrderStatus.inTransit => ('In transit', AppColors.primary),
      OrderStatus.delivered => ('Delivered', AppColors.success),
      OrderStatus.completed => ('Completed', AppColors.success),
      OrderStatus.cancelled => ('Cancelled', const Color(0xFFDC2626)),
      OrderStatus.refunded => ('Refunded', AppColors.grey600),
    };

    return Chip(
      label: Text(label),
      backgroundColor: color.withAlpha(36),
      side: BorderSide(color: color.withAlpha(51)),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w600),
    );
  }
}
