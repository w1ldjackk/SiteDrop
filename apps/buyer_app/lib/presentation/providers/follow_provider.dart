// lib/presentation/providers/follow_provider.dart
// Buyer → seller follow state per seller.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sitedrop_core/data/services/follow_service.dart';
import 'package:sitedrop_core/data/services/storage_service.dart';

final sellerFollowProvider = FutureProvider.autoDispose
    .family<FollowStatus, String>((ref, sellerId) async {
  if (sellerId.isEmpty) {
    return const FollowStatus(following: false, followersCount: 0);
  }
  final token = await StorageService.getAuthToken();
  if (token == null || token.isEmpty) {
    return const FollowStatus(following: false, followersCount: 0);
  }
  try {
    return await FollowService.status(sellerId);
  } catch (_) {
    return const FollowStatus(following: false, followersCount: 0);
  }
});

/// Toggle follow and refresh the cached status. Returns server message.
Future<(bool, String)> toggleSellerFollow(
  WidgetRef ref,
  String sellerId,
) async {
  final (ok, message, _) = await FollowService.toggle(sellerId);
  ref.invalidate(sellerFollowProvider(sellerId));
  return (ok, message);
}
