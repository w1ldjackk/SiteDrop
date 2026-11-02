// lib/presentation/providers/preferences_provider.dart
// Account preferences (language, notification matrix) + 2FA status.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sitedrop_core/sitedrop_core.dart';

/// Raw preferences map from the server (merged with defaults).
final userPreferencesProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  return PreferencesService.getPreferences();
});

/// Two-factor state for the Security section.
final twoFactorProvider =
    FutureProvider.autoDispose<({bool enabled, bool confirmed})>((ref) {
  return SecurityService.twoFactorStatus();
});

/// Save one preference key, then refresh. Throws on failure.
Future<void> savePreference(
  WidgetRef ref,
  String key,
  dynamic value,
) async {
  await PreferencesService.updatePreferences({key: value});
  ref.invalidate(userPreferencesProvider);
}
