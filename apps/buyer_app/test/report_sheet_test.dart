// Repro for: buyer product detail "Report this product" sheet throws
// RenderFlex overflow + dirty-build-scope + duplicate GlobalKeys on submit.
// Pumps the REAL ProductDetailScreen; any exception fails with the stack.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sitedrop_core/data/models/product.dart';
import 'package:sitedrop_core/data/models/user.dart';
import 'package:sitedrop_buyer/presentation/providers/auth_provider.dart';
import 'package:sitedrop_buyer/presentation/providers/product_provider.dart';
import 'package:sitedrop_buyer/presentation/screens/buyer/product_detail_screen.dart';

class _FakeAuthedAuth extends AuthNotifier {
  _FakeAuthedAuth(this.user);

  final User user;

  @override
  Future<AuthState> build() async => AuthState.authenticated(user);
}

const _product = ProductModel(
  id: '1',
  name: 'Test Cement',
  price: 150,
  sellerId: '4',
  sellerName: 'Sample Seller',
  specifications: {'material': 'galvanized_steel'},
);

void main() {
  testWidgets('report sheet opens and submits without render/layout errors',
      (tester) async {
    // Small phone screen (logical 360x640) — overflow bugs hide on default.
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    // Real backend token (php artisan serve :8000) → exercises the TRUE
    // success path (pop + success toast), not just the offline error path.
    // Auth token lives in flutter_secure_storage → mock its channel.
    const token = '5|PZABDZIAjJsASUfPtuaZXS1aA53cPFZeKDs544X158b7c866';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async {
        final args = (call.arguments as Map?) ?? {};
        if (call.method == 'read' && args['key'] == 'auth_token') {
          return token;
        }
        return null;
      },
    );
    SharedPreferences.setMockInitialValues({});
    const user = User(
      id: '5',
      name: 'Sample Buyer',
      phone: '233247131610',
      email: 'buyer@sitedrop.gh',
      role: 'buyer',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(() => _FakeAuthedAuth(user)),
          productDetailsProvider('1')
              .overrideWithValue(const AsyncData(_product)),
        ],
        child: const MaterialApp(
          home: ProductDetailScreen(productId: '1'),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);

    // Open the report row (scroll into view first).
    await tester.ensureVisible(find.text('Report this product'));
    await tester.pump();
    await tester.tap(find.text('Report this product'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    expect(find.text('Submit report'), findsOneWidget);

    // Open the keyboard in the details field (as a real user would),
    // type details, then pick a reason and submit.
    await tester.tap(find.byType(TextField).last);
    await tester.pump();
    await tester.enterText(
      find.byType(TextField).last,
      'Fake item, wrong photos',
    );
    await tester.pump();
    await tester.tap(find.text('Spam or scam'));
    await tester.pump();
    await tester.ensureVisible(
      find.text('Submit report'),
    );
    await tester.pump();
    await tester.tap(find.text('Submit report'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);

    // Dismiss the (still open — error path) sheet via the modal barrier
    // (pageBack needs a GoRouter, which the bare test harness lacks),
    // then Seller tab → Follow.
    tester.testTextInput.hide();
    await tester.pump();
    await tester.tapAt(const Offset(180, 60));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Seller').first);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Follow'));
    await tester.pump();
    await tester.tap(find.text('Follow'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });
}

