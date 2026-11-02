// Exercises the REAL provider data-stack behind the buyer Profile
// screen against the REAL backend: login -> AuthService.getCurrentUser,
// profile/stats, inbox, wishlist, orders. Any TypeError from real data
// fails here with the exact stack trace.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sitedrop_core/data/services/address_service.dart';
import 'package:sitedrop_core/data/services/api_service.dart';
import 'package:sitedrop_core/data/services/auth_service.dart';
import 'package:sitedrop_core/data/services/inbox_notification_service.dart';
import 'package:sitedrop_core/data/services/instrument_service.dart';
import 'package:sitedrop_core/data/services/order_service.dart';
import 'package:sitedrop_core/data/services/review_service.dart';
import 'package:sitedrop_core/data/services/wallet_service.dart';
import 'package:sitedrop_core/data/services/wishlist_service.dart';
import 'package:sitedrop_buyer/presentation/providers/profile_stats_provider.dart';

const _base = 'http://localhost:8000/api/v1';

Future<String?> _loginToken() async {
  final client = HttpClient();
  try {
    final req = await client.postUrl(Uri.parse('$_base/auth/login'));
    req.headers.contentType = ContentType.json;
    req.headers.set('Accept', 'application/json');
    req.write(jsonEncode(
        {'login': 'buyer@sitedrop.gh', 'password': 'password'}));
    final res = await req.close().timeout(const Duration(seconds: 15));
    final body = await res.transform(utf8.decoder).join();
    return (jsonDecode(body) as Map)['token'] as String?;
  } finally {
    client.close();
  }
}

void main() {
  test('real profile data-stack parses without TypeError', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});

    // Widget binding mocks HttpClient (400s) — stash the mock and use
    // the real network for this backend-backed test, restore at the end.
    final httpMock = HttpOverrides.current;
    HttpOverrides.global = null;
    try {
      late final String token;
      try {
        final t = await _loginToken();
        if (t == null || t.isEmpty) {
          markTestSkipped('Login did not return a token');
          return;
        }
        token = t;
      } on SocketException catch (_) {
        markTestSkipped('Backend not running on localhost:8000');
        return;
      } on TimeoutException catch (_) {
        markTestSkipped('Backend not reachable on localhost:8000');
        return;
      }

    // Stub flutter_secure_storage so ApiService picks up the real token.
    const channel =
        MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      final args = call.arguments is Map
          ? Map<String, dynamic>.from(call.arguments as Map)
          : <String, dynamic>{};
      switch (call.method) {
        case 'read':
          if (args['key'] == 'auth_token') return token;
          return null;
        case 'write':
        case 'delete':
          return null;
        case 'readAll':
          return <String, String>{'auth_token': token};
        case 'containsKey':
          return args['key'] == 'auth_token';
        case 'deleteAll':
          return null;
        default:
          return null;
      }
    });

    ApiService.ensureInitialized();

    // 1. auth state behind the screen.
    final user = await AuthService.getCurrentUser();
    expect(user.id.isNotEmpty, isTrue);

    // 2. stats row.
    final statsRes = await ApiService.get<Map<String, dynamic>>(
      '/profile/stats',
    );
    final stats = ProfileStats.fromJson(
        Map<String, dynamic>.from(
            (statsRes['data'] as Map?) ?? const {}));
    expect(stats.ordersCount, greaterThanOrEqualTo(0));

    // 3. bell badge in the profile app bar.
    final inbox = await InboxNotificationService.fetchInbox();
    expect(inbox.unreadCount, greaterThanOrEqualTo(0));

    // 4. wishlist count.
    final wishlist = await WishlistService.fetchWishlist();
    expect(wishlist, isNotNull);

    // 5. orders list (same source the hub screens poll).
    final orders = await OrderService.fetchOrders();
    expect(orders, isNotNull);

    // 6. every destination reachable from the profile menu.
    final book = await AddressService.withDefaultClient().getAddressBook();
    expect(book.addresses, isNotNull);
    final instruments = await InstrumentService.fetchMine();
    expect(instruments, isNotNull);
    final wallet = await WalletService.fetchWallet();
    expect(wallet, isNotNull);
    final reviews = await ReviewService.fetchMyReviews();
    expect(reviews, isNotNull);
    } finally {
      HttpOverrides.global = httpMock;
    }
  });
}
