// lib/data/models/seller_follow.dart
// Seller follows — buyers following sellers for notifications.

class SellerFollowModel {
  final String id;
  final String userId; // buyer
  final String sellerId; // seller
  final DateTime createdAt;

  const SellerFollowModel({
    required this.id,
    required this.userId,
    required this.sellerId,
    required this.createdAt,
  });

  factory SellerFollowModel.fromJson(Map<String, dynamic> json) {
    return SellerFollowModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      sellerId: json['seller_id']?.toString() ?? '',
      createdAt: _dt(json['created_at']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'seller_id': sellerId,
  };

  static DateTime? _dt(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }
}