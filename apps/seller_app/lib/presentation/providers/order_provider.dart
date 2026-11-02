// lib/presentation/providers/order_provider.dart

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sitedrop_core/data/models/cart_item.dart';
import 'package:sitedrop_core/data/models/delivery.dart';
import 'package:sitedrop_core/data/models/order.dart';
import 'package:sitedrop_core/data/models/tracking.dart';
import 'package:sitedrop_core/data/services/order_service.dart';

final ordersProvider = AsyncNotifierProvider<OrdersNotifier, List<OrderModel>>(
  OrdersNotifier.new,
);

final orderProvider = ordersProvider;

final orderDetailsProvider = FutureProvider.autoDispose
    .family<OrderModel?, String>((ref, orderId) {
  return OrderService.fetchOrder(orderId);
});

final orderTimelineProvider = FutureProvider.autoDispose
    .family<List<OrderTimelineEvent>, String>((ref, orderId) {
  return OrderService.fetchTimeline(orderId);
});

final deliveryForOrderProvider = FutureProvider.autoDispose
    .family<DeliveryModel?, String>((ref, orderId) {
  return OrderService.fetchDeliveryForOrder(orderId);
});

// Seller's orders provider
final sellerOrdersProvider = FutureProvider.autoDispose<List<OrderModel>>((ref) {
  return OrderService.fetchSellerOrders();
});

class OrdersNotifier extends AsyncNotifier<List<OrderModel>> {
  @override
  Future<List<OrderModel>> build() async {
    try {
      return await OrderService.fetchOrders();
    } catch (e) {
      return const [];
    }
  }

  Future<void> refreshOrders() async {
    state = const AsyncLoading<List<OrderModel>>();
    try {
      final orders = await OrderService.fetchOrders();
      state = AsyncData(orders);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }

  Future<Map<String, dynamic>> placeOrder({
    required List<CartItemModel> items,
    required String deliveryAddress,
    required String deliveryPhone,
    required String paymentMethod,
    required String notes,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final order = await OrderService.placeOrder(
        items: items,
        deliveryAddress: deliveryAddress,
        deliveryPhone: deliveryPhone,
        paymentMethod: paymentMethod,
        notes: notes,
        latitude: latitude,
        longitude: longitude,
      );

      final currentOrders = state.value ?? const [];
      state = AsyncData([order, ...currentOrders]);

      return {
        'order': order,
        'paymentData': order.paymentData,
        'nextSteps': order.nextSteps,
      };
    } catch (e) {
      // Re-throw the error to be caught in the UI
      throw Exception(e.toString());
    }
  }
}
