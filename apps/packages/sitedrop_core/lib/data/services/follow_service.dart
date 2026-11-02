// lib/data/services/follow_service.dart
// Buyer → seller follows + product reports.

import '../../core/utils/app_logger.dart';
import 'api_service.dart';
import '../../core/constants/api_constants.dart';

class FollowStatus {
  final bool following;
  final int followersCount;

  const FollowStatus({required this.following, required this.followersCount});

  factory FollowStatus.fromJson(Map<String, dynamic> json) {
    return FollowStatus(
      following: json['following'] == true,
      followersCount: int.tryParse('${json['followers_count'] ?? 0}') ?? 0,
    );
  }
}

class FollowService {
  static Future<FollowStatus> status(String sellerId) async {
    try {
      final response = await ApiService.get<Map<String, dynamic>>(
        '/sellers/$sellerId/follow-status',
      );
      final data = response['data'];
      if (data is Map<String, dynamic>) {
        return FollowStatus.fromJson(data);
      }
      return const FollowStatus(following: false, followersCount: 0);
    } catch (e) {
      AppLogger.e('❌ Error fetching follow status: $e');
      return const FollowStatus(following: false, followersCount: 0);
    }
  }

  static Future<(bool, String, FollowStatus?)> toggle(String sellerId) async {
    try {
      final response = await ApiService.post<Map<String, dynamic>>(
        '/sellers/$sellerId/follow',
      );
      final ok = response['status'] == 'success';
      final data = response['data'];
      final status = data is Map<String, dynamic>
          ? FollowStatus.fromJson(data)
          : null;
      return (
        ok,
        response['message']?.toString() ??
            (ok ? 'Updated' : 'Could not update follow'),
        status,
      );
    } catch (e) {
      AppLogger.e('❌ Error toggling follow: $e');
      return (false, 'Could not update follow — check connection', null);
    }
  }

  static Future<(bool, String)> reportProduct(
    String productId, {
    required String reason,
    String? details,
  }) async {
    try {
      final response = await ApiService.post<Map<String, dynamic>>(
        '${ApiConstants.productDetail(productId)}/report',
        data: {
          'reason': reason,
          if (details != null && details.trim().isNotEmpty)
            'details': details.trim(),
        },
      );
      final ok = response['status'] == 'success';
      return (
        ok,
        response['message']?.toString() ??
            (ok ? 'Report submitted' : 'Could not submit report'),
      );
    } catch (e) {
      AppLogger.e('❌ Error reporting product: $e');
      return (false, 'Could not submit report — check connection');
    }
  }
}
