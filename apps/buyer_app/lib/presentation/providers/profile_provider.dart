// lib/presentation/providers/profile_provider.dart
// Full account profile (user + UserProfile map) for Edit Profile.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sitedrop_core/sitedrop_core.dart';

/// GET /profile → (user, profile). Auto-refresh after save/avatar change.
final userProfileProvider = FutureProvider.autoDispose<
    ({Map<String, dynamic> user, Map<String, dynamic> profile})>((ref) {
  return ProfileService.fetchProfile();
});
