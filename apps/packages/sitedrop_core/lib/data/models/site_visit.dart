// lib/data/models/site_visit.dart
// Site visits — visitor check-ins, safety briefings, PPE tracking.

import '../../core/utils/json_helpers.dart';

class SiteVisitModel {
  final String id;
  final String siteId;
  final String userId;
  final String visitorName;
  final String visitorPhone;
  final String? visitorEmail;
  final String? visitorSignature;
  final String? hostSignature;
  final VisitType visitType;
  final DateTime visitDate;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final String purpose;
  final String? notes;
  final VisitStatus status;
  final String? approvedBy;
  final DateTime? approvedAt;
  final bool safetyBriefingCompleted;
  final bool ppeProvided;
  final double? temperature;
  final String? vehicleRegistration;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SiteVisitModel({
    required this.id,
    required this.siteId,
    required this.userId,
    required this.visitorName,
    required this.visitorPhone,
    this.visitorEmail,
    this.visitorSignature,
    this.hostSignature,
    required this.visitType,
    required this.visitDate,
    this.checkInTime,
    this.checkOutTime,
    required this.purpose,
    this.notes,
    required this.status,
    this.approvedBy,
    this.approvedAt,
    required this.safetyBriefingCompleted,
    required this.ppeProvided,
    this.temperature,
    this.vehicleRegistration,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SiteVisitModel.fromJson(Map<String, dynamic> json) {
    return SiteVisitModel(
      id: json['id']?.toString() ?? '',
      siteId: json['site_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      visitorName: json['visitor_name']?.toString() ?? '',
      visitorPhone: json['visitor_phone']?.toString() ?? '',
      visitorEmail: json['visitor_email']?.toString(),
      visitorSignature: json['visitor_signature']?.toString(),
      hostSignature: json['host_signature']?.toString(),
      visitType: VisitType.fromString(json['visit_type']?.toString()),
      visitDate: _dt(json['visit_date']) ?? DateTime.now(),
      checkInTime: _dt(json['check_in_time']),
      checkOutTime: _dt(json['check_out_time']),
      purpose: json['purpose']?.toString() ?? '',
      notes: json['notes']?.toString(),
      status: VisitStatus.fromString(json['status']?.toString()),
      approvedBy: json['approved_by']?.toString(),
      approvedAt: _dt(json['approved_at']),
      safetyBriefingCompleted: JsonHelpers.boolean(
        json['safety_briefing_completed'],
      ),
      ppeProvided: JsonHelpers.boolean(json['ppe_provided']),
      temperature: JsonHelpers.toDouble(json['temperature']),
      vehicleRegistration: json['vehicle_registration']?.toString(),
      createdAt: _dt(json['created_at']) ?? DateTime.now(),
      updatedAt: _dt(json['updated_at']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'site_id': siteId,
    'user_id': userId,
    'visitor_name': visitorName,
    'visitor_phone': visitorPhone,
    'visitor_email': visitorEmail,
    'visitor_signature': visitorSignature,
    'host_signature': hostSignature,
    'visit_type': visitType.value,
    'visit_date': visitDate.toIso8601String(),
    'check_in_time': checkInTime?.toIso8601String(),
    'check_out_time': checkOutTime?.toIso8601String(),
    'purpose': purpose,
    'notes': notes,
    'status': status.value,
    'approved_by': approvedBy,
    'approved_at': approvedAt?.toIso8601String(),
    'safety_briefing_completed': safetyBriefingCompleted,
    'ppe_provided': ppeProvided,
    'temperature': temperature,
    'vehicle_registration': vehicleRegistration,
  };

  Duration? get duration {
    if (checkInTime == null || checkOutTime == null) return null;
    return checkOutTime!.difference(checkInTime!);
  }

  bool get isCheckedIn => checkInTime != null;
  bool get isCheckedOut => checkOutTime != null;
  bool get isActive => status == VisitStatus.checkedIn || status == VisitStatus.inProgress;

  static DateTime? _dt(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }
}

enum VisitType {
  scheduled('scheduled'),
  walkIn('walk-in'),
  emergency('emergency');

  final String value;
  const VisitType(this.value);

  static VisitType fromString(String? s) {
    return VisitType.values.firstWhere(
      (e) => e.value == s,
      orElse: () => VisitType.scheduled,
    );
  }
}

enum VisitStatus {
  scheduled('scheduled'),
  checkedIn('checked_in'),
  inProgress('in_progress'),
  completed('completed'),
  cancelled('cancelled'),
  rejected('rejected');

  final String value;
  const VisitStatus(this.value);

  static VisitStatus fromString(String? s) {
    return VisitStatus.values.firstWhere(
      (e) => e.value == s,
      orElse: () => VisitStatus.scheduled,
    );
  }

  String get displayName {
    switch (this) {
      case VisitStatus.scheduled:
        return 'Scheduled';
      case VisitStatus.checkedIn:
        return 'Checked In';
      case VisitStatus.inProgress:
        return 'In Progress';
      case VisitStatus.completed:
        return 'Completed';
      case VisitStatus.cancelled:
        return 'Cancelled';
      case VisitStatus.rejected:
        return 'Rejected';
    }
  }
}