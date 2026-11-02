// Regression test for the buyer Profile TypeError:
// two concurrent identical GETs share one in-flight future (coalescing).
// Both callers must resolve with the same payload — the second caller
// must NOT throw `type 'Future<dynamic>' is not a subtype of ...`.
//
// Self-contained: a fake Dio adapter answers the request so the test does
// not need a running backend (CI-safe).
import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sitedrop_core/data/services/api_service.dart';

class _CountingAdapter implements HttpClientAdapter {
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    // Small delay so the two calls really overlap in-flight.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return ResponseBody.fromString(
      jsonEncode({
        'status': 'success',
        'data': {'data': <dynamic>[]},
      }),
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
  test('concurrent identical GETs both resolve (coalescing)', () async {
    TestWidgetsFlutterBinding.ensureInitialized();

    // Stub secure storage (public endpoint needs no token).
    const channel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);

    final originalAdapter = ApiService.dio.httpClientAdapter;
    final adapter = _CountingAdapter();
    ApiService.dio.httpClientAdapter = adapter;

    try {
      ApiService.ensureInitialized();

      // Same endpoint + same query => same coalescing key, overlapping
      // in-flight so the second caller joins the first future.
      final results = await Future.wait([
        ApiService.get<Map<String, dynamic>>(
          '/products/listings',
          queryParams: {'per_page': 1},
        ),
        ApiService.get<Map<String, dynamic>>(
          '/products/listings',
          queryParams: {'per_page': 1},
        ),
      ]);

      for (final r in results) {
        expect(r['status'], 'success');
      }
      // Coalescing means only one request actually hit the network.
      expect(adapter.calls, 1);
    } finally {
      ApiService.dio.httpClientAdapter = originalAdapter;
    }
  });
}
