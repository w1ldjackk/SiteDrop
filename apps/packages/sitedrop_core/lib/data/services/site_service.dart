// lib/data/services/site_service.dart
// Site service — CRUD for sites, documents, materials, staff, visits, status logs.

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/site.dart';
import '../models/site_document.dart';
import '../models/site_material.dart';
import '../models/site_staff.dart';
import '../models/site_status_log.dart';
import '../models/site_visit.dart';
import '../models/seller_profile.dart';
import '../models/service_area.dart';
import '../models/seller_follow.dart';
import '../../core/constants/api_constants.dart';
import '../../core/utils/json_helpers.dart';
import '../../maps/app_map_point.dart';
import 'api_service.dart';

class SiteService {
  static Future<List<SiteModel>> fetchSites({
    String? status,
    SiteType? siteType,
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'per_page': perPage.toString(),
      };
      if (status != null) {
        queryParams['status'] = status;
      }
      if (siteType != null) {
        queryParams['site_type'] = siteType.value;
      }

      final response = await ApiService.get<Map<String, dynamic>>(
        ApiConstants.sites,
        queryParams: queryParams,
      );

      final data = response['data'] as Map<String, dynamic>? ?? {};
      final sitesData =
          data['sites'] as List<dynamic>? ??
          data['data'] as List<dynamic>? ??
          [];
      debugPrint('[SiteService] fetchSites: ${sitesData.length} row(s)');
      // Parse per-item: one malformed row must not nuke the whole list
      // into a fake-empty state.
      final out = <SiteModel>[];
      for (final item in sitesData) {
        if (item is! Map) continue;
        try {
          out.add(SiteModel.fromJson(Map<String, dynamic>.from(item)));
        } catch (e) {
          debugPrint('[SiteService] fetchSites: skipped 1 row ($e)');
        }
      }
      return out;
    } catch (e) {
      debugPrint('[SiteService] fetchSites failed: $e');
      return const [];
    }
  }

  static Future<SiteModel?> fetchSite(String siteId) async {
    try {
      final response = await ApiService.get<Map<String, dynamic>>(
        ApiConstants.siteDetail(siteId),
      );

      final data = response['data'] as Map<String, dynamic>? ?? {};
      final siteRaw = data['site'];
      final siteData = siteRaw is Map
          ? Map<String, dynamic>.from(siteRaw)
          : data;
      if (siteData.isNotEmpty) {
        return SiteModel.fromJson(siteData);
      }
      return null;
    } catch (e) {
      debugPrint('[SiteService] fetchSite($siteId) failed: $e');
      return null;
    }
  }

  static Future<SiteModel> createSite({
    required String name,
    required String address,
    required SiteType siteType,
    String? contactPerson,
    String? contactPhone,
    AppMapPoint? coordinates,
    String? description,
    List<String>? sitePhotos,
    double? sizeSqMeters,
    double? budget,
    List<String>? materialsNeeded,
    SiteStatus? status,
    PriorityLevel? priorityLevel,
    DateTime? projectStartDate,
    DateTime? estimatedCompletionDate,
    String? siteManagerId,
    String? supervisorId,
    String? accessNotes,
    String? securityRequirements,
    List<MultipartFile>? sitePhotoFiles,
  }) async {
    // Multipart when new photos are attached (works on web via bytes);
    // otherwise JSON. [sitePhotoFiles] must use the 'site_photos[]' key
    // the backend reads.
    if (sitePhotoFiles != null && sitePhotoFiles.isNotEmpty) {
      final form = FormData.fromMap({
        'name': name,
        'address': address,
        'site_type': siteType.value,
        'contact_person': ?contactPerson,
        'contact_phone': ?contactPhone,
        'description': ?description,
        'size_sq_meters': ?sizeSqMeters,
        'budget': ?budget,
        'status': ?status?.value,
        'priority_level': ?priorityLevel?.value,
        'access_notes': ?accessNotes,
        'security_requirements': ?securityRequirements,
        if (coordinates != null)
          'coordinates': {
            'lat': coordinates.latitude,
            'lng': coordinates.longitude,
          },
      });
      for (final file in sitePhotoFiles) {
        form.files.add(MapEntry('site_photos[]', file));
      }
      final response = await ApiService.post<Map<String, dynamic>>(
        ApiConstants.sites,
        data: form,
        options: Options(contentType: 'multipart/form-data'),
      );
      final siteData =
          response['data'] as Map<String, dynamic>? ??
          response['site'] as Map<String, dynamic>? ??
          response;
      return SiteModel.fromJson(siteData);
    }

    final data = {
      'name': name,
      'address': address,
      'site_type': siteType.value,
      'contact_person': ?contactPerson,
      'contact_phone': ?contactPhone,
      'coordinates': coordinates != null
          ? {'lat': coordinates.latitude, 'lng': coordinates.longitude}
          : null,
      'description': ?description,
      'site_photos': ?sitePhotos,
      'size_sq_meters': ?sizeSqMeters,
      'budget': ?budget,
      'materials_needed': ?materialsNeeded,
      'status': ?status?.value,
      'priority_level': ?priorityLevel?.value,
      'project_start_date': ?projectStartDate?.toIso8601String(),
      'estimated_completion_date': ?estimatedCompletionDate?.toIso8601String(),
      'site_manager_id': ?siteManagerId,
      'supervisor_id': ?supervisorId,
      'access_notes': ?accessNotes,
      'security_requirements': ?securityRequirements,
    };

    final response = await ApiService.post<Map<String, dynamic>>(
      ApiConstants.sites,
      data: data,
    );

    final siteData =
        response['data'] as Map<String, dynamic>? ??
        response['site'] as Map<String, dynamic>? ??
        response;
    return SiteModel.fromJson(siteData);
  }

  static Future<SiteModel> updateSite(
    String siteId, {
    String? name,
    String? address,
    SiteType? siteType,
    String? contactPerson,
    String? contactPhone,
    AppMapPoint? coordinates,
    String? description,
    List<String>? sitePhotos,
    SiteStatus? status,
    double? sizeSqMeters,
    double? budget,
    List<String>? materialsNeeded,
    PriorityLevel? priorityLevel,
    DateTime? projectStartDate,
    DateTime? estimatedCompletionDate,
    String? siteManagerId,
    String? supervisorId,
    String? accessNotes,
    String? securityRequirements,
    String? statusUpdateReason,
    List<MultipartFile>? sitePhotoFiles,
    List<String>? existingPhotoPaths,
  }) async {
    // Multipart when photos change. PHP never parses multipart bodies on a
    // real PUT, so spoof via POST + _method (matches the PUT route).
    final hasPhotoChanges =
        (sitePhotoFiles != null && sitePhotoFiles.isNotEmpty) ||
        existingPhotoPaths != null;
    if (hasPhotoChanges) {
      final form = FormData.fromMap({
        '_method': 'PUT',
        'name': ?name,
        'address': ?address,
        'site_type': ?siteType?.value,
        'contact_person': ?contactPerson,
        'contact_phone': ?contactPhone,
        'description': ?description,
        'status': ?status?.value,
        'size_sq_meters': ?sizeSqMeters,
        'budget': ?budget,
        'priority_level': ?priorityLevel?.value,
        'access_notes': ?accessNotes,
        'security_requirements': ?securityRequirements,
        'status_update_reason': ?statusUpdateReason,
        if (coordinates != null)
          'coordinates': {
            'lat': coordinates.latitude,
            'lng': coordinates.longitude,
          },
        'existing_photos': ?existingPhotoPaths,
      });
      if (sitePhotoFiles != null) {
        for (final file in sitePhotoFiles) {
          form.files.add(MapEntry('site_photos[]', file));
        }
      }
      final response = await ApiService.post<Map<String, dynamic>>(
        ApiConstants.siteDetail(siteId),
        data: form,
        options: Options(contentType: 'multipart/form-data'),
      );
      final siteData =
          response['data'] as Map<String, dynamic>? ??
          response['site'] as Map<String, dynamic>? ??
          response;
      return SiteModel.fromJson(siteData);
    }

    final data = <String, dynamic>{};
    if (name != null) {
      data['name'] = name;
    }
    if (address != null) {
      data['address'] = address;
    }
    if (siteType != null) {
      data['site_type'] = siteType.value;
    }
    if (contactPerson != null) {
      data['contact_person'] = contactPerson;
    }
    if (contactPhone != null) {
      data['contact_phone'] = contactPhone;
    }
    if (coordinates != null) {
      data['coordinates'] = {
        'lat': coordinates.latitude,
        'lng': coordinates.longitude,
      };
    }
    if (description != null) {
      data['description'] = description;
    }
    if (sitePhotos != null) {
      data['site_photos'] = sitePhotos;
    }
    if (status != null) {
      data['status'] = status.value;
    }
    if (sizeSqMeters != null) {
      data['size_sq_meters'] = sizeSqMeters;
    }
    if (budget != null) {
      data['budget'] = budget;
    }
    if (materialsNeeded != null) {
      data['materials_needed'] = materialsNeeded;
    }
    if (priorityLevel != null) {
      data['priority_level'] = priorityLevel.value;
    }
    if (projectStartDate != null) {
      data['project_start_date'] = projectStartDate.toIso8601String();
    }
    if (estimatedCompletionDate != null) {
      data['estimated_completion_date'] = estimatedCompletionDate
          .toIso8601String();
    }
    if (siteManagerId != null) {
      data['site_manager_id'] = siteManagerId;
    }
    if (supervisorId != null) {
      data['supervisor_id'] = supervisorId;
    }
    if (accessNotes != null) {
      data['access_notes'] = accessNotes;
    }
    if (securityRequirements != null) {
      data['security_requirements'] = securityRequirements;
    }
    if (statusUpdateReason != null) {
      data['status_update_reason'] = statusUpdateReason;
    }

    final response = await ApiService.put<Map<String, dynamic>>(
      ApiConstants.siteDetail(siteId),
      data: data,
    );

    final siteData =
        response['data'] as Map<String, dynamic>? ??
        response['site'] as Map<String, dynamic>? ??
        response;
    return SiteModel.fromJson(siteData);
  }

  static Future<void> deleteSite(String siteId) async {
    await ApiService.delete(ApiConstants.siteDetail(siteId));
  }

  // Site Documents
  static Future<List<SiteDocumentModel>> fetchSiteDocuments(
    String siteId,
  ) async {
    try {
      final response = await ApiService.get<Map<String, dynamic>>(
        ApiConstants.sitesDocuments.replaceAll('{id}', siteId),
      );
      // NOTE: this endpoint returns a bare array in `data`, not an object.
      final docsData = JsonHelpers.listFromData(
        response['data'],
        const ['documents', 'data'],
      );
      final out = <SiteDocumentModel>[];
      for (final item in docsData) {
        if (item is! Map) continue;
        try {
          out.add(SiteDocumentModel.fromJson(Map<String, dynamic>.from(item)));
        } catch (e) {
          debugPrint('[SiteService] fetchSiteDocuments: skipped 1 row ($e)');
        }
      }
      return out;
    } catch (e) {
      debugPrint('[SiteService] fetchSiteDocuments failed: $e');
      return const [];
    }
  }

  static Future<SiteDocumentModel> uploadDocument(
    String siteId, {
    required String title,
    required DocumentType documentType,
    required String filePath,
    String? fileName,
    List<int>? fileBytes,
    String? description,
    String? version,
    DocumentStatus? status,
    DateTime? expiryDate,
    bool? isConfidential,
    AccessLevel? accessLevel,
    List<String>? tags,
  }) async {
    final resolvedName = (fileName == null || fileName.isEmpty)
        ? filePath.split('/').last.split(r'\').last
        : fileName;

    final MultipartFile file;
    if (fileBytes != null) {
      file = MultipartFile.fromBytes(fileBytes, filename: resolvedName);
    } else {
      file = await MultipartFile.fromFile(filePath, filename: resolvedName);
    }

    final formData = FormData.fromMap({
      'title': title,
      'document_type': documentType.value,
      // Backend validates `document` (same key as truck/seller uploads).
      'document': file,
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
      if (version != null && version.trim().isNotEmpty)
        'version': version.trim(),
      if (status != null) 'status': status.value,
      if (expiryDate != null) 'expiry_date': expiryDate.toIso8601String(),
      if (isConfidential != null) 'is_confidential': isConfidential ? 1 : 0,
      if (accessLevel != null) 'access_level': accessLevel.value,
      if (tags != null && tags.isNotEmpty) 'tags': tags,
    });

    final response = await ApiService.post<Map<String, dynamic>>(
      ApiConstants.sitesDocuments.replaceAll('{id}', siteId),
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );

    final docData =
        response['data'] as Map<String, dynamic>? ??
        response['document'] as Map<String, dynamic>? ??
        response;
    return SiteDocumentModel.fromJson(docData);
  }

  // Site Materials
  static Future<List<SiteMaterialModel>> fetchSiteMaterials(
    String siteId,
  ) async {
    try {
      final response = await ApiService.get<Map<String, dynamic>>(
        ApiConstants.sitesMaterials.replaceAll('{id}', siteId),
      );
      // NOTE: this endpoint returns a bare array in `data`, not an object.
      final matsData = JsonHelpers.listFromData(
        response['data'],
        const ['materials', 'data'],
      );
      final out = <SiteMaterialModel>[];
      for (final item in matsData) {
        if (item is! Map) continue;
        try {
          out.add(SiteMaterialModel.fromJson(Map<String, dynamic>.from(item)));
        } catch (e) {
          debugPrint('[SiteService] fetchSiteMaterials: skipped 1 row ($e)');
        }
      }
      return out;
    } catch (e) {
      debugPrint('[SiteService] fetchSiteMaterials failed: $e');
      return const [];
    }
  }

  static Future<SiteMaterialModel> createMaterial(
    String siteId, {
    required String materialName,
    required double quantityNeeded,
    required String unit,
    String? supplierId,
    double? estimatedCost,
    DateTime? expectedDeliveryDate,
    String? notes,
  }) async {
    final data = {
      'material_name': materialName,
      'quantity_needed': quantityNeeded,
      'unit': unit,
      'supplier_id': ?supplierId,
      'estimated_cost': ?estimatedCost,
      'expected_delivery_date': ?expectedDeliveryDate?.toIso8601String(),
      'notes': ?notes,
    };

    final response = await ApiService.post<Map<String, dynamic>>(
      ApiConstants.sitesMaterials.replaceAll('{id}', siteId),
      data: data,
    );

    final matData =
        response['data'] as Map<String, dynamic>? ??
        response['material'] as Map<String, dynamic>? ??
        response;
    return SiteMaterialModel.fromJson(matData);
  }

  static Future<SiteMaterialModel> updateMaterial(
    String siteId,
    String materialId, {
    String? materialName,
    double? quantityNeeded,
    double? quantityDelivered,
    String? unit,
    double? estimatedCost,
    double? actualCost,
    DeliveryStatus? deliveryStatus,
    DateTime? orderedAt,
    DateTime? expectedDeliveryDate,
    DateTime? deliveredAt,
    String? notes,
  }) async {
    final data = <String, dynamic>{};
    if (materialName != null) {
      data['material_name'] = materialName;
    }
    if (quantityNeeded != null) {
      data['quantity_needed'] = quantityNeeded;
    }
    if (quantityDelivered != null) {
      data['quantity_delivered'] = quantityDelivered;
    }
    if (unit != null) {
      data['unit'] = unit;
    }
    if (estimatedCost != null) {
      data['estimated_cost'] = estimatedCost;
    }
    if (actualCost != null) {
      data['actual_cost'] = actualCost;
    }
    if (deliveryStatus != null) {
      data['delivery_status'] = deliveryStatus.value;
    }
    if (orderedAt != null) {
      data['ordered_at'] = orderedAt.toIso8601String();
    }
    if (expectedDeliveryDate != null) {
      data['expected_delivery_date'] = expectedDeliveryDate.toIso8601String();
    }
    if (deliveredAt != null) {
      data['delivered_at'] = deliveredAt.toIso8601String();
    }
    if (notes != null) {
      data['notes'] = notes;
    }

    final response = await ApiService.put<Map<String, dynamic>>(
      '${ApiConstants.sitesMaterials.replaceAll('{id}', siteId)}/$materialId',
      data: data,
    );

    final matData =
        response['data'] as Map<String, dynamic>? ??
        response['material'] as Map<String, dynamic>? ??
        response;
    return SiteMaterialModel.fromJson(matData);
  }

  // Site Staff
  static Future<List<SiteStaffModel>> fetchSiteStaff(
    String siteId, {
    bool? isActive,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (isActive != null) {
        queryParams['is_active'] = isActive.toString();
      }

      final response = await ApiService.get<Map<String, dynamic>>(
        ApiConstants.sitesStaff.replaceAll('{id}', siteId),
        queryParams: queryParams.isEmpty ? null : queryParams,
      );
      // NOTE: this endpoint returns a bare array in `data`, not an object.
      final staffData = JsonHelpers.listFromData(
        response['data'],
        const ['staff', 'data'],
      );
      final out = <SiteStaffModel>[];
      for (final item in staffData) {
        if (item is! Map) continue;
        try {
          out.add(SiteStaffModel.fromJson(Map<String, dynamic>.from(item)));
        } catch (e) {
          debugPrint('[SiteService] fetchSiteStaff: skipped 1 row ($e)');
        }
      }
      return out;
    } catch (e) {
      debugPrint('[SiteService] fetchSiteStaff failed: $e');
      return const [];
    }
  }

  static Future<SiteStaffModel> addStaff(
    String siteId, {
    required String userId,
    required StaffRole role,
    required String position,
    required DateTime startDate,
    DateTime? endDate,
    String? department,
    Map<String, dynamic>? shiftSchedule,
    Map<String, dynamic>? contactEmergency,
    List<String>? certifications,
    List<String>? skills,
    String? notes,
  }) async {
    final data = {
      'user_id': userId,
      'role': role.value,
      'position': position,
      'start_date': startDate.toIso8601String(),
      'end_date': ?endDate?.toIso8601String(),
      'department': ?department,
      'shift_schedule': ?shiftSchedule,
      'contact_emergency': ?contactEmergency,
      'certifications': ?certifications,
      'skills': ?skills,
      'notes': ?notes,
    };

    final response = await ApiService.post<Map<String, dynamic>>(
      ApiConstants.sitesStaff.replaceAll('{id}', siteId),
      data: data,
    );

    final staffData =
        response['data'] as Map<String, dynamic>? ??
        response['staff'] as Map<String, dynamic>? ??
        response;
    return SiteStaffModel.fromJson(staffData);
  }

  static Future<SiteStaffModel> updateStaff(
    String siteId,
    String staffId, {
    StaffRole? role,
    String? position,
    DateTime? startDate,
    DateTime? endDate,
    String? department,
    bool? isActive,
    Map<String, dynamic>? shiftSchedule,
    Map<String, dynamic>? contactEmergency,
    List<String>? certifications,
    List<String>? skills,
    double? performanceRating,
    DateTime? lastPerformanceReview,
    String? notes,
  }) async {
    final data = <String, dynamic>{};
    if (role != null) {
      data['role'] = role.value;
    }
    if (position != null) {
      data['position'] = position;
    }
    if (startDate != null) {
      data['start_date'] = startDate.toIso8601String();
    }
    if (endDate != null) {
      data['end_date'] = endDate.toIso8601String();
    }
    if (department != null) {
      data['department'] = department;
    }
    if (isActive != null) {
      data['is_active'] = isActive;
    }
    if (shiftSchedule != null) {
      data['shift_schedule'] = shiftSchedule;
    }
    if (contactEmergency != null) {
      data['contact_emergency'] = contactEmergency;
    }
    if (certifications != null) {
      data['certifications'] = certifications;
    }
    if (skills != null) {
      data['skills'] = skills;
    }
    if (performanceRating != null) {
      data['performance_rating'] = performanceRating;
    }
    if (lastPerformanceReview != null) {
      data['last_performance_review'] = lastPerformanceReview.toIso8601String();
    }
    if (notes != null) {
      data['notes'] = notes;
    }

    final response = await ApiService.put<Map<String, dynamic>>(
      '${ApiConstants.sitesStaff.replaceAll('{id}', siteId)}/$staffId',
      data: data,
    );

    final staffData =
        response['data'] as Map<String, dynamic>? ??
        response['staff'] as Map<String, dynamic>? ??
        response;
    return SiteStaffModel.fromJson(staffData);
  }

  // Site Visits
  static Future<List<SiteVisitModel>> fetchSiteVisits(
    String siteId, {
    VisitStatus? status,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (status != null) {
        queryParams['status'] = status.value;
      }

      final response = await ApiService.get<Map<String, dynamic>>(
        ApiConstants.sitesVisits.replaceAll('{siteId}', siteId),
        queryParams: queryParams.isEmpty ? null : queryParams,
      );
      // NOTE: this endpoint returns a bare array in `data`, not an object.
      final visitsData = JsonHelpers.listFromData(
        response['data'],
        const ['visits', 'data'],
      );
      final out = <SiteVisitModel>[];
      for (final item in visitsData) {
        if (item is! Map) continue;
        try {
          out.add(SiteVisitModel.fromJson(Map<String, dynamic>.from(item)));
        } catch (e) {
          debugPrint('[SiteService] fetchSiteVisits: skipped 1 row ($e)');
        }
      }
      return out;
    } catch (e) {
      debugPrint('[SiteService] fetchSiteVisits failed: $e');
      return const [];
    }
  }

  static Future<SiteVisitModel> createVisit(
    String siteId, {
    required String visitorName,
    required String visitorPhone,
    String? visitorEmail,
    required VisitType visitType,
    required DateTime visitDate,
    required String purpose,
    String? notes,
    String? vehicleRegistration,
  }) async {
    final data = {
      'visitor_name': visitorName,
      'visitor_phone': visitorPhone,
      'visitor_email': ?visitorEmail,
      'visit_type': visitType.value,
      'visit_date': visitDate.toIso8601String(),
      'purpose': purpose,
      'notes': ?notes,
      'vehicle_registration': ?vehicleRegistration,
    };

    final response = await ApiService.post<Map<String, dynamic>>(
      ApiConstants.sitesVisits.replaceAll('{siteId}', siteId),
      data: data,
    );

    final visitData =
        response['data'] as Map<String, dynamic>? ??
        response['visit'] as Map<String, dynamic>? ??
        response;
    return SiteVisitModel.fromJson(visitData);
  }

  static Future<SiteVisitModel> checkInVisit(
    String siteId,
    String visitId, {
    String? visitorSignature,
    String? hostSignature,
    bool? safetyBriefingCompleted,
    bool? ppeProvided,
    double? temperature,
  }) async {
    final data = <String, dynamic>{};
    if (visitorSignature != null) {
      data['visitor_signature'] = visitorSignature;
    }
    if (hostSignature != null) {
      data['host_signature'] = hostSignature;
    }
    if (safetyBriefingCompleted != null) {
      data['safety_briefing_completed'] = safetyBriefingCompleted;
    }
    if (ppeProvided != null) {
      data['ppe_provided'] = ppeProvided;
    }
    if (temperature != null) {
      data['temperature'] = temperature;
    }

    final response = await ApiService.post<Map<String, dynamic>>(
      ApiConstants.sitesCheckIn
          .replaceAll('{siteId}', siteId)
          .replaceAll('{visitId}', visitId),
      data: data,
    );

    final visitData =
        response['data'] as Map<String, dynamic>? ??
        response['visit'] as Map<String, dynamic>? ??
        response;
    return SiteVisitModel.fromJson(visitData);
  }

  static Future<SiteVisitModel> checkOutVisit(
    String siteId,
    String visitId, {
    String? visitorSignature,
    String? hostSignature,
  }) async {
    final data = <String, dynamic>{};
    if (visitorSignature != null) {
      data['visitor_signature'] = visitorSignature;
    }
    if (hostSignature != null) {
      data['host_signature'] = hostSignature;
    }

    final response = await ApiService.post<Map<String, dynamic>>(
      ApiConstants.sitesCheckOut
          .replaceAll('{siteId}', siteId)
          .replaceAll('{visitId}', visitId),
      data: data,
    );

    final visitData =
        response['data'] as Map<String, dynamic>? ??
        response['visit'] as Map<String, dynamic>? ??
        response;
    return SiteVisitModel.fromJson(visitData);
  }

  // Site Status Logs
  static Future<List<SiteStatusLogModel>> fetchSiteStatusLogs(
    String siteId,
  ) async {
    try {
      final response = await ApiService.get<Map<String, dynamic>>(
        '${ApiConstants.siteDetail(siteId)}/status-logs',
      );
      // NOTE: this endpoint returns a bare array in `data`, not an object.
      final logsData = JsonHelpers.listFromData(
        response['data'],
        const ['logs', 'data'],
      );
      final out = <SiteStatusLogModel>[];
      for (final item in logsData) {
        if (item is! Map) continue;
        try {
          out.add(SiteStatusLogModel.fromJson(Map<String, dynamic>.from(item)));
        } catch (e) {
          debugPrint('[SiteService] fetchSiteStatusLogs: skipped 1 row ($e)');
        }
      }
      return out;
    } catch (e) {
      debugPrint('[SiteService] fetchSiteStatusLogs failed: $e');
      return const [];
    }
  }

  // Seller Profile — backed by Laravel SellerOnboardingController.
  // GET /seller/onboarding, POST /seller/onboarding,
  // GET /seller/status, POST /seller/submit-for-review,
  // POST /seller/documents.
  static Future<SellerProfileModel?> fetchSellerProfile() async {
    final onboarding = await fetchSellerOnboarding();
    return onboarding.profile;
  }

  static Future<SellerOnboarding> fetchSellerOnboarding() async {
    // NOTE: errors propagate so the edit screen's Retry branch shows
    // genuine failures instead of masquerading as "no docs". A clean
    // no-profile case still returns 200 + null -> empty form.
    final response = await ApiService.get<Map<String, dynamic>>(
      ApiConstants.sellerOnboarding,
    );
    final data = response['data'] is Map
        ? Map<String, dynamic>.from(response['data'] as Map)
        : <String, dynamic>{};
    final profileRaw = data['seller_profile'];
    final profileData = profileRaw is Map
        ? Map<String, dynamic>.from(profileRaw)
        : null;
    final missingRaw = data['missing_fields'];
    return SellerOnboarding(
      profile: profileData != null && profileData.isNotEmpty
          ? SellerProfileModel.fromJson(profileData)
          : null,
      isComplete: data['is_complete'] == true || data['is_complete'] == 1,
      missingFields: missingRaw is List
          ? missingRaw.map((e) => e.toString()).toList()
          : [],
    );
  }

  static Future<Map<String, dynamic>> fetchSellerStatus() async {
    try {
      final response = await ApiService.get<Map<String, dynamic>>(
        ApiConstants.sellerStatus,
      );
      return response['data'] as Map<String, dynamic>? ?? {};
    } catch (e) {
      return {};
    }
  }

  static Future<SellerProfileModel> submitSellerForReview() async {
    final response = await ApiService.post<Map<String, dynamic>>(
      ApiConstants.sellerSubmitForReview,
    );
    final data = response['data'] as Map<String, dynamic>? ?? {};
    final profileData =
        data['seller_profile'] as Map<String, dynamic>? ?? data;
    return SellerProfileModel.fromJson(profileData);
  }

  /// Create or update the seller business profile.
  /// Sends multipart when [logoPath]/[coverImagePath]/[documentPaths] are set,
  /// otherwise JSON. [serviceAreas] serializes to
  /// [{lat, lng, label, radius_km}] (nulls always omitted — the backend
  /// rejects explicit nulls for array fields).
  static Future<SellerProfileModel> saveSellerProfile({
    required String businessName,
    required SellerBusinessType businessType,
    String? businessRegistrationNumber,
    String? taxId,
    String? businessPhone,
    String? businessEmail,
    String? website,
    String? description,
    List<ServiceArea>? serviceAreas,
    double? commissionRate,
    double? minimumOrderAmount,
    double? deliveryRadiusKm,
    String? bankAccountName,
    String? bankAccountNumber,
    String? bankName,
    String? bankBranch,
    Map<String, String>? socialLinks,
    Map<String, dynamic>? businessHours,
    String? logoPath,
    String? coverImagePath,
    List<int>? logoBytes,
    List<int>? coverImageBytes,
    String? logoFileName,
    String? coverFileName,
    List<String>? documentPaths,
  }) async {
    final hasFiles =
        (logoPath != null && logoPath.isNotEmpty) ||
        (coverImagePath != null && coverImagePath.isNotEmpty) ||
        logoBytes != null ||
        coverImageBytes != null ||
        (documentPaths != null && documentPaths.isNotEmpty);

    dynamic payload;
    Options? options;
    if (hasFiles) {
      final form = FormData.fromMap({
        'business_name': businessName,
        'business_type': businessType.value,
        if (businessRegistrationNumber != null &&
            businessRegistrationNumber.trim().isNotEmpty)
          'business_registration_number': businessRegistrationNumber.trim(),
        if (taxId != null && taxId.trim().isNotEmpty)
          'tax_id': taxId.trim(),
        if (businessPhone != null && businessPhone.trim().isNotEmpty)
          'business_phone': businessPhone.trim(),
        if (businessEmail != null && businessEmail.trim().isNotEmpty)
          'business_email': businessEmail.trim(),
        if (website != null && website.trim().isNotEmpty)
          'website': website.trim(),
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
        if (serviceAreas != null && serviceAreas.isNotEmpty)
          'service_areas': serviceAreas.map((a) => a.toJson()).toList(),
        'commission_rate': ?commissionRate,
        'minimum_order_amount': ?minimumOrderAmount,
        'delivery_radius_km': ?deliveryRadiusKm,
        if (bankAccountName != null && bankAccountName.trim().isNotEmpty)
          'bank_account_name': bankAccountName.trim(),
        if (bankAccountNumber != null && bankAccountNumber.trim().isNotEmpty)
          'bank_account_number': bankAccountNumber.trim(),
        if (bankName != null && bankName.trim().isNotEmpty)
          'bank_name': bankName.trim(),
        if (bankBranch != null && bankBranch.trim().isNotEmpty)
          'bank_branch': bankBranch.trim(),
        'social_links': ?socialLinks,
        'business_hours': ?businessHours,
      });
      if (logoBytes != null) {
        form.files.add(
          MapEntry(
            'logo',
            MultipartFile.fromBytes(
              logoBytes,
              filename: (logoFileName == null || logoFileName.isEmpty)
                  ? 'logo.jpg'
                  : logoFileName,
            ),
          ),
        );
      } else if (logoPath != null && logoPath.isNotEmpty) {
        form.files.add(
          MapEntry(
            'logo',
            await MultipartFile.fromFile(
              logoPath,
              filename: (logoFileName == null || logoFileName.isEmpty)
                  ? logoPath.split('/').last.split(r'\').last
                  : logoFileName,
            ),
          ),
        );
      }
      if (coverImageBytes != null) {
        form.files.add(
          MapEntry(
            'cover_image',
            MultipartFile.fromBytes(
              coverImageBytes,
              filename: (coverFileName == null || coverFileName.isEmpty)
                  ? 'cover.jpg'
                  : coverFileName,
            ),
          ),
        );
      } else if (coverImagePath != null && coverImagePath.isNotEmpty) {
        form.files.add(
          MapEntry(
            'cover_image',
            await MultipartFile.fromFile(
              coverImagePath,
              filename: (coverFileName == null || coverFileName.isEmpty)
                  ? coverImagePath.split('/').last.split(r'\').last
                  : coverFileName,
            ),
          ),
        );
      }
      if (documentPaths != null) {
        for (final path in documentPaths) {
          if (path.isEmpty) {
            continue;
          }
          form.files.add(
            MapEntry(
              'documents[]',
              await MultipartFile.fromFile(
                path,
                filename: path.split('/').last.split(r'\').last,
              ),
            ),
          );
        }
      }
      payload = form;
      options = Options(contentType: 'multipart/form-data');
    } else {
      payload = {
        'business_name': businessName,
        'business_type': businessType.value,
        'business_registration_number': ?businessRegistrationNumber,
        'tax_id': ?taxId,
        'business_phone': ?businessPhone,
        'business_email': ?businessEmail,
        'website': ?website,
        'description': ?description,
        'service_areas': ?serviceAreas?.map((a) => a.toJson()).toList(),
        'commission_rate': ?commissionRate,
        'minimum_order_amount': ?minimumOrderAmount,
        'delivery_radius_km': ?deliveryRadiusKm,
        'bank_account_name': ?bankAccountName,
        'bank_account_number': ?bankAccountNumber,
        'bank_name': ?bankName,
        'bank_branch': ?bankBranch,
        'social_links': ?socialLinks,
        'business_hours': ?businessHours,
      };
    }

    final response = await ApiService.post<Map<String, dynamic>>(
      ApiConstants.sellerOnboarding,
      data: payload,
      options: options,
    );

    final data = response['data'] as Map<String, dynamic>? ?? {};
    final profileData =
        data['seller_profile'] as Map<String, dynamic>? ?? data;
    return SellerProfileModel.fromJson(profileData);
  }

  static Future<SellerProfileModel> createSellerProfile({
    required String businessName,
    required SellerBusinessType businessType,
    String? businessRegistrationNumber,
    String? taxId,
    String? businessPhone,
    String? businessEmail,
    String? website,
    String? description,
    String? logoUrl,
    String? coverImageUrl,
    List<ServiceArea>? serviceAreas,
    double? commissionRate,
    double? minimumOrderAmount,
    double? deliveryRadiusKm,
    String? bankAccountName,
    String? bankAccountNumber,
    String? bankName,
    String? bankBranch,
    List<String>? verificationDocuments,
    Map<String, String>? socialLinks,
    Map<String, dynamic>? businessHours,
  }) async {
    return saveSellerProfile(
      businessName: businessName,
      businessType: businessType,
      businessRegistrationNumber: businessRegistrationNumber,
      taxId: taxId,
      businessPhone: businessPhone,
      businessEmail: businessEmail,
      website: website,
      description: description,
      serviceAreas: serviceAreas,
      commissionRate: commissionRate,
      minimumOrderAmount: minimumOrderAmount,
      deliveryRadiusKm: deliveryRadiusKm,
      bankAccountName: bankAccountName,
      bankAccountNumber: bankAccountNumber,
      bankName: bankName,
      bankBranch: bankBranch,
      socialLinks: socialLinks,
      businessHours: businessHours,
    );
  }

  static Future<SellerProfileModel> updateSellerProfile({
    String? businessName,
    SellerBusinessType? businessType,
    String? businessRegistrationNumber,
    String? taxId,
    String? businessPhone,
    String? businessEmail,
    String? website,
    String? description,
    String? logoUrl,
    String? coverImageUrl,
    SellerProfileStatus? status,
    bool? emailVerified,
    List<ServiceArea>? serviceAreas,
    double? commissionRate,
    double? minimumOrderAmount,
    double? deliveryRadiusKm,
    String? bankAccountName,
    String? bankAccountNumber,
    String? bankName,
    String? bankBranch,
    List<String>? verificationDocuments,
    Map<String, String>? socialLinks,
    Map<String, dynamic>? businessHours,
  }) async {
    // The API is create-or-update via POST /seller/onboarding; fill gaps
    // from the stored profile so partial updates validate.
    final existing = await fetchSellerProfile();
    return saveSellerProfile(
      businessName: businessName ?? existing?.businessName ?? '',
      businessType:
          businessType ?? existing?.businessType ?? SellerBusinessType.supplier,
      businessRegistrationNumber:
          businessRegistrationNumber ?? existing?.businessRegistrationNumber,
      taxId: taxId ?? existing?.taxId,
      businessPhone: businessPhone ?? existing?.businessPhone,
      businessEmail: businessEmail ?? existing?.businessEmail,
      website: website ?? existing?.website,
      description: description ?? existing?.description,
      serviceAreas: serviceAreas ?? existing?.serviceAreas,
      commissionRate: commissionRate,
      minimumOrderAmount: minimumOrderAmount,
      deliveryRadiusKm: deliveryRadiusKm,
      bankAccountName: bankAccountName ?? existing?.bankAccountName,
      bankAccountNumber: bankAccountNumber ?? existing?.bankAccountNumber,
      bankName: bankName ?? existing?.bankName,
      bankBranch: bankBranch ?? existing?.bankBranch,
      socialLinks: socialLinks ?? existing?.socialLinks,
      businessHours: businessHours ?? existing?.businessHours,
    );
  }

  /// Upload one seller verification document.
  /// [documentType] must be registration|license|insurance|identification|other.
  static Future<List<Map<String, dynamic>>>
  uploadSellerVerificationDocument({
    required String filePath,
    required String documentType,
    String? fileName,
    List<int>? fileBytes,
  }) async {
    final resolvedName = (fileName == null || fileName.isEmpty)
        ? filePath.split('/').last.split(r'\').last
        : fileName;
    final MultipartFile file;
    if (fileBytes != null) {
      file = MultipartFile.fromBytes(fileBytes, filename: resolvedName);
    } else {
      file = await MultipartFile.fromFile(filePath, filename: resolvedName);
    }
    final formData = FormData.fromMap({
      'document_type': documentType,
      'document': file,
    });
    final response = await ApiService.post<Map<String, dynamic>>(
      ApiConstants.sellerDocuments,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    final data = response['data'] as Map<String, dynamic>? ?? {};
    final docs = data['documents'] as List? ?? [];
    return docs
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  // Seller Follows
  static Future<bool> followSeller(String sellerId) async {    try {
      final response = await ApiService.post<Map<String, dynamic>>(
        '/sellers/$sellerId/follow',
      );
      return response['status'] == 'success';
    } catch (e) {
      return false;
    }
  }

  static Future<bool> unfollowSeller(String sellerId) async {
    try {
      final response = await ApiService.delete('/sellers/$sellerId/follow');
      return response['status'] == 'success';
    } catch (e) {
      return false;
    }
  }

  static Future<bool> isFollowingSeller(String sellerId) async {
    try {
      final response = await ApiService.get<Map<String, dynamic>>(
        '/sellers/$sellerId/follow-status',
      );
      final data = response['data'] as Map<String, dynamic>? ?? {};
      return data['is_following'] as bool? ?? false;
    } catch (e) {
      return false;
    }
  }

  static Future<List<SellerFollowModel>> fetchFollowedSellers() async {
    try {
      final response = await ApiService.get<Map<String, dynamic>>(
        '/sellers/following',
      );
      final data = response['data'] as Map<String, dynamic>? ?? {};
      final followsData =
          data['follows'] as List<dynamic>? ??
          data['data'] as List<dynamic>? ??
          [];
      return followsData
          .whereType<Map<String, dynamic>>()
          .map((json) => SellerFollowModel.fromJson(json))
          .toList();
    } catch (e) {
      return const [];
    }
  }

  static Future<int> getSellerFollowerCount(String sellerId) async {
    try {
      final response = await ApiService.get<Map<String, dynamic>>(
        '/sellers/$sellerId/follower-count',
      );
      final data = response['data'] as Map<String, dynamic>? ?? {};
      return (data['count'] as num?)?.toInt() ?? 0;
    } catch (e) {
      return 0;
    }
  }
}

/// Seller onboarding snapshot: profile + completeness info from
/// GET /seller/onboarding.
class SellerOnboarding {
  final SellerProfileModel? profile;
  final bool isComplete;
  final List<String> missingFields;

  const SellerOnboarding({
    this.profile,
    this.isComplete = false,
    this.missingFields = const [],
  });
}
