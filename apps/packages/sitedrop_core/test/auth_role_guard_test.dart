import 'package:flutter_test/flutter_test.dart';
import 'package:sitedrop_core/config/app_config.dart';
import 'package:sitedrop_core/config/auth_role_guard.dart';
import 'package:sitedrop_core/data/models/user.dart';

// Role separation: each store binary only accepts its own account role.
// Run once per flavor to cover all apps, e.g.:
//   flutter test --dart-define=APP_ROLE=buyer
//   flutter test --dart-define=APP_ROLE=seller
//   flutter test --dart-define=APP_ROLE=driver
void main() {
  User userWithRole(String role) =>
      User(id: '1', name: 'T', phone: '+233000000000', role: role);

  test('own role is allowed in this app (${AppConfig.roleName})', () {
    final user = userWithRole(AppConfig.roleName);
    expect(AuthRoleGuard.isAllowed(user), isTrue);
    expect(() => AuthRoleGuard.ensureAllowed(user), returnsNormally);
  });

  test('other store roles are rejected with the correct app name', () {
    const storeRoles = ['buyer', 'seller', 'driver'];
    final others =
        storeRoles.where((r) => r != AppConfig.roleName).toList();
    expect(others, hasLength(2));
    for (final role in others) {
      final user = userWithRole(role);
      expect(AuthRoleGuard.isAllowed(user), isFalse,
          reason: '$role must not sign in to ${AppConfig.roleName} app');
      expect(
        () => AuthRoleGuard.ensureAllowed(user),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains(AuthRoleGuard.appNameFor(role)),
        )),
      );
    }
  });
}
