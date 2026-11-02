// lib/presentation/providers/site_provider.dart
// Site providers for seller app

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sitedrop_core/data/models/site.dart';
import 'package:sitedrop_core/data/models/site_document.dart';
import 'package:sitedrop_core/data/models/site_material.dart';
import 'package:sitedrop_core/data/models/site_staff.dart';
import 'package:sitedrop_core/data/models/site_visit.dart';
import 'package:sitedrop_core/data/models/site_status_log.dart';
import 'package:sitedrop_core/data/models/seller_profile.dart';
import 'package:sitedrop_core/data/models/service_area.dart';
import 'package:sitedrop_core/data/models/seller_follow.dart';
import 'package:sitedrop_core/maps/app_map_point.dart';
import 'package:sitedrop_core/data/services/site_service.dart';

// Sites
final sitesProvider = FutureProvider.autoDispose.family<List<SiteModel>, ({String? status, SiteType? siteType, int page})>((ref, params) {
  return SiteService.fetchSites(
    status: params.status,
    siteType: params.siteType,
    page: params.page,
  );
});

final siteDetailProvider = FutureProvider.autoDispose.family<SiteModel?, String>((ref, siteId) {
  return SiteService.fetchSite(siteId);
});

// Site Documents
final siteDocumentsProvider = FutureProvider.autoDispose.family<List<SiteDocumentModel>, String>((ref, siteId) {
  return SiteService.fetchSiteDocuments(siteId);
});

// Site Materials
final siteMaterialsProvider = FutureProvider.autoDispose.family<List<SiteMaterialModel>, String>((ref, siteId) {
  return SiteService.fetchSiteMaterials(siteId);
});

// Site Staff
final siteStaffProvider = FutureProvider.autoDispose.family<List<SiteStaffModel>, ({String siteId, bool? isActive})>((ref, params) {
  return SiteService.fetchSiteStaff(params.siteId, isActive: params.isActive);
});

// Site Visits
final siteVisitsProvider = FutureProvider.autoDispose.family<List<SiteVisitModel>, ({String siteId, VisitStatus? status})>((ref, params) {
  return SiteService.fetchSiteVisits(params.siteId, status: params.status);
});

// Site Status Logs
final siteStatusLogsProvider = FutureProvider.autoDispose.family<List<SiteStatusLogModel>, String>((ref, siteId) {
  return SiteService.fetchSiteStatusLogs(siteId);
});

// Seller Profile
final sellerProfileProvider = FutureProvider.autoDispose<SellerProfileModel?>((ref) {
  return SiteService.fetchSellerProfile();
});

// Seller Follows
final followedSellersProvider = FutureProvider.autoDispose<List<SellerFollowModel>>((ref) {
  return SiteService.fetchFollowedSellers();
});

final sellerFollowerCountProvider = FutureProvider.autoDispose.family<int, String>((ref, sellerId) {
  return SiteService.getSellerFollowerCount(sellerId);
});

final isFollowingSellerProvider = FutureProvider.autoDispose.family<bool, String>((ref, sellerId) {
  return SiteService.isFollowingSeller(sellerId);
});

// Mutation providers
final createSiteProvider = FutureProvider.autoDispose.family<SiteModel, Map<String, dynamic>>((ref, params) {
  return SiteService.createSite(
    name: params['name'] as String,
    address: params['address'] as String,
    siteType: params['siteType'] as SiteType,
    contactPerson: params['contactPerson'] as String?,
    contactPhone: params['contactPhone'] as String?,
    coordinates: params['coordinates'] as AppMapPoint?,
    description: params['description'] as String?,
    sitePhotos: params['sitePhotos'] as List<String>?,
    sizeSqMeters: params['sizeSqMeters'] as double?,
    budget: params['budget'] as double?,
    materialsNeeded: params['materialsNeeded'] as List<String>?,
    priorityLevel: params['priorityLevel'] as PriorityLevel?,
    projectStartDate: params['projectStartDate'] as DateTime?,
    estimatedCompletionDate: params['estimatedCompletionDate'] as DateTime?,
    siteManagerId: params['siteManagerId'] as String?,
    supervisorId: params['supervisorId'] as String?,
    accessNotes: params['accessNotes'] as String?,
    securityRequirements: params['securityRequirements'] as String?,
  );
});

final updateSiteProvider = FutureProvider.autoDispose.family<SiteModel, ({String siteId, Map<String, dynamic> data})>((ref, params) {
  return SiteService.updateSite(
    params.siteId,
    name: params.data['name'] as String?,
    address: params.data['address'] as String?,
    siteType: params.data['siteType'] as SiteType?,
    contactPerson: params.data['contactPerson'] as String?,
    contactPhone: params.data['contactPhone'] as String?,
    coordinates: params.data['coordinates'] as AppMapPoint?,
    description: params.data['description'] as String?,
    sitePhotos: params.data['sitePhotos'] as List<String>?,
    status: params.data['status'] as SiteStatus?,
    sizeSqMeters: params.data['sizeSqMeters'] as double?,
    budget: params.data['budget'] as double?,
    materialsNeeded: params.data['materialsNeeded'] as List<String>?,
    priorityLevel: params.data['priorityLevel'] as PriorityLevel?,
    projectStartDate: params.data['projectStartDate'] as DateTime?,
    estimatedCompletionDate: params.data['estimatedCompletionDate'] as DateTime?,
    siteManagerId: params.data['siteManagerId'] as String?,
    supervisorId: params.data['supervisorId'] as String?,
    accessNotes: params.data['accessNotes'] as String?,
    securityRequirements: params.data['securityRequirements'] as String?,
    statusUpdateReason: params.data['statusUpdateReason'] as String?,
  );
});

final deleteSiteProvider = FutureProvider.autoDispose.family<void, String>((ref, siteId) {
  return SiteService.deleteSite(siteId);
});

final createMaterialProvider = FutureProvider.autoDispose.family<SiteMaterialModel, ({String siteId, Map<String, dynamic> data})>((ref, params) {
  return SiteService.createMaterial(
    params.siteId,
    materialName: params.data['materialName'] as String,
    quantityNeeded: params.data['quantityNeeded'] as double,
    unit: params.data['unit'] as String,
    supplierId: params.data['supplierId'] as String?,
    estimatedCost: params.data['estimatedCost'] as double?,
    expectedDeliveryDate: params.data['expectedDeliveryDate'] as DateTime?,
    notes: params.data['notes'] as String?,
  );
});

final updateMaterialProvider = FutureProvider.autoDispose.family<SiteMaterialModel, ({String siteId, String materialId, Map<String, dynamic> data})>((ref, params) {
  return SiteService.updateMaterial(
    params.siteId,
    params.materialId,
    materialName: params.data['materialName'] as String?,
    quantityNeeded: params.data['quantityNeeded'] as double?,
    quantityDelivered: params.data['quantityDelivered'] as double?,
    unit: params.data['unit'] as String?,
    estimatedCost: params.data['estimatedCost'] as double?,
    actualCost: params.data['actualCost'] as double?,
    deliveryStatus: params.data['deliveryStatus'] as DeliveryStatus?,
    orderedAt: params.data['orderedAt'] as DateTime?,
    expectedDeliveryDate: params.data['expectedDeliveryDate'] as DateTime?,
    deliveredAt: params.data['deliveredAt'] as DateTime?,
    notes: params.data['notes'] as String?,
  );
});

final addStaffProvider = FutureProvider.autoDispose.family<SiteStaffModel, ({String siteId, Map<String, dynamic> data})>((ref, params) {
  return SiteService.addStaff(
    params.siteId,
    userId: params.data['userId'] as String,
    role: params.data['role'] as StaffRole,
    position: params.data['position'] as String,
    startDate: params.data['startDate'] as DateTime,
    endDate: params.data['endDate'] as DateTime?,
    department: params.data['department'] as String?,
    shiftSchedule: params.data['shiftSchedule'] as Map<String, dynamic>?,
    contactEmergency: params.data['contactEmergency'] as Map<String, dynamic>?,
    certifications: params.data['certifications'] as List<String>?,
    skills: params.data['skills'] as List<String>?,
    notes: params.data['notes'] as String?,
  );
});

final updateStaffProvider = FutureProvider.autoDispose.family<SiteStaffModel, ({String siteId, String staffId, Map<String, dynamic> data})>((ref, params) {
  return SiteService.updateStaff(
    params.siteId,
    params.staffId,
    role: params.data['role'] as StaffRole?,
    position: params.data['position'] as String?,
    startDate: params.data['startDate'] as DateTime?,
    endDate: params.data['endDate'] as DateTime?,
    department: params.data['department'] as String?,
    isActive: params.data['isActive'] as bool?,
    shiftSchedule: params.data['shiftSchedule'] as Map<String, dynamic>?,
    contactEmergency: params.data['contactEmergency'] as Map<String, dynamic>?,
    certifications: params.data['certifications'] as List<String>?,
    skills: params.data['skills'] as List<String>?,
    performanceRating: params.data['performanceRating'] as double?,
    lastPerformanceReview: params.data['lastPerformanceReview'] as DateTime?,
    notes: params.data['notes'] as String?,
  );
});

final createVisitProvider = FutureProvider.autoDispose.family<SiteVisitModel, ({String siteId, Map<String, dynamic> data})>((ref, params) {
  return SiteService.createVisit(
    params.siteId,
    visitorName: params.data['visitorName'] as String,
    visitorPhone: params.data['visitorPhone'] as String,
    visitorEmail: params.data['visitorEmail'] as String?,
    visitType: params.data['visitType'] as VisitType,
    visitDate: params.data['visitDate'] as DateTime,
    purpose: params.data['purpose'] as String,
    notes: params.data['notes'] as String?,
    vehicleRegistration: params.data['vehicleRegistration'] as String?,
  );
});

final checkInVisitProvider = FutureProvider.autoDispose.family<SiteVisitModel, ({String siteId, String visitId, Map<String, dynamic> data})>((ref, params) {
  return SiteService.checkInVisit(
    params.siteId,
    params.visitId,
    visitorSignature: params.data['visitorSignature'] as String?,
    hostSignature: params.data['hostSignature'] as String?,
    safetyBriefingCompleted: params.data['safetyBriefingCompleted'] as bool?,
    ppeProvided: params.data['ppeProvided'] as bool?,
    temperature: params.data['temperature'] as double?,
  );
});

final checkOutVisitProvider = FutureProvider.autoDispose.family<SiteVisitModel, ({String siteId, String visitId, Map<String, dynamic> data})>((ref, params) {
  return SiteService.checkOutVisit(
    params.siteId,
    params.visitId,
    visitorSignature: params.data['visitorSignature'] as String?,
    hostSignature: params.data['hostSignature'] as String?,
  );
});

final followSellerProvider = FutureProvider.autoDispose.family<bool, String>((ref, sellerId) {
  return SiteService.followSeller(sellerId);
});

final unfollowSellerProvider = FutureProvider.autoDispose.family<bool, String>((ref, sellerId) {
  return SiteService.unfollowSeller(sellerId);
});

final createSellerProfileProvider = FutureProvider.autoDispose.family<SellerProfileModel, Map<String, dynamic>>((ref, params) {
  return SiteService.createSellerProfile(
    businessName: params['businessName'] as String,
    businessType: params['businessType'] as SellerBusinessType,
    businessRegistrationNumber: params['businessRegistrationNumber'] as String?,
    taxId: params['taxId'] as String?,
    businessPhone: params['businessPhone'] as String?,
    businessEmail: params['businessEmail'] as String?,
    website: params['website'] as String?,
    description: params['description'] as String?,
    logoUrl: params['logoUrl'] as String?,
    coverImageUrl: params['coverImageUrl'] as String?,
    serviceAreas: params['serviceAreas'] as List<ServiceArea>?,
    commissionRate: params['commissionRate'] as double?,
    minimumOrderAmount: params['minimumOrderAmount'] as double?,
    deliveryRadiusKm: params['deliveryRadiusKm'] as double?,
    bankAccountName: params['bankAccountName'] as String?,
    bankAccountNumber: params['bankAccountNumber'] as String?,
    bankName: params['bankName'] as String?,
    bankBranch: params['bankBranch'] as String?,
    verificationDocuments: params['verificationDocuments'] as List<String>?,
    socialLinks: params['socialLinks'] as Map<String, String>?,
    businessHours: params['businessHours'] as Map<String, dynamic>?,
  );
});

final updateSellerProfileProvider = FutureProvider.autoDispose.family<SellerProfileModel, Map<String, dynamic>>((ref, params) {
  return SiteService.updateSellerProfile(
    businessName: params['businessName'] as String?,
    businessType: params['businessType'] as SellerBusinessType?,
    businessRegistrationNumber: params['businessRegistrationNumber'] as String?,
    taxId: params['taxId'] as String?,
    businessPhone: params['businessPhone'] as String?,
    businessEmail: params['businessEmail'] as String?,
    website: params['website'] as String?,
    description: params['description'] as String?,
    logoUrl: params['logoUrl'] as String?,
    coverImageUrl: params['coverImageUrl'] as String?,
    status: params['status'] as SellerProfileStatus?,
    emailVerified: params['emailVerified'] as bool?,
    serviceAreas: params['serviceAreas'] as List<ServiceArea>?,
    commissionRate: params['commissionRate'] as double?,
    minimumOrderAmount: params['minimumOrderAmount'] as double?,
    deliveryRadiusKm: params['deliveryRadiusKm'] as double?,
    bankAccountName: params['bankAccountName'] as String?,
    bankAccountNumber: params['bankAccountNumber'] as String?,
    bankName: params['bankName'] as String?,
    bankBranch: params['bankBranch'] as String?,
    verificationDocuments: params['verificationDocuments'] as List<String>?,
    socialLinks: params['socialLinks'] as Map<String, String>?,
    businessHours: params['businessHours'] as Map<String, dynamic>?,
  );
});