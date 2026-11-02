import '../../core/utils/app_logger.dart';
// lib/data/services/order_service.dart

import '../../core/constants/api_constants.dart';
import '../../core/constants/app_constants.dart';
import '../models/cart_item.dart';
import '../models/delivery.dart';
import '../models/order.dart';
import '../models/tracking.dart';
import 'api_service.dart';

class OrderService {
  static Future<List<OrderModel>> fetchOrders() async {
    try {
      final response = await ApiService.get<Map<String, dynamic>>(
        ApiConstants.orders,
      );

      // API returns: { status: 'success', data: { orders: [...] } }
      final data = response['data'] as Map<String, dynamic>? ?? {};
      final ordersData = data['orders'] as List<dynamic>? ?? [];

      AppLogger.d('📦 Orders fetched: ${ordersData.length}');

      return ordersData
          .whereType<Map<String, dynamic>>()
          .map((json) => OrderModel.fromJson(json))
          .toList();
    } catch (e) {
      AppLogger.e('❌ Error fetching orders: $e');
      return const [];
    }
  }

  static Future<OrderModel?> fetchOrder(String orderId) async {
    try {
      final response = await ApiService.get<Map<String, dynamic>>(
        '${ApiConstants.orders}/$orderId',
      );

      // Debug: Print the full response structure
      AppLogger.d('📦 Order API Response: $response');

      // API returns: { status: 'success', data: { order: {...}, timeline, … } }
      final data = response['data'] as Map<String, dynamic>? ?? {};
      AppLogger.d('📦 Data keys: ${data.keys}');

      // ✅ Detail shape (order + timeline siblings) → single model.
      if (data['order'] is Map<String, dynamic>) {
        final order = OrderModel.fromDetailJson(data);
        AppLogger.i('✅ Order fetched: ${order.id}');
        return order;
      }

      // ✅ Flat fallback (older payloads).
      if (data.isNotEmpty) {
        return OrderModel.fromJson(data);
      }
      return null;
    } catch (e) {
      AppLogger.e('❌ Error fetching order: $e');
      return null;
    }
  }

  /// `GET /orders/{id}/timeline` — refresh journey feed for live tracker.
  static Future<List<OrderTimelineEvent>> fetchTimeline(String orderId) async {
    try {
      final response = await ApiService.get<Map<String, dynamic>>(
        ApiConstants.orderTimeline.replaceAll('{id}', orderId),
      );
      final data = response['data'] as Map<String, dynamic>? ?? {};
      final raw = data['timeline'] as List<dynamic>? ?? [];
      return raw
          .whereType<Map>()
          .map((e) => OrderTimelineEvent.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      AppLogger.e('❌ Error fetching timeline: $e');
      return const [];
    }
  }

  /// Update order status (seller/admin) — returns success map for UI
  static Future<Map<String, dynamic>> updateOrderStatus({
    required String orderId,
    required String status,
    String? cancellationReason,
  }) async {
    try {
      final response = await ApiService.put<Map<String, dynamic>>(
        '${ApiConstants.orders}/$orderId/status',
        data: {'status': status, 'cancellation_reason': cancellationReason},
      );

      if (response['status'] == 'success') {
        final data = response['data'] as Map<String, dynamic>? ?? {};
        final orderData = data['order'] as Map<String, dynamic>? ?? data;
        return {
          'success': true,
          'message': 'Order status updated',
          if (orderData.isNotEmpty) 'order': OrderModel.fromJson(orderData),
        };
      }

      return {
        'success': false,
        'message': response['message'] ?? 'Failed to update order status',
      };
    } catch (e) {
      AppLogger.e('❌ Error updating order status: $e');
      return {
        'success': false,
        'message': 'Failed to update order status: ${e.toString()}',
      };
    }
  }

  /// Cancel order (seller) — returns success map for UI
  static Future<Map<String, dynamic>> cancelOrder({
    required String orderId,
    required String reason,
  }) async {
    try {
      final response = await ApiService.post<Map<String, dynamic>>(
        '${ApiConstants.orders}/$orderId/cancel',
        data: {'cancellation_reason': reason},
      );

      if (response['status'] == 'success') {
        return {'success': true, 'message': 'Order cancelled'};
      }

      return {
        'success': false,
        'message': response['message'] ?? 'Failed to cancel order',
      };
    } catch (e) {
      AppLogger.e('❌ Error cancelling order: $e');
      return {
        'success': false,
        'message': 'Failed to cancel order: ${e.toString()}',
      };
    }
  }

  static Future<OrderModel> placeOrder({
    required List<CartItemModel> items,
    required String deliveryAddress,
    required String deliveryPhone,
    required String paymentMethod,
    required String notes,
    required double latitude,
    required double longitude,
    String? phoneNumber,
    String? network,
  }) async {
    try {
      // Map payment method to API value if it's a display name
      String apiPaymentMethod = paymentMethod;
      if (AppConstants.paymentMethodApiMap.containsKey(paymentMethod)) {
        apiPaymentMethod = AppConstants.paymentMethodApiMap[paymentMethod]!;
      }

      final response = await ApiService.post<Map<String, dynamic>>(
        ApiConstants.checkoutPlaceOrder,
        data: {
          'delivery_address': deliveryAddress,
          'delivery_phone': deliveryPhone,
          'payment_method': apiPaymentMethod,
          'notes': notes,
          'latitude': latitude,
          'longitude': longitude,
          // Mobile Money payer wallet (required by CheckoutRequest).
          if (phoneNumber != null && phoneNumber.trim().isNotEmpty)
            'phone_number': phoneNumber.trim(),
          if (network != null && network.trim().isNotEmpty)
            'network': network.trim(),
        },
      );

      if (response['status'] == 'success') {
        final data = response['data'] as Map<String, dynamic>? ?? {};
        return OrderModel.fromCheckoutJson(data);
      }

      throw Exception(response['message'] ?? 'Unable to place order');
    } catch (e) {
      throw Exception('Failed to place order: ${e.toString()}');
    }
  }

  // Get order statistics
  static Future<Map<String, dynamic>> getOrderStatistics() async {
    try {
      final response = await ApiService.get<Map<String, dynamic>>(
        '${ApiConstants.orders}/statistics',
      );

      if (response['status'] == 'success') {
        return response['data'] as Map<String, dynamic>? ?? {};
      }
      return {};
    } catch (e) {
      AppLogger.e('❌ Error fetching order statistics: $e');
      return {};
    }
  }

  // Get seller orders
  static Future<List<OrderModel>> fetchSellerOrders({
    String? status,
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (status != null) queryParams['status'] = status;
      queryParams['page'] = page.toString();
      queryParams['per_page'] = perPage.toString();

      final response = await ApiService.get<Map<String, dynamic>>(
        '${ApiConstants.orders}/seller',
        queryParams: queryParams,
      );

      final data = response['data'] as Map<String, dynamic>? ?? {};
      final ordersData = data['orders'] as List<dynamic>? ?? [];

      return ordersData
          .whereType<Map<String, dynamic>>()
          .map((json) => OrderModel.fromJson(json))
          .toList();
    } catch (e) {
      AppLogger.e('❌ Error fetching seller orders: $e');
      return const [];
    }
  }

  /// Fetch delivery for a given order id (buyer tracking).
  static Future<DeliveryModel?> fetchDeliveryForOrder(String orderId) async {
    try {
      final response = await ApiService.get<Map<String, dynamic>>(
        '${ApiConstants.deliveries}?order_id=$orderId',
      );
      final candidates = _extractDeliveryMaps(response['data']);

      // Prefer the delivery belonging to this order; fall back to first.
      Map<String, dynamic>? match;
      for (final d in candidates) {
        if (d['order_id']?.toString() == orderId) {
          match = d;
          break;
        }
      }
      match ??= candidates.isNotEmpty ? candidates.first : null;

      if (match != null && match.isNotEmpty) {
        return DeliveryModel.fromJson(match);
      }
      return null;
    } catch (e) {
      AppLogger.e('❌ Error fetching delivery for order $orderId: $e');
      return null;
    }
  }

  /// Accept every envelope shape the API may return: a bare list,
  /// `{delivery: {...}}`, `{deliveries: [...]}`, or a bare delivery object.
  /// Never throws on unexpected shapes — returns an empty list instead.
  static List<Map<String, dynamic>> _extractDeliveryMaps(dynamic data) {
    Map<String, dynamic>? asMap(dynamic e) {
      if (e is Map<String, dynamic>) {
        return e;
      }
      if (e is Map) {
        return Map<String, dynamic>.from(e);
      }
      return null;
    }

    if (data is List) {
      return data.map(asMap).whereType<Map<String, dynamic>>().toList();
    }
    if (data is Map) {
      final nested = data['delivery'] ?? data['deliveries'];
      if (nested is List) {
        return nested.map(asMap).whereType<Map<String, dynamic>>().toList();
      }
      final nestedMap = asMap(nested);
      if (nestedMap != null && nestedMap.isNotEmpty) {
        return [nestedMap];
      }
      // Bare delivery object (has delivery-ish keys)?
      if (data.containsKey('order_id') ||
          data.containsKey('tracking_number')) {
        final bare = asMap(data);
        if (bare != null && bare.isNotEmpty) {
          return [bare];
        }
      }
    }
    return const [];
  }
}
