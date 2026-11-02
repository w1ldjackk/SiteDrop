// Tests for DeliveryService methods against fake Dio adapter.
// No live backend required — CI-safe.

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sitedrop_core/data/services/api_service.dart';
import 'package:sitedrop_core/data/services/delivery_service.dart';

class _FakeAdapter implements HttpClientAdapter {
  Map<String, dynamic> response;

  _FakeAdapter({required this.response});

  int calls = 0;
  String? lastPath;
  Map<String, dynamic>? lastBody;

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
  group('DeliveryService', () {
    late _FakeAdapter adapter;
    final originalAdapter = ApiService.dio.httpClientAdapter;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();

      const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => 'fake-token');

      adapter = _FakeAdapter(
        response: {'status': 'success', 'data': {'offers': []}},
      );

      ApiService.dio.httpClientAdapter = adapter;
      addTearDown(() => ApiService.dio.httpClientAdapter = originalAdapter);
    });

    test('fetchOffers returns empty list', () async {
      adapter.response = {
        'status': 'success',
        'data': {'offers': []},
      };

      final offers = await DeliveryService.fetchOffers();

      expect(offers, isEmpty);
      expect(adapter.calls, 1);
      expect(adapter.lastPath, '/deliveries/offers');
    });

    test('acceptOffer returns success', () async {
      adapter.response = {'status': 'success', 'message': 'Trip accepted'};

      final (ok, message) = await DeliveryService.acceptOffer('offer-1');

      expect(ok, isTrue);
      expect(message, 'Trip accepted');
      expect(adapter.calls, 1);
      expect(adapter.lastPath, '/deliveries/offers/offer-1/accept');
    });

    test('declineOffer returns success', () async {
      adapter.response = {'status': 'success', 'message': 'Offer declined'};

      final (ok, message) = await DeliveryService.declineOffer('offer-1');

      expect(ok, isTrue);
      expect(message, 'Offer declined');
      expect(adapter.calls, 1);
      expect(adapter.lastPath, '/deliveries/offers/offer-1/decline');
    });

    test('fetchMyDeliveries returns list', () async {
      adapter.response = {
        'status': 'success',
        'data': {'deliveries': [
          {'id': 1, 'tracking_number': 'TRK-001', 'status': 'assigned'},
        ]},
      };

      final deliveries = await DeliveryService.fetchMyDeliveries();

      expect(deliveries, hasLength(1));
      expect(adapter.calls, 1);
      expect(adapter.lastPath, '/deliveries');
    });

    test('updateStatus returns success for in_transit', () async {
      adapter.response = {'status': 'success', 'message': 'Delivery updated'};

      final (ok, message) = await DeliveryService.updateStatus('delivery-1', 'in_transit');

      expect(ok, isTrue);
      expect(message, 'Delivery updated');
      expect(adapter.calls, 1);
      expect(adapter.lastPath, '/deliveries/delivery-1/status');
      expect(adapter.lastBody?['status'], 'in_transit');
    });

    test('postLocation returns success', () async {
      adapter.response = {'status': 'success', 'message': 'Location updated'};

      final ok = await DeliveryService.postLocation('delivery-1', 5.6037, -0.1870);

      expect(ok, isTrue);
      expect(adapter.calls, 1);
      expect(adapter.lastPath, '/deliveries/delivery-1/location');
      expect(adapter.lastBody?['lat'], 5.6037);
      expect(adapter.lastBody?['lng'], -0.1870);
    });

    test('setPresence online returns success', () async {
      adapter.response = {'status': 'success', 'message': 'You are online'};

      final (ok, message) = await DeliveryService.setPresence(online: true, lat: 5.6037, lng: -0.1870);

      expect(ok, isTrue);
      expect(message, 'You are online');
      expect(adapter.calls, 1);
      expect(adapter.lastPath, '/deliveries/presence');
      expect(adapter.lastBody?['is_online'], true);
    });
  });
}