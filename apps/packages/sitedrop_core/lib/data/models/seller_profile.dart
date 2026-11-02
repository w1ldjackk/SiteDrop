// lib/data/models/seller_profile.dart
// Seller profiles — business info, verification, service areas, banking.

import 'package:sitedrop_core/core/constants/api_constants.dart';
import 'service_area.dart';

class SellerProfileModel {
  final String id;
  final String userId;
  final String businessName;
  final SellerBusinessType businessType;
  final String? businessRegistrationNumber;
  final String? taxId;
  final String? businessPhone;
  final String? businessEmail;
  final String? website;
  final String? description;
  final String? logoUrl;
  final String? coverImageUrl;
  final SellerProfileStatus status;
  final bool emailVerified;
  final DateTime? approvedAt;
  final String? rejectedReason;
  final List<ServiceArea> serviceAreas;
  final double commissionRate;
  final double minimumOrderAmount;
  final double deliveryRadiusKm;
  final String? bankAccountName;
  final String? bankAccountNumber;
  final String? bankName;
  final String? bankBranch;
  final List<String> verificationDocuments;
  final List<VerificationDocEntry> verificationEntries;
  final Map<String, String> socialLinks;
  final Map<String, dynamic>? businessHours;
  final String? sellerCode;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const SellerProfileModel({
    required this.id,
    required this.userId,
    required this.businessName,
    required this.businessType,
    this.businessRegistrationNumber,
    this.taxId,
    this.businessPhone,
    this.businessEmail,
    this.website,
    this.description,
    this.logoUrl,
    this.coverImageUrl,
    required this.status,
    required this.emailVerified,
    this.approvedAt,
    this.rejectedReason,
    this.serviceAreas = const [],
    required this.commissionRate,
    required this.minimumOrderAmount,
    required this.deliveryRadiusKm,
    this.bankAccountName,
    this.bankAccountNumber,
    this.bankName,
    this.bankBranch,
    this.verificationDocuments = const [],
    this.verificationEntries = const [],
    this.socialLinks = const {},
    this.businessHours,
    this.sellerCode,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  factory SellerProfileModel.fromJson(Map<String, dynamic> json) {
    final areas = <ServiceArea>[];
    if (json['service_areas'] is List) {
      for (final a in json['service_areas'] as List) {
        // Tolerate legacy {lat,lng} pins, [lat,lng] pairs, and full entries.
        if (a is Map) {
          final area = ServiceArea.fromJson(a);
          if (area.point.latitude != 0 || area.point.longitude != 0) {
            areas.add(area);
          }
        } else if (a is List && a.length >= 2) {
          final lat = ServiceArea.fromJson({'lat': a[0], 'lng': a[1]});
          areas.add(lat);
        }
      }
    }

    return SellerProfileModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      businessName: json['business_name']?.toString() ?? '',
      businessType: SellerBusinessType.fromString(json['business_type']?.toString()),
      businessRegistrationNumber: json['business_registration_number']?.toString(),
      taxId: json['tax_id']?.toString(),
      businessPhone: json['business_phone']?.toString(),
      businessEmail: json['business_email']?.toString(),
      website: json['website']?.toString(),
      description: json['description']?.toString(),
      logoUrl: _optUrl(json['logo_url']),
      coverImageUrl: _optUrl(json['cover_image_url']),
      status: SellerProfileStatus.fromString(json['status']?.toString()),
      emailVerified: _boolean(json['email_verified']),
      approvedAt: _dt(json['approved_at']),
      rejectedReason: json['rejected_reason']?.toString(),
      serviceAreas: areas,
      commissionRate: _numD(json['commission_rate']) ?? 10.0,
      minimumOrderAmount: _numD(json['minimum_order_amount']) ?? 0,
      deliveryRadiusKm: _numD(json['delivery_radius_km']) ?? 50,
      bankAccountName: json['bank_account_name']?.toString(),
      bankAccountNumber: json['bank_account_number']?.toString(),
      bankName: json['bank_name']?.toString(),
      bankBranch: json['bank_branch']?.toString(),
      verificationDocuments: _docUrls(json['verification_documents']),
      verificationEntries: _docEntries(json['verification_documents']),
      // The backend casts these to PHP arrays, so empty values arrive as
      // JSON `[]` (JSArray on web) instead of `{}` — never cast with `as Map`.
      socialLinks: _strMap(json['social_links']),
      businessHours: _dynMap(json['business_hours']),
      sellerCode: json['seller_code']?.toString(),
      createdAt: _dt(json['created_at']) ?? DateTime.now(),
      updatedAt: _dt(json['updated_at']) ?? DateTime.now(),
      deletedAt: _dt(json['deleted_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'business_name': businessName,
    'business_type': businessType.value,
    'business_registration_number': businessRegistrationNumber,
    'tax_id': taxId,
    'business_phone': businessPhone,
    'business_email': businessEmail,
    'website': website,
    'description': description,
    'logo_url': logoUrl,
    'cover_image_url': coverImageUrl,
    'status': status.value,
    'email_verified': emailVerified,
    'approved_at': approvedAt?.toIso8601String(),
    'rejected_reason': rejectedReason,
    'service_areas': serviceAreas.map((a) => a.toJson()).toList(),
    'commission_rate': commissionRate,
    'minimum_order_amount': minimumOrderAmount,
    'delivery_radius_km': deliveryRadiusKm,
    'bank_account_name': bankAccountName,
    'bank_account_number': bankAccountNumber,
    'bank_name': bankName,
    'bank_branch': bankBranch,
    'verification_documents': verificationDocuments,
    'social_links': socialLinks,
    'business_hours': businessHours,
    'seller_code': sellerCode,
  };

  bool get isApproved => status == SellerProfileStatus.approved;
  bool get isPending => status == SellerProfileStatus.pending;
  bool get isSuspended => status == SellerProfileStatus.suspended;
  bool get canSell => isApproved && deletedAt == null;

  /// Patch verification docs from the authoritative upload response without
  /// waiting for a refetch (which may race or fail silently).
  SellerProfileModel copyWith({
    List<String>? verificationDocuments,
    List<VerificationDocEntry>? verificationEntries,
  }) {
    return SellerProfileModel(
      id: id,
      userId: userId,
      businessName: businessName,
      businessType: businessType,
      businessRegistrationNumber: businessRegistrationNumber,
      taxId: taxId,
      businessPhone: businessPhone,
      businessEmail: businessEmail,
      website: website,
      description: description,
      logoUrl: logoUrl,
      coverImageUrl: coverImageUrl,
      status: status,
      emailVerified: emailVerified,
      approvedAt: approvedAt,
      rejectedReason: rejectedReason,
      serviceAreas: serviceAreas,
      commissionRate: commissionRate,
      minimumOrderAmount: minimumOrderAmount,
      deliveryRadiusKm: deliveryRadiusKm,
      bankAccountName: bankAccountName,
      bankAccountNumber: bankAccountNumber,
      bankName: bankName,
      bankBranch: bankBranch,
      verificationDocuments: verificationDocuments ?? this.verificationDocuments,
      verificationEntries: verificationEntries ?? this.verificationEntries,
      socialLinks: socialLinks,
      businessHours: businessHours,
      sellerCode: sellerCode,
      createdAt: createdAt,
      updatedAt: updatedAt,
      deletedAt: deletedAt,
    );
  }

  /// Verification docs with their type labels. The API may return plain URL
  /// strings (older rows) or {type, url, uploaded_at} maps.
  static List<VerificationDocEntry> _docEntries(dynamic v) {
    List<dynamic> list;
    if (v is String) {
      list = v.isEmpty ? [] : [v];
    } else if (v is List) {
      list = v;
    } else {
      return [];
    }
    return list
        .map((e) {
          if (e is Map) {
            final url = e['url']?.toString() ?? '';
            if (url.isEmpty) {
              return null;
            }
            final uploadedRaw = e['uploaded_at']?.toString();
            return VerificationDocEntry(
              url: ApiConstants.resolveAssetUrl(url),
              type: e['type']?.toString() ?? 'other',
              uploadedAt: uploadedRaw != null
                  ? DateTime.tryParse(uploadedRaw)
                  : null,
            );
          }
          final url = e?.toString() ?? '';
          if (url.isEmpty) {
            return null;
          }
          return VerificationDocEntry(
            url: ApiConstants.resolveAssetUrl(url),
            type: 'other',
          );
        })
        .whereType<VerificationDocEntry>()
        .toList();
  }

  static List<String> _docUrls(dynamic v) =>
      _docEntries(v).map((e) => e.url).toList();

  /// Resolve relative asset paths, preserving null/empty as-is.
  static String? _optUrl(dynamic v) {
    final s = v?.toString();
    if (s == null || s.isEmpty) {
      return s;
    }
    return ApiConstants.resolveAssetUrl(s);
  }

  static DateTime? _dt(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }

  /// Tolerate empty-PHP-array `[]`, null, and real maps.
  static Map<String, String> _strMap(dynamic v) {
    if (v is Map) {
      return v.map((k, val) => MapEntry(k.toString(), val.toString()));
    }
    return {};
  }

  /// Tolerate empty-PHP-array `[]` (JSArray on web), null, and real maps.
  static Map<String, dynamic>? _dynMap(dynamic v) {
    if (v is Map) {
      return Map<String, dynamic>.from(v);
    }
    return null;
  }

  /// Tolerate bool/int/string (Laravel may send 0/1 or "true"/"false").
  static bool _boolean(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.trim().toLowerCase();
      return s == 'true' || s == '1' || s == 'yes';
    }
    return false;
  }

  /// Tolerate num/string (Laravel decimals often serialize as strings).
  static double? _numD(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}

/// A seller verification document with its backend-assigned type.
class VerificationDocEntry {
  final String url;
  final String type;
  final DateTime? uploadedAt;

  const VerificationDocEntry({
    required this.url,
    required this.type,
    this.uploadedAt,
  });

  String get fileName => url.split('/').last.split('?').first;

  /// Public entry point reusing the profile's tolerant parse logic
  /// (plain URL strings or {type, url, uploaded_at} maps).
  static List<VerificationDocEntry> listFrom(dynamic v) =>
      SellerProfileModel._docEntries(v);

  String get displayType {
    switch (type) {
      case 'registration':
        return 'Registration';
      case 'license':
        return 'License';
      case 'insurance':
        return 'Insurance';
      case 'identification':
        return 'Identification';
      default:
        return 'Other';
    }
  }
}

enum SellerBusinessType {
  quarry('quarry'),
  truckOwner('truck_owner'),
  supplier('supplier'),
  distributor('distributor'),
  retailer('retailer'),
  manufacturer('manufacturer');

  final String value;
  const SellerBusinessType(this.value);

  static SellerBusinessType fromString(String? s) {
    return SellerBusinessType.values.firstWhere(
      (e) => e.value == s,
      orElse: () => SellerBusinessType.supplier,
    );
  }

  String get displayName {
    switch (this) {
      case SellerBusinessType.quarry:
        return 'Quarry';
      case SellerBusinessType.truckOwner:
        return 'Truck Owner';
      case SellerBusinessType.supplier:
        return 'Supplier';
      case SellerBusinessType.distributor:
        return 'Distributor';
      case SellerBusinessType.retailer:
        return 'Retailer';
      case SellerBusinessType.manufacturer:
        return 'Manufacturer';
    }
  }
}

enum SellerProfileStatus {
  pending('pending'),
  approved('approved'),
  suspended('suspended'),
  rejected('rejected');

  final String value;
  const SellerProfileStatus(this.value);

  static SellerProfileStatus fromString(String? s) {
    return SellerProfileStatus.values.firstWhere(
      (e) => e.value == s,
      orElse: () => SellerProfileStatus.pending,
    );
  }

  String get displayName {
    switch (this) {
      case SellerProfileStatus.pending:
        return 'Pending Review';
      case SellerProfileStatus.approved:
        return 'Approved';
      case SellerProfileStatus.suspended:
        return 'Suspended';
      case SellerProfileStatus.rejected:
        return 'Rejected';
    }
  }
}