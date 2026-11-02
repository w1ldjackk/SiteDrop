// lib/data/models/site.dart
// Site models for seller app — construction sites, quarries, warehouses, suppliers.

import 'package:flutter/material.dart';
import 'package:sitedrop_core/app/theme/colors.dart';
import 'package:sitedrop_core/core/constants/api_constants.dart';
import 'package:sitedrop_core/core/utils/json_helpers.dart';
import 'package:sitedrop_core/maps/app_map_point.dart';

class SiteModel {
  final String id;
  final String userId;
  final String name;
  final String address;
  final AppMapPoint? coordinates;
  final String? contactPerson;
  final String? contactPhone;
  final List<String> sitePhotos;
  final String? description;
  final SiteType siteType;
  final SiteStatus status;
  final double? sizeSqMeters;
  final double? budget;
  final List<String>? materialsNeeded;
  final PriorityLevel priorityLevel;
  final DateTime? projectStartDate;
  final DateTime? estimatedCompletionDate;
  final String? siteManagerId;
  final String? supervisorId;
  final String? accessNotes;
  final String? securityRequirements;
  final String siteCode;
  final String? statusUpdateReason;
  final DateTime? statusUpdatedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const SiteModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.address,
    this.coordinates,
    this.contactPerson,
    this.contactPhone,
    this.sitePhotos = const [],
    this.description,
    this.siteType = SiteType.construction,
    this.status = SiteStatus.planning,
    this.sizeSqMeters,
    this.budget,
    this.materialsNeeded,
    this.priorityLevel = PriorityLevel.medium,
    this.projectStartDate,
    this.estimatedCompletionDate,
    this.siteManagerId,
    this.supervisorId,
    this.accessNotes,
    this.securityRequirements,
    required this.siteCode,
    this.statusUpdateReason,
    this.statusUpdatedAt,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  factory SiteModel.fromJson(Map<String, dynamic> json) {
    // coordinates may be a Map or a JSON-encoded string (double-encoded
    // rows only peel one layer through Eloquent's `array` cast).
    AppMapPoint? coords;
    final rawCoords = JsonHelpers.decodeIfString(json['coordinates']);
    if (rawCoords is Map) {
      final c = Map<String, dynamic>.from(rawCoords);
      final lat = JsonHelpers.toDouble(c['lat'] ?? c['latitude']);
      final lng = JsonHelpers.toDouble(
        c['lng'] ?? c['longitude'] ?? c['lon'],
      );
      if (lat != null && lng != null) {
        coords = AppMapPoint(lat, lng);
      }
    }

    return SiteModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      coordinates: coords,
      contactPerson: json['contact_person']?.toString(),
      contactPhone: json['contact_phone']?.toString(),
      sitePhotos: JsonHelpers.stringList(
        json['site_photos'],
      ).map(ApiConstants.resolveAssetUrl).toList(),
      description: json['description']?.toString(),
      siteType: SiteType.fromString(json['site_type']?.toString()),
      status: SiteStatus.fromString(json['status']?.toString()),
      sizeSqMeters: JsonHelpers.toDouble(json['size_sq_meters']),
      budget: JsonHelpers.toDouble(json['budget']),
      materialsNeeded: JsonHelpers.stringList(json['materials_needed']),
      priorityLevel: PriorityLevel.fromString(json['priority_level']?.toString()),
      projectStartDate: _dt(json['project_start_date']),
      estimatedCompletionDate: _dt(json['estimated_completion_date']),
      siteManagerId: json['site_manager_id']?.toString(),
      supervisorId: json['supervisor_id']?.toString(),
      accessNotes: json['access_notes']?.toString(),
      securityRequirements: json['security_requirements']?.toString(),
      siteCode: json['site_code']?.toString() ?? '',
      statusUpdateReason: json['status_update_reason']?.toString(),
      statusUpdatedAt: _dt(json['status_updated_at']),
      createdAt: _dt(json['created_at']) ?? DateTime.now(),
      updatedAt: _dt(json['updated_at']) ?? DateTime.now(),
      deletedAt: _dt(json['deleted_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'name': name,
    'address': address,
    'coordinates': coordinates != null
        ? {'lat': coordinates!.latitude, 'lng': coordinates!.longitude}
        : null,
    'contact_person': contactPerson,
    'contact_phone': contactPhone,
    'site_photos': sitePhotos,
    'description': description,
    'site_type': siteType.value,
    'status': status.value,
    'size_sq_meters': sizeSqMeters,
    'budget': budget,
    'materials_needed': materialsNeeded,
    'priority_level': priorityLevel.value,
    'project_start_date': projectStartDate?.toIso8601String(),
    'estimated_completion_date': estimatedCompletionDate?.toIso8601String(),
    'site_manager_id': siteManagerId,
    'supervisor_id': supervisorId,
    'access_notes': accessNotes,
    'security_requirements': securityRequirements,
    'site_code': siteCode,
    'status_update_reason': statusUpdateReason,
    'status_updated_at': statusUpdatedAt?.toIso8601String(),
  };

  bool get isActive => status == SiteStatus.active;
  bool get isCompleted => status == SiteStatus.completed;
  bool get isOnHold => status == SiteStatus.onHold;
  bool get canManage => !isCompleted && deletedAt == null;

  static DateTime? _dt(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }
}

enum SiteType {
  construction('construction'),
  quarry('quarry'),
  warehouse('warehouse'),
  supplier('supplier'),
  other('other');

  final String value;
  const SiteType(this.value);

  static SiteType fromString(String? s) {
    return SiteType.values.firstWhere(
      (e) => e.value == s,
      orElse: () => SiteType.construction,
    );
  }

  String get displayName {
    switch (this) {
      case SiteType.construction:
        return 'Construction Site';
      case SiteType.quarry:
        return 'Quarry';
      case SiteType.warehouse:
        return 'Warehouse';
      case SiteType.supplier:
        return 'Supplier';
      case SiteType.other:
        return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case SiteType.construction:
        return Icons.construction;
      case SiteType.quarry:
        return Icons.terrain;
      case SiteType.warehouse:
        return Icons.warehouse;
      case SiteType.supplier:
        return Icons.local_shipping;
      case SiteType.other:
        return Icons.location_on;
    }
  }
}

enum SiteStatus {
  planning('planning'),
  active('active'),
  onHold('on_hold'),
  completed('completed'),
  cancelled('cancelled');

  final String value;
  const SiteStatus(this.value);

  static SiteStatus fromString(String? s) {
    return SiteStatus.values.firstWhere(
      (e) => e.value == s,
      orElse: () => SiteStatus.planning,
    );
  }

  String get displayName {
    switch (this) {
      case SiteStatus.planning:
        return 'Planning';
      case SiteStatus.active:
        return 'Active';
      case SiteStatus.onHold:
        return 'On Hold';
      case SiteStatus.completed:
        return 'Completed';
      case SiteStatus.cancelled:
        return 'Cancelled';
    }
  }

  Color get color {
    switch (this) {
      case SiteStatus.planning:
        return const Color(0xFF6366F1);
      case SiteStatus.active:
        return const Color(0xFF10B981);
      case SiteStatus.onHold:
        return const Color(0xFFF59E0B);
      case SiteStatus.completed:
        return const Color(0xFF8B5CF6);
      case SiteStatus.cancelled:
        return const Color(0xFFEF4444);
    }
  }
}

enum PriorityLevel {
  high('high'),
  medium('medium'),
  low('low');

  final String value;
  const PriorityLevel(this.value);

  static PriorityLevel fromString(String? s) {
    return PriorityLevel.values.firstWhere(
      (e) => e.value == s,
      orElse: () => PriorityLevel.medium,
    );
  }

  String get displayName {
    switch (this) {
      case PriorityLevel.high:
        return 'High';
      case PriorityLevel.medium:
        return 'Medium';
      case PriorityLevel.low:
        return 'Low';
    }
  }
}

extension SiteTypeExtension on SiteType {
  Color get color {
    switch (this) {
      case SiteType.construction:
        return const Color(0xFF6366F1);
      case SiteType.quarry:
        return const Color(0xFFF59E0B);
      case SiteType.warehouse:
        return const Color(0xFF10B981);
      case SiteType.supplier:
        return const Color(0xFF8B5CF6);
      case SiteType.other:
        return const Color(0xFF64748B);
    }
  }

  IconData get icon {
    switch (this) {
      case SiteType.construction:
        return Icons.construction_outlined;
      case SiteType.quarry:
        return Icons.terrain_outlined;
      case SiteType.warehouse:
        return Icons.warehouse_outlined;
      case SiteType.supplier:
        return Icons.local_shipping_outlined;
      case SiteType.other:
        return Icons.more_horiz;
    }
  }
}

extension PriorityLevelExtension on PriorityLevel {
  Color get color {
    switch (this) {
      case PriorityLevel.high:
        return AppColors.error;
      case PriorityLevel.medium:
        return AppColors.warning;
      case PriorityLevel.low:
        return AppColors.success;
    }
  }
}