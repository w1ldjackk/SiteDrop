// Parses the REAL backend responses for every payload the buyer
// Profile screen depends on (/user, /profile/stats, /wishlist, /cart).
// Any TypeError from real data fails here with the exact stack trace.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:sitedrop_core/data/models/cart_item.dart';
import 'package:sitedrop_core/data/models/product.dart';
import 'package:sitedrop_core/data/models/user.dart';
import 'package:sitedrop_buyer/presentation/providers/profile_stats_provider.dart';

const _base = 'http://localhost:8000/api/v1';

Future<Map<String, dynamic>> _post(
    HttpClient client, String path, Map<String, dynamic> body,
    {String? token}) async {
  final req = await client.postUrl(Uri.parse('$_base$path'));
  req.headers.contentType = ContentType.json;
  req.headers.set('Accept', 'application/json');
  if (token != null) req.headers.set('Authorization', 'Bearer $token');
  req.write(jsonEncode(body));
  final res = await req.close();
  final text = await res.transform(utf8.decoder).join();
  if (res.statusCode >= 400) {
    throw StateError('$path -> ${res.statusCode}: $text');
  }
  return jsonDecode(text) as Map<String, dynamic>;
}

Future<Map<String, dynamic>> _get(HttpClient client, String path,
    {String? token}) async {
  final req = await client.getUrl(Uri.parse('$_base$path'));
  req.headers.set('Accept', 'application/json');
  if (token != null) req.headers.set('Authorization', 'Bearer $token');
  final res = await req.close();
  final text = await res.transform(utf8.decoder).join();
  if (res.statusCode >= 400) {
    throw StateError('$path -> ${res.statusCode}: $text');
  }
  final decoded = jsonDecode(text);
  if (decoded is Map<String, dynamic>) return decoded;
  throw StateError('$path returned non-object JSON');
}

void main() {
  test('real buyer payloads parse without TypeError', () async {
    final client = HttpClient();
    try {
      Map<String, dynamic> login;
      try {
        login = await _post(client, '/auth/login',
                {'login': 'buyer@sitedrop.gh', 'password': 'password'})
            .timeout(const Duration(seconds: 15));
      } on SocketException catch (_) {
        markTestSkipped('Backend not running on localhost:8000');
        return;
      } on TimeoutException catch (_) {
        markTestSkipped('Backend not reachable on localhost:8000');
        return;
      }
      final token = login['token'] as String;
      expect(token.isNotEmpty, isTrue);

      // /user -> User.fromJson (auth state behind the profile screen).
      final me = await _get(client, '/user', token: token);
      final userData =
          (me['data'] as Map<String, dynamic>)['user'] as Map<String, dynamic>;
      final user = User.fromJson(userData);
      expect(user.id.isNotEmpty, isTrue);

      // /profile/stats -> ProfileStats.fromJson (stats row on the screen).
      final statsRes = await _get(client, '/profile/stats', token: token);
      final stats = ProfileStats.fromJson(
          statsRes['data'] as Map<String, dynamic>);
      expect(stats.ordersCount, greaterThanOrEqualTo(0));

      // /wishlist -> ProductModel list (wishlist count on the screen).
      final wish = await _get(client, '/wishlist', token: token);
      final wdata = wish['data'];
      final witems = wdata is Map<String, dynamic>
          ? (wdata['wishlist'] ?? wdata['items'] ?? []) as List
          : (wdata as List);
      for (final item in witems) {
        ProductModel.fromJson(
            Map<String, dynamic>.from(item as Map));
      }

      // /cart -> CartItemModel list (session bootstrap parses this too).
      final cart = await _get(client, '/cart', token: token);
      final cdata = cart['data'] as Map<String, dynamic>?;
      final citems =
          (cdata?['cart'] as Map<String, dynamic>?)?['items'] as List? ??
              const [];
      for (final item in citems) {
        CartItemModel.fromJson(
            Map<String, dynamic>.from(item as Map));
      }
    } finally {
      client.close();
    }
  });
}
