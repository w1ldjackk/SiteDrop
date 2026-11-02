// lib/data/services/profile_service.dart
// Client for Laravel Api\ProfileController show/update.

import '../../core/constants/api_constants.dart';
import '../../core/utils/app_logger.dart';
import 'api_service.dart';

class ProfileService {
  ProfileService._();

  /// GET /profile → { user: {...}, profile: {...}|null }
  static Future<({Map<String, dynamic> user, Map<String, dynamic> profile})>
      fetchProfile() async {
    try {
      final response = await ApiService.get<Map<String, dynamic>>(
        ApiConstants.profile,
      );
      final data = response['data'] as Map<String, dynamic>? ?? {};
      Map<String, dynamic> mapOf(dynamic v) =>
          v is Map<String, dynamic> ? v : <String, dynamic>{};
      return (
        user: mapOf(data['user']),
        profile: mapOf(data['profile']),
      );
    } catch (e) {
      AppLogger.e('❌ Error fetching profile: $e');
      rethrow;
    }
  }

  /// PUT /profile — name + UserProfile fields. Unknown/empty values skipped.
  static Future<void> updateDetails(Map<String, dynamic> values) async {
    final body = <String, dynamic>{};
    for (final entry in values.entries) {
      final v = entry.value;
      if (v == null) continue;
      if (v is String && v.trim().isEmpty) continue;
      body[entry.key] = v is String ? v.trim() : v;
    }
    if (body.isEmpty) return;
    final response = await ApiService.put<Map<String, dynamic>>(
      ApiConstants.profile,
      data: body,
    );
    if (response['status'] != 'success') {
      throw Exception(
        response['message']?.toString() ?? 'Could not save profile',
      );
    }
  }
}
