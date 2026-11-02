// Tests for OrderService methods against fake Dio adapter.
// No live backend required — CI-safe.

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sitedrop_core/data/services/api_service.dart';
import 'package:sitedrop_core/data/services/order_service.dart';

class _FakeAdapter implements HttpClientAdapter {
  Map<String, dynamic> response;

  _FakeAdapter({required this.response});

  int calls = 0;
  String? lastPath;
  Map<String, dynamic>? lastBody;
  Map<String, dynamic>? lastQuery;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    lastPath = options.path;
    if (options.data != null) {
      lastBody = options.data is Map ? Map<String, dynamic>.from(options.data) : null;
    }
    lastQuery = Map<String, dynamic>.from(options.queryParameters);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    return ResponseBody.fromString(
      jsonEncode(response),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('OrderService', () {
    late _FakeAdapter adapter;
    final originalAdapter = ApiService.dio.httpClientAdapter;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();

      // Stub secure storage
      const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => 'fake-token');

      adapter = _FakeAdapter(
        response: {
          'status': 'success',
          'data': {'orders': [], 'pagination': {'current_page': 1, 'last_page': 1, 'per_page': 20, 'total': 0}},
        },
      );

      ApiService.dio.httpClientAdapter = adapter;
      addTearDown(() => ApiService.dio.httpClientAdapter = originalAdapter);
    });

    test('fetchOrders returns list', () async {
      adapter.response = {
        'status': 'success',
        'data': {
          'orders': [
            {'id': 1, 'order_number': 'ORD-001', 'status': 'pending', 'total_amount': 100.0},
          ],
          'pagination': {'current_page': 1, 'last_page': 1, 'per_page': 20, 'total': 1}
        },
      };

      final orders = await OrderService.fetchOrders();

      expect(orders, hasLength(1));
      expect(orders.first.orderNumber, 'ORD-001');
      expect(adapter.calls, 1);
      expect(adapter.lastPath, '/orders');
    });

    test('fetchOrder returns single order', () async {
      adapter.response = {
        'status': 'success',
        'data': {
          'order': {'id': 1, 'order_number': 'ORD-001', 'status': 'pending', 'total_amount': 100.0},
        },
      };

      final order = await OrderService.fetchOrder('1');

      expect(order, isNotNull);
      expect(order!.orderNumber, 'ORD-001');
      expect(adapter.calls, 1);
      expect(adapter.lastPath, '/orders/1');
    });

    test('updateOrderStatus returns success', () async {
      adapter.response = {
        'status': 'success',
        'message': 'Order status updated',
        'data': {'order': {'id': 1, 'order_number': 'ORD-001', 'status': 'confirmed'}},
      };

      final result = await OrderService.updateOrderStatus(
        orderId: '1',
        status: 'confirmed',
      );

      expect(result['success'], isTrue);
      expect(adapter.calls, 1);
      expect(adapter.lastPath, '/orders/1/status');
      expect(adapter.lastBody?['status'], 'confirmed');
    });

    test('cancelOrder returns success', () async {
      adapter.response = {
        'status': 'success',
        'message': 'Order cancelled',
      };

      final result = await OrderService.cancelOrder(
        orderId: '1',
        reason: 'No longer needed',
      );

      expect(result['success'], isTrue);
      expect(adapter.calls, 1);
      expect(adapter.lastPath, '/orders/1/cancel');
      expect(adapter.lastBody?['cancellation_reason'], 'No longer needed');
    });

    test('placeOrder returns order', () async {
      adapter.response = {
        'status': 'success',
        'data': {
          'order': {'id': 42, 'order_number': 'ORD-042', 'status': 'pending', 'total_amount': 100.0},
        },
      };

      final order = await OrderService.placeOrder(
        items: [],
        deliveryAddress: '123 Main St',
        deliveryPhone: '+233540000000',
        paymentMethod: 'Cash on Delivery',
        notes: '',
        latitude: 5.6037,
        longitude: -0.1870,
      );

      expect(order.orderNumber, 'ORD-042');
      expect(adapter.calls, 1);
      expect(adapter.lastPath, '/checkout/place-order');
      // Payment method should be mapped to API value
      expect(adapter.lastBody?['payment_method'], 'cash_on_delivery');
    });

    test('getOrderStatistics returns stats', () async {
      adapter.response = {
        'status': 'success',
        'data': {'total': 10, 'completed': 5, 'pending': 3},
      };

      final stats = await OrderService.getOrderStatistics();

      expect(stats['total'], 10);
      expect(stats['completed'], 5);
      expect(stats['pending'], 3);
      expect(adapter.calls, 1);
      expect(adapter.lastPath, '/orders/statistics');
    });

    test('fetchSellerOrders returns seller orders', () async {
      adapter.response = {
        'status': 'success',
        'data': {
          'orders': [
            {'id': 1, 'order_number': 'ORD-001', 'status': 'pending', 'total_amount': 200.0},
          ],
        },
      };

      final orders = await OrderService.fetchSellerOrders();

      expect(orders, hasLength(1));
      expect(orders.first.orderNumber, 'ORD-001');
      expect(adapter.calls, 1);
      expect(adapter.lastPath, '/orders/seller');
    });
  });
}