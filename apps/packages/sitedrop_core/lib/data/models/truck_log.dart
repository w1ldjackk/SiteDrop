// lib/data/models/truck_log.dart
// Maps to Laravel App\Models\TruckLog (activity history).

class TruckLogModel {
  final String id;
  final String truckId;
  final String? userId;
  final String? userName;
  final String action;
  final String? description;
  final Map<String, dynamic>? metadata;
  final DateTime? createdAt;

  const TruckLogModel({
    required this.id,
    required this.truckId,
    this.userId,
    this.userName,
    required this.action,
    this.description,
    this.metadata,
    this.createdAt,
  });

  String get actionLabel =>
      action.replaceAll('_', ' ').split(' ').map((w) {
        if (w.isEmpty) return w;
        return w[0].toUpperCase() + w.substring(1);
      }).join(' ');

  factory TruckLogModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    return TruckLogModel(
      id: '${json['id'] ?? ''}',
      truckId: '${json['truck_id'] ?? ''}',
      userId: json['user_id']?.toString(),
      userName: user is Map ? user['name']?.toString() : null,
      action: '${json['action'] ?? ''}',
      description: json['description']?.toString(),
      metadata: json['metadata'] is Map
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : null,
      createdAt: _dt(json['created_at']),
    );
  }

  static DateTime? _dt(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }
}
