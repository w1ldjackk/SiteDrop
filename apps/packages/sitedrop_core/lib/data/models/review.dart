// lib/data/models/review.dart

import '../../core/constants/api_constants.dart';
class ReviewModel {
  final String id;
  final int rating;
  final String comment;
  final bool isVerifiedPurchase;
  final int helpfulCount;
  final DateTime? createdAt;
  final String reviewerId;
  final String reviewerName;
  final String? reviewerAvatar;

  const ReviewModel({
    required this.id,
    required this.rating,
    this.comment = '',
    this.isVerifiedPurchase = false,
    this.helpfulCount = 0,
    this.createdAt,
    this.reviewerId = '',
    this.reviewerName = 'Buyer',
    this.reviewerAvatar,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    final reviewer = json['reviewer'] as Map<String, dynamic>?;
    final rawAvatar =
        reviewer?['avatar']?.toString() ?? reviewer?['avatar_url']?.toString();
    return ReviewModel(
      id: json['id']?.toString() ?? '',
      rating: _asInt(json['rating'], 0).clamp(0, 5),
      comment: (json['comment'] ?? '').toString(),
      isVerifiedPurchase: json['is_verified_purchase'] == true ||
          json['is_verified_purchase'] == 1 ||
          json['is_verified_purchase'] == '1',
      helpfulCount: _asInt(json['helpful_count'], 0),
      createdAt: _asDate(json['created_at']),
      reviewerId: reviewer?['id']?.toString() ??
          json['reviewer_id']?.toString() ??
          '',
      reviewerName: reviewer?['name']?.toString() ??
          json['reviewer_name']?.toString() ??
          'Buyer',
      reviewerAvatar: rawAvatar == null || rawAvatar.isEmpty
          ? rawAvatar
          : ApiConstants.resolveAssetUrl(rawAvatar),
    );
  }

  String get initials {
    final parts = reviewerName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'B';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  static int _asInt(dynamic v, int fallback) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is double) return v.round();
    return int.tryParse(v.toString()) ?? fallback;
  }

  static DateTime? _asDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }
}

class ReviewSummary {  final double averageRating;
  final int total;

  const ReviewSummary({
    this.averageRating = 0,
    this.total = 0,
  });

  factory ReviewSummary.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ReviewSummary();
    final avg = json['average_rating'] ?? json['avg_rating'] ?? 0;
    final total = json['total'] ?? json['total_reviews'] ?? 0;
    return ReviewSummary(
      averageRating: avg is num
          ? avg.toDouble()
          : double.tryParse(avg.toString()) ?? 0,
      total: total is int
          ? total
          : int.tryParse(total.toString()) ?? 0,
    );
  }
}

/// One row of `GET /reviews/mine` — the review I wrote, with context
/// (product for product reviews, order for order/trip reviews).
class MyReviewModel {
  final String id;
  final String type;
  final int rating;
  final String comment;
  final String status;
  final bool isVerifiedPurchase;
  final DateTime? createdAt;

  final String? productId;
  final String? productName;
  final String? orderId;
  final String? orderNumber;
  final String? orderStatus;
  final String? revieweeName;

  const MyReviewModel({
    required this.id,
    required this.type,
    required this.rating,
    this.comment = '',
    this.status = 'published',
    this.isVerifiedPurchase = false,
    this.createdAt,
    this.productId,
    this.productName,
    this.orderId,
    this.orderNumber,
    this.orderStatus,
    this.revieweeName,
  });

  bool get isProductReview => productId != null && productId!.isNotEmpty;
  bool get isOrderReview => orderId != null && orderId!.isNotEmpty;

  /// Human context line: product name or order number + seller.
  String get subject {
    if (isProductReview) return productName ?? 'Product';
    final order = orderNumber ?? 'Order';
    if (revieweeName != null && revieweeName!.trim().isNotEmpty) {
      return '$order · $revieweeName';
    }
    return order;
  }

  factory MyReviewModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? mapOf(dynamic v) =>
        v is Map ? Map<String, dynamic>.from(v) : null;
    final product = mapOf(json['product']);
    final order = mapOf(json['order']);
    final reviewee = mapOf(json['reviewee']);
    return MyReviewModel(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      rating: ReviewModel._asInt(json['rating'], 0).clamp(0, 5),
      comment: (json['comment'] ?? '').toString(),
      status: json['status']?.toString() ?? 'published',
      isVerifiedPurchase: json['is_verified_purchase'] == true ||
          json['is_verified_purchase'] == 1 ||
          json['is_verified_purchase'] == '1',
      createdAt: ReviewModel._asDate(json['created_at']),
      productId: product?['id']?.toString(),
      productName: product?['name']?.toString(),
      orderId: order?['id']?.toString(),
      orderNumber: order?['order_number']?.toString(),
      orderStatus: order?['status']?.toString(),
      revieweeName: reviewee?['name']?.toString(),
    );
  }
}
