// lib/data/models/site_staff.dart
// Site staff — workers, managers, supervisors assigned to a site.

import '../../core/utils/json_helpers.dart';

class SiteStaffModel {
  final String id;
  final String siteId;
  final String userId;
  final StaffRole role;
  final String? department;
  final String position;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isActive;
  final Map<String, dynamic>? shiftSchedule;
  final Map<String, dynamic>? contactEmergency;
  final List<String> certifications;
  final List<String> skills;
  final double? performanceRating;
  final DateTime? lastPerformanceReview;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SiteStaffModel({
    required this.id,
    required this.siteId,
    required this.userId,
    required this.role,
    this.department,
    required this.position,
    required this.startDate,
    this.endDate,
    required this.isActive,
    this.shiftSchedule,
    this.contactEmergency,
    this.certifications = const [],
    this.skills = const [],
    this.performanceRating,
    this.lastPerformanceReview,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SiteStaffModel.fromJson(Map<String, dynamic> json) {
    return SiteStaffModel(
      id: json['id']?.toString() ?? '',
      siteId: json['site_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      role: StaffRole.fromString(json['role']?.toString()),
      department: json['department']?.toString(),
      position: json['position']?.toString() ?? '',
      startDate: _dt(json['start_date']) ?? DateTime.now(),
      endDate: _dt(json['end_date']),
      isActive: JsonHelpers.boolean(json['is_active'], fallback: true),
      shiftSchedule: JsonHelpers.dynamicMap(json['shift_schedule']),
      contactEmergency: JsonHelpers.dynamicMap(json['contact_emergency']),
      certifications: JsonHelpers.stringList(json['certifications']),
      skills: JsonHelpers.stringList(json['skills']),
      performanceRating: JsonHelpers.toDouble(json['performance_rating']),
      lastPerformanceReview: _dt(json['last_performance_review']),
      notes: json['notes']?.toString(),
      createdAt: _dt(json['created_at']) ?? DateTime.now(),
      updatedAt: _dt(json['updated_at']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'site_id': siteId,
    'user_id': userId,
    'role': role.value,
    'department': department,
    'position': position,
    'start_date': startDate.toIso8601String(),
    'end_date': endDate?.toIso8601String(),
    'is_active': isActive,
    'shift_schedule': shiftSchedule,
    'contact_emergency': contactEmergency,
    'certifications': certifications,
    'skills': skills,
    'performance_rating': performanceRating,
    'last_performance_review': lastPerformanceReview?.toIso8601String(),
    'notes': notes,
  };

  bool get isCurrentlyActive => isActive && (endDate == null || endDate!.isAfter(DateTime.now()));

  static DateTime? _dt(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }
}

enum StaffRole {
  siteManager('site_manager'),
  supervisor('supervisor'),
  foreman('foreman'),
  safetyOfficer('safety_officer'),
  qualityControl('quality_control'),
  operator('operator'),
  laborer('laborer'),
  other('other');

  final String value;
  const StaffRole(this.value);

  static StaffRole fromString(String? s) {
    return StaffRole.values.firstWhere(
      (e) => e.value == s,
      orElse: () => StaffRole.laborer,
    );
  }

  String get displayName {
    switch (this) {
      case StaffRole.siteManager:
        return 'Site Manager';
      case StaffRole.supervisor:
        return 'Supervisor';
      case StaffRole.foreman:
        return 'Foreman';
      case StaffRole.safetyOfficer:
        return 'Safety Officer';
      case StaffRole.qualityControl:
        return 'Quality Control';
      case StaffRole.operator:
        return 'Operator';
      case StaffRole.laborer:
        return 'Laborer';
      case StaffRole.other:
        return 'Other';
    }
  }
}