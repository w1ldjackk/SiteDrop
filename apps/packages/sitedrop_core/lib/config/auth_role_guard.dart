// Which account roles may sign in to the running role app.
//
// Each store binary (buyer / seller / driver via `--dart-define=APP_ROLE=…`)
// only accepts its own role: a seller account cannot sign in to the buyer
// or driver app, and vice versa. Rejected attempts fail with a
// human-readable message naming the correct app.
import '../data/models/user.dart';
import 'app_config.dart';
import 'app_flavor.dart';

class AuthRoleGuard {
  /// Roles allowed in the currently running app (exactly its own role).
  static Set<String> get allowedRoles => <String>{AppConfig.roleName};

  /// True when [user] may stay signed in to this app.
  static bool isAllowed(User user) => allowedRoles.contains(user.role);

  /// Display name of the store app that owns [role].
  static String appNameFor(String role) => switch (role) {
        'seller' => 'SiteDrop Seller',
        'driver' => 'SiteDrop Driver',
        'buyer' => 'SiteDrop',
        'admin' || 'super-admin' => 'SiteDrop Admin',
        _ => 'SiteDrop',
      };

  /// Display name of the currently running app.
  static String get currentAppName => switch (AppConfig.flavor) {
        AppFlavor.buyer => 'SiteDrop',
        AppFlavor.seller => 'SiteDrop Seller',
        AppFlavor.driver => 'SiteDrop Driver',
      };

  /// Throws a user-facing [Exception] when [user] belongs to another app.
  static void ensureAllowed(User user) {
    if (isAllowed(user)) return;
    throw Exception(
      'This is a ${user.role} account (for ${appNameFor(user.role)}). '
      'Please sign in with the $currentAppName app.',
    );
  }
}
