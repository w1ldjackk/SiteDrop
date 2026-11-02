// lib/data/services/review_service.dart
// My reviews feed + order/trip (seller + driver) ratings.

import '../../core/constants/api_constants.dart';
import '../../core/utils/app_logger.dart';
import '../models/review.dart';
import 'api_service.dart';

class ReviewService {
  /// `GET /reviews/mine` — reviews I wrote (products + orders/trips).
  static Future<List<MyReviewModel>> fetchMyReviews() async {
    try {
      final response = await ApiService.get<Map<String, dynamic>>(
        ApiConstants.reviewsMine,
      );
      final data = response['data'] as Map<String, dynamic>? ?? {};
      final raw = data['reviews'] as List<dynamic>? ?? [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(MyReviewModel.fromJson)
          .toList();
    } catch (e) {
      AppLogger.e('❌ Error fetching my reviews: $e');
      return const [];
    }
  }

  /// Rate a delivered order: seller stars + optional driver (trip) stars.
  /// Returns (ok, message).
  static Future<(bool, String)> submitOrderReview(
    String orderId, {
    required int rating,
    String? comment,
    int? driverRating,
    String? driverComment,
  }) async {
    try {
      final body = <String, dynamic>{
        'rating': rating.clamp(1, 5),
        if (comment != null && comment.trim().isNotEmpty)
          'comment': comment.trim(),
        if (driverRating != null) 'driver_rating': driverRating.clamp(1, 5),
        if (driverComment != null && driverComment.trim().isNotEmpty)
          'driver_comment': driverComment.trim(),
      };
      final response = await ApiService.post<Map<String, dynamic>>(
        ApiConstants.orderReview(orderId),
        data: body,
      );
      final ok = response['status'] == 'success';
      return (
        ok,
        response['message']?.toString() ??
            (ok ? 'Thanks for your review!' : 'Could not submit review')
      );
    } catch (e) {
      AppLogger.e('❌ Error submitting order review: $e');
      return (false, 'Could not submit review. Please try again.');
    }
  }
}
