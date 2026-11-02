// lib/data/models/truck_document.dart
// Maps to Laravel App\Models\TruckDocument.

import '../../core/constants/api_constants.dart';
class TruckDocumentModel {
  final String id;
  final String truckId;
  final String documentType;
  final String title;
  final String? description;
  final String filePath;
  final String fileName;
  final int? fileSize;
  final String? fileExtension;
  final String? documentNumber;
  final DateTime? issueDate;
  final DateTime? expiryDate;
  final String status;
  final bool isRequired;
  final String? notes;

  const TruckDocumentModel({
    required this.id,
    required this.truckId,
    required this.documentType,
    required this.title,
    this.description,
    required this.filePath,
    required this.fileName,
    this.fileSize,
    this.fileExtension,
    this.documentNumber,
    this.issueDate,
    this.expiryDate,
    this.status = 'pending',
    this.isRequired = true,
    this.notes,
  });

  String get typeLabel => documentType.replaceAll('_', ' ');

  bool get isExpired {
    if (expiryDate == null) return false;
    return expiryDate!.isBefore(DateTime.now());
  }

  factory TruckDocumentModel.fromJson(Map<String, dynamic> json) {
    return TruckDocumentModel(
      id: '${json['id'] ?? ''}',
      truckId: '${json['truck_id'] ?? ''}',
      documentType: '${json['document_type'] ?? 'other'}',
      title: '${json['title'] ?? ''}',
      description: json['description']?.toString(),
      filePath: ApiConstants.resolveAssetUrl(json['file_path']?.toString() ?? ''),
      fileName: '${json['file_name'] ?? ''}',
      fileSize: json['file_size'] is int
          ? json['file_size'] as int
          : int.tryParse('${json['file_size'] ?? ''}'),
      fileExtension: json['file_extension']?.toString(),
      documentNumber: json['document_number']?.toString(),
      issueDate: _dt(json['issue_date']),
      expiryDate: _dt(json['expiry_date']),
      status: '${json['status'] ?? 'pending'}',
      isRequired: _b(json['is_required'], fallback: true),
      notes: json['notes']?.toString(),
    );
  }

  static DateTime? _dt(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }

  static bool _b(dynamic v, {required bool fallback}) {
    if (v == null) return fallback;
    if (v is bool) return v;
    if (v is int) return v == 1;
    if (v is String) return v == '1' || v.toLowerCase() == 'true';
    return fallback;
  }
}
