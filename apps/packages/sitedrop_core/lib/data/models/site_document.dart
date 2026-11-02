// lib/data/models/site_document.dart
// Site documents — permits, contracts, blueprints, reports, etc.

import '../../core/constants/api_constants.dart';
import '../../core/utils/json_helpers.dart';
class SiteDocumentModel {
  final String id;
  final String siteId;
  final String userId;
  final String title;
  final String? description;
  final DocumentType documentType;
  final String filePath;
  final String fileName;
  final int? fileSize;
  final String? fileExtension;
  final String version;
  final DocumentStatus status;
  final String uploadedBy;
  final String? approvedBy;
  final DateTime? approvedAt;
  final DateTime? expiryDate;
  final bool isConfidential;
  final AccessLevel accessLevel;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SiteDocumentModel({
    required this.id,
    required this.siteId,
    required this.userId,
    required this.title,
    this.description,
    required this.documentType,
    required this.filePath,
    required this.fileName,
    this.fileSize,
    this.fileExtension,
    required this.version,
    required this.status,
    required this.uploadedBy,
    this.approvedBy,
    this.approvedAt,
    this.expiryDate,
    required this.isConfidential,
    required this.accessLevel,
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory SiteDocumentModel.fromJson(Map<String, dynamic> json) {
    return SiteDocumentModel(
      id: json['id']?.toString() ?? '',
      siteId: json['site_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      documentType: DocumentType.fromString(json['document_type']?.toString()),
      filePath: ApiConstants.resolveAssetUrl(json['file_path']?.toString() ?? ''),
      fileName: json['file_name']?.toString() ?? '',
      fileSize: JsonHelpers.toDouble(json['file_size'])?.toInt(),
      fileExtension: json['file_extension']?.toString(),
      version: json['version']?.toString() ?? '1.0',
      status: DocumentStatus.fromString(json['status']?.toString()),
      uploadedBy: json['uploaded_by']?.toString() ?? '',
      approvedBy: json['approved_by']?.toString(),
      approvedAt: _dt(json['approved_at']),
      expiryDate: _dt(json['expiry_date']),
      isConfidential: JsonHelpers.boolean(json['is_confidential']),
      accessLevel: AccessLevel.fromString(json['access_level']?.toString()),
      tags: JsonHelpers.stringList(json['tags']),
      createdAt: _dt(json['created_at']) ?? DateTime.now(),
      updatedAt: _dt(json['updated_at']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'site_id': siteId,
    'user_id': userId,
    'title': title,
    'description': description,
    'document_type': documentType.value,
    'file_path': filePath,
    'file_name': fileName,
    'file_size': fileSize,
    'file_extension': fileExtension,
    'version': version,
    'status': status.value,
    'uploaded_by': uploadedBy,
    'approved_by': approvedBy,
    'approved_at': approvedAt?.toIso8601String(),
    'expiry_date': expiryDate?.toIso8601String(),
    'is_confidential': isConfidential,
    'access_level': accessLevel.value,
    'tags': tags,
  };

  bool get isExpired => expiryDate != null && expiryDate!.isBefore(DateTime.now());
  bool get isActive => status == DocumentStatus.active;
  bool get needsApproval => status == DocumentStatus.draft;

  static DateTime? _dt(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }
}

enum DocumentType {
  permit('permit'),
  contract('contract'),
  blueprint('blueprint'),
  report('report'),
  invoice('invoice'),
  insurance('insurance'),
  certificate('certificate'),
  other('other');

  final String value;
  const DocumentType(this.value);

  static DocumentType fromString(String? s) {
    return DocumentType.values.firstWhere(
      (e) => e.value == s,
      orElse: () => DocumentType.other,
    );
  }

  String get displayName {
    switch (this) {
      case DocumentType.permit:
        return 'Permit';
      case DocumentType.contract:
        return 'Contract';
      case DocumentType.blueprint:
        return 'Blueprint';
      case DocumentType.report:
        return 'Report';
      case DocumentType.invoice:
        return 'Invoice';
      case DocumentType.insurance:
        return 'Insurance';
      case DocumentType.certificate:
        return 'Certificate';
      case DocumentType.other:
        return 'Other';
    }
  }
}

enum DocumentStatus {
  draft('draft'),
  active('active'),
  archived('archived'),
  expired('expired'),
  rejected('rejected');

  final String value;
  const DocumentStatus(this.value);

  static DocumentStatus fromString(String? s) {
    return DocumentStatus.values.firstWhere(
      (e) => e.value == s,
      orElse: () => DocumentStatus.draft,
    );
  }

  String get displayName {
    switch (this) {
      case DocumentStatus.draft:
        return 'Draft';
      case DocumentStatus.active:
        return 'Active';
      case DocumentStatus.archived:
        return 'Archived';
      case DocumentStatus.expired:
        return 'Expired';
      case DocumentStatus.rejected:
        return 'Rejected';
    }
  }
}

enum AccessLevel {
  public('public'),
  private('private'),
  restricted('restricted');

  final String value;
  const AccessLevel(this.value);

  static AccessLevel fromString(String? s) {
    return AccessLevel.values.firstWhere(
      (e) => e.value == s,
      orElse: () => AccessLevel.public,
    );
  }

  String get displayName {
    switch (this) {
      case AccessLevel.public:
        return 'Public';
      case AccessLevel.private:
        return 'Private';
      case AccessLevel.restricted:
        return 'Restricted';
    }
  }
}