// Repro for: buyer Profile tab shows a TypeError instead of the profile.
// Pumps the REAL UserProfileScreen as a logged-in buyer; any exception
// during build/layout fails the test with the exact stack trace.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sitedrop_core/data/models/user.dart';
import 'package:sitedrop_buyer/presentation/providers/auth_provider.dart';
import 'package:sitedrop_buyer/presentation/screens/profile/user/profile_screen.dart';

class _FakeAuthedAuth extends AuthNotifier {
  _FakeAuthedAuth(this.user);

  final User user;

  @override
  Future<AuthState> build() async => AuthState.authenticated(user);
}

void main() {
  testWidgets('profile screen builds for logged-in buyer (no TypeError)',
      (tester) async {
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
        ],
        child: const MaterialApp(
          home: UserProfileScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Sample Buyer'), findsOneWidget);
    expect(find.text('Orders'), findsWidgets);
    expect(find.text('Logout'), findsOneWidget);
  });
}
