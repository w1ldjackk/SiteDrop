// Seller profile stats (no wishlist)
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sitedrop_core/core/constants/api_constants.dart';
import 'package:sitedrop_core/data/services/api_service.dart';
import 'package:sitedrop_core/data/services/storage_service.dart';

class ProfileStats {
  final int ordersCount;
  final int reviewsCount;
  final int wishlistCount;
  final int deliveriesCount;
  final double rating;

  const ProfileStats({
    this.ordersCount = 0,
    this.reviewsCount = 0,
    this.wishlistCount = 0,
    this.deliveriesCount = 0,
    this.rating = 0,
  });

  factory ProfileStats.fromJson(Map<String, dynamic> json) {
    return ProfileStats(
      ordersCount: _asInt(json['orders_count']),
      reviewsCount: _asInt(json['reviews_count']),
      wishlistCount: _asInt(json['wishlist_count']),
      deliveriesCount: _asInt(json['deliveries_count']),
      rating: _asDouble(json['rating']),
    );
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  static double _asDouble(dynamic v) {
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }
}

final profileStatsProvider =
    FutureProvider.autoDispose<ProfileStats>((ref) async {
  final token = await StorageService.getAuthToken();
  if (token == null || token.isEmpty) {
    return const ProfileStats();
  }

  try {
    final response = await ApiService.get<Map<String, dynamic>>(
      ApiConstants.profileStats,
    );
    final data = response['data'] as Map<String, dynamic>? ?? {};
    return ProfileStats.fromJson(data);
  } catch (_) {
    return const ProfileStats();
  }
});
