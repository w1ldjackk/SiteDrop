// lib/presentation/providers/reviews_provider.dart
// Ratings & Reviews: my feed + orders still awaiting a rating.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sitedrop_core/sitedrop_core.dart';

import 'order_provider.dart';

/// Reviews I wrote (products + orders/trips).
final myReviewsProvider =
    FutureProvider.autoDispose<List<MyReviewModel>>((ref) {
  return ReviewService.fetchMyReviews();
});

/// Delivered/completed orders with no order review yet → "To review".
/// Matches `mine` by order id (server is source of truth for reviewed).
final pendingReviewOrdersProvider =
    FutureProvider.autoDispose<List<OrderModel>>((ref) async {
  final orders = await ref.watch(ordersProvider.future);
  final mine = await ref.watch(myReviewsProvider.future);
  final reviewedOrderIds = {
    for (final r in mine)
      if (r.orderId != null && r.orderId!.isNotEmpty) r.orderId!,
  };
  return orders
      .where((o) =>
          o.isCompleted &&
          !reviewedOrderIds.contains(o.id) &&
          (o.serverCanReview ?? true))
      .toList();
});
