// lib/presentation/providers/tracking_provider.dart
// Live tracker data: journey timeline + buyer delivery snapshot.
// Polling is owned by the tracking screen (30s while order is active).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sitedrop_core/sitedrop_core.dart';

import 'order_provider.dart';

/// Journey feed: embedded timeline from order detail first,
/// refreshed from `GET /orders/{id}/timeline`.
final orderTimelineProvider = FutureProvider.autoDispose
    .family<List<OrderTimelineEvent>, String>((ref, orderId) async {
  final fresh = await OrderService.fetchTimeline(orderId);
  if (fresh.isNotEmpty) return fresh;
  // Fallback: embedded timeline already parsed into the order detail.
  final order = await ref.watch(orderDetailsProvider(orderId).future);
  return order?.timeline ?? const [];
});

/// Buyer delivery snapshot matched by order_id (`GET /deliveries`).
/// Null = no delivery yet (order still being prepared).
final deliveryForOrderProvider = FutureProvider.autoDispose
    .family<DeliveryModel?, String>((ref, orderId) {
  return OrderService.fetchDeliveryForOrder(orderId);
});
