// lib/data/models/site_status_log.dart
// Site status logs — audit trail for site status changes.

class SiteStatusLogModel {
  final String id;
  final String siteId;
  final String? userId;
  final String? oldStatus;
  final String newStatus;
  final String? reason;
  final String? notes;
  final String? ipAddress;
  final String? userAgent;
  final DateTime createdAt;

  const SiteStatusLogModel({
    required this.id,
    required this.siteId,
    this.userId,
    this.oldStatus,
    required this.newStatus,
    this.reason,
    this.notes,
    this.ipAddress,
    this.userAgent,
    required this.createdAt,
  });

  factory SiteStatusLogModel.fromJson(Map<String, dynamic> json) {
    return SiteStatusLogModel(
      id: json['id']?.toString() ?? '',
      siteId: json['site_id']?.toString() ?? '',
      userId: json['user_id']?.toString(),
      oldStatus: json['old_status']?.toString(),
      newStatus: json['new_status']?.toString() ?? '',
      reason: json['reason']?.toString(),
      notes: json['notes']?.toString(),
      ipAddress: json['ip_address']?.toString(),
      userAgent: json['user_agent']?.toString(),
      createdAt: _dt(json['created_at']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'site_id': siteId,
    'user_id': userId,
    'old_status': oldStatus,
    'new_status': newStatus,
    'reason': reason,
    'notes': notes,
    'ip_address': ipAddress,
    'user_agent': userAgent,
  };

  static DateTime? _dt(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }
}