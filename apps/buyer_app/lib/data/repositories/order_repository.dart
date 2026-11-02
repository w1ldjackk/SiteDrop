import 'package:sitedrop_core/core/utils/app_logger.dart';
// lib/data/repositories/order_repository.dart

import 'package:sitedrop_core/data/models/cart_item.dart';
import 'package:sitedrop_core/data/models/order.dart';
import 'package:sitedrop_core/data/services/order_service.dart';
import 'package:sitedrop_core/data/services/storage_service.dart';

class OrderRepository {
  static const String _ordersCacheKey = 'cached_orders';
  static const String _orderDetailsCachePrefix = 'order_detail_';

  // ============================================================
  // GET ORDERS
  // ============================================================

  /// Get all orders for the current user
  static Future<List<OrderModel>> getOrders({bool forceRefresh = false}) async {
    try {
      // Try to get from server
      final serverOrders = await OrderService.fetchOrders();

      // Cache the result
      await _cacheOrders(serverOrders);

      return serverOrders;
    } catch (e) {
      AppLogger.e('WARN:  Failed to fetch orders from server: $e');

      // If forceRefresh is true, don't use cache
      if (forceRefresh) {
        return [];
      }

      // Fallback to cached orders
      return _getCachedOrders();
    }
  }

  /// Get cached orders from local storage
  static Future<List<OrderModel>> _getCachedOrders() async {
    try {
      final cached = await StorageService.readSecure(_ordersCacheKey);
      if (cached != null && cached.isNotEmpty) {
        // For now, return empty list - implement proper JSON serialization later
        return [];
      }
    } catch (e) {
      AppLogger.e('WARN:  Failed to get cached orders: $e');
    }
    return [];
  }

  /// Cache orders to local storage
  static Future<void> _cacheOrders(List<OrderModel> orders) async {
    try {
      await StorageService.saveSecure(
        _ordersCacheKey,
        orders.length.toString(),
      );
    } catch (e) {
      AppLogger.e('WARN:  Failed to cache orders: $e');
    }
  }

  // ============================================================
  // GET ORDER DETAILS
  // ============================================================

  /// Get single order details by ID
  static Future<OrderModel?> getOrderDetails({
    required String orderId,
    bool forceRefresh = false,
  }) async {
    try {
      // Try to get from server
      final order = await OrderService.fetchOrder(orderId);

      if (order != null) {
        // Cache the order details
        await _cacheOrderDetails(orderId, order);
      }

      return order;
    } catch (e) {
      AppLogger.e('WARN:  Failed to fetch order details from server: $e');

      // If forceRefresh is true, don't use cache
      if (forceRefresh) {
        return null;
      }

      // Fallback to cached order details
      return _getCachedOrderDetails(orderId);
    }
  }

  /// Get cached order details from local storage
  static Future<OrderModel?> _getCachedOrderDetails(String orderId) async {
    try {
      final cacheKey = '$_orderDetailsCachePrefix$orderId';
      final cached = await StorageService.readSecure(cacheKey);
      if (cached != null && cached.isNotEmpty) {
        // For now, return null - implement proper JSON serialization later
        return null;
      }
    } catch (e) {
      AppLogger.e('WARN:  Failed to get cached order details: $e');
    }
    return null;
  }

  /// Cache order details to local storage
  static Future<void> _cacheOrderDetails(
    String orderId,
    OrderModel order,
  ) async {
    try {
      final cacheKey = '$_orderDetailsCachePrefix$orderId';
      await StorageService.saveSecure(cacheKey, order.id);
    } catch (e) {
      AppLogger.e('WARN:  Failed to cache order details: $e');
    }
  }

  // ============================================================
  // PLACE ORDER - FIXED: Changed List<dynamic> to List<CartItemModel>
  // ============================================================

  /// Place a new order
  static Future<OrderModel> placeOrder({
    required List<CartItemModel> items, // FIXED: Changed from List<dynamic>
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

      // Refresh orders cache after placing new order
      await getOrders(forceRefresh: true);

      return order;
    } catch (e) {
      AppLogger.e('ERR:  Failed to place order: $e');
      rethrow;
    }
  }

  // ============================================================
  // UPDATE ORDER STATUS
  // ============================================================

  /// Update order status (for sellers)
  static Future<OrderModel?> updateOrderStatus({
    required String orderId,
    required String status,
    String? cancellationReason,
  }) async {
    try {
      final result = await OrderService.updateOrderStatus(
        orderId: orderId,
        status: status,
        cancellationReason: cancellationReason,
      );

      if (result['success'] == true && result['order'] != null) {
        final order = result['order'] as OrderModel;
        // Refresh cache after update
        await _cacheOrderDetails(orderId, order);
        await getOrders(forceRefresh: true);
        return order;
      }

      return null;
    } catch (e) {
      AppLogger.e('ERR:  Failed to update order status: $e');
      return null;
    }
  }

  // ============================================================
  // CANCEL ORDER
  // ============================================================

  /// Cancel an order (for buyers)
  static Future<bool> cancelOrder({
    required String orderId,
    required String reason,
  }) async {
    try {
      final result = await OrderService.cancelOrder(
        orderId: orderId,
        reason: reason,
      );

      final success = result['success'] == true;

      if (success) {
        // Refresh cache after cancellation
        await getOrders(forceRefresh: true);
        // Clear cached order details
        await StorageService.deleteSecure('$_orderDetailsCachePrefix$orderId');
      }

      return success;
    } catch (e) {
      AppLogger.e('ERR:  Failed to cancel order: $e');
      return false;
    }
  }

  // ============================================================
  // ORDER STATISTICS
  // ============================================================

  /// Get order statistics for the current user
  static Future<Map<String, dynamic>> getStatistics() async {
    try {
      return await OrderService.getOrderStatistics();
    } catch (e) {
      AppLogger.e('WARN:  Failed to fetch order statistics: $e');
      return {};
    }
  }

  // ============================================================
  // SELLER ORDERS
  // ============================================================

  /// Get orders for a seller (for seller dashboard)
  static Future<List<OrderModel>> getSellerOrders({
    String? status,
    int page = 1,
    int perPage = 20,
    bool forceRefresh = false,
  }) async {
    try {
      final orders = await OrderService.fetchSellerOrders(
        status: status,
        page: page,
        perPage: perPage,
      );

      // Cache the result (with status as part of key)
      if (status != null) {
        await StorageService.saveSecure(
          'seller_orders_${status}_$page',
          orders.length.toString(),
        );
      }

      return orders;
    } catch (e) {
      AppLogger.e('WARN:  Failed to fetch seller orders: $e');

      if (forceRefresh) {
        return [];
      }

      // Try to get cached seller orders
      try {
        final cacheKey = status != null
            ? 'seller_orders_${status}_$page'
            : 'seller_orders_all_$page';
        final cached = await StorageService.readSecure(cacheKey);
        if (cached != null && cached.isNotEmpty) {
          // Return empty for now - implement proper serialization later
          return [];
        }
      } catch (cacheError) {
        AppLogger.e('WARN:  Failed to get cached seller orders: $cacheError');
      }

      return [];
    }
  }

  // ============================================================
  // HELPER METHODS
  // ============================================================

  /// Clear all order cache
  static Future<void> clearCache() async {
    try {
      await StorageService.deleteSecure(_ordersCacheKey);
      // Note: Would need to clear individual order caches too
      // For now, we just clear the main cache
    } catch (e) {
      AppLogger.e('WARN:  Failed to clear order cache: $e');
    }
  }

  /// Check if user has any orders
  static Future<bool> hasOrders() async {
    final orders = await getOrders();
    return orders.isNotEmpty;
  }

  /// Get order count
  static Future<int> getOrderCount() async {
    final orders = await getOrders();
    return orders.length;
  }

  /// Get pending order count
  static Future<int> getPendingOrderCount() async {
    final orders = await getOrders();
    return orders
        .where(
          (order) =>
              order.status == OrderStatus.pending ||
              order.status == OrderStatus.confirmed,
        )
        .length;
  }

  /// Get completed order count
  static Future<int> getCompletedOrderCount() async {
    final orders = await getOrders();
    return orders
        .where(
          (order) =>
              order.status == OrderStatus.completed ||
              order.status == OrderStatus.delivered,
        )
        .length;
  }

  /// Calculate total revenue from completed orders
  static Future<double> getTotalRevenue() async {
    final orders = await getOrders();
    double total = 0.0; // FIXED: Initialize with double
    for (var order in orders) {
      if (order.status == OrderStatus.completed) {
        total += order.totalAmount; // FIXED: Use += operator properly
      }
    }
    return total;
  }
}
