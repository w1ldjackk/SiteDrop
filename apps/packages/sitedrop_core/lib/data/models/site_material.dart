// lib/data/models/site_material.dart
// Site materials — materials needed/delivered for a site.

import '../../core/utils/json_helpers.dart';

class SiteMaterialModel {
  final String id;
  final String siteId;
  final String? supplierId;
  final String materialName;
  final double quantityNeeded;
  final double quantityDelivered;
  final String unit;
  final double? estimatedCost;
  final double? actualCost;
  final DeliveryStatus deliveryStatus;
  final DateTime? orderedAt;
  final DateTime? expectedDeliveryDate;
  final DateTime? deliveredAt;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SiteMaterialModel({
    required this.id,
    required this.siteId,
    this.supplierId,
    required this.materialName,
    required this.quantityNeeded,
    required this.quantityDelivered,
    required this.unit,
    this.estimatedCost,
    this.actualCost,
    required this.deliveryStatus,
    this.orderedAt,
    this.expectedDeliveryDate,
    this.deliveredAt,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SiteMaterialModel.fromJson(Map<String, dynamic> json) {
    return SiteMaterialModel(
      id: json['id']?.toString() ?? '',
      siteId: json['site_id']?.toString() ?? '',
      supplierId: json['supplier_id']?.toString(),
      materialName: json['material_name']?.toString() ?? '',
      quantityNeeded: JsonHelpers.toDouble(json['quantity_needed']) ?? 0,
      quantityDelivered: JsonHelpers.toDouble(json['quantity_delivered']) ?? 0,
      unit: json['unit']?.toString() ?? '',
      estimatedCost: JsonHelpers.toDouble(json['estimated_cost']),
      actualCost: JsonHelpers.toDouble(json['actual_cost']),
      deliveryStatus: DeliveryStatus.fromString(json['delivery_status']?.toString()),
      orderedAt: _dt(json['ordered_at']),
      expectedDeliveryDate: _dt(json['expected_delivery_date']),
      deliveredAt: _dt(json['delivered_at']),
      notes: json['notes']?.toString(),
      createdAt: _dt(json['created_at']) ?? DateTime.now(),
      updatedAt: _dt(json['updated_at']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'site_id': siteId,
    'supplier_id': supplierId,
    'material_name': materialName,
    'quantity_needed': quantityNeeded,
    'quantity_delivered': quantityDelivered,
    'unit': unit,
    'estimated_cost': estimatedCost,
    'actual_cost': actualCost,
    'delivery_status': deliveryStatus.value,
    'ordered_at': orderedAt?.toIso8601String(),
    'expected_delivery_date': expectedDeliveryDate?.toIso8601String(),
    'delivered_at': deliveredAt?.toIso8601String(),
    'notes': notes,
  };

  double get quantityPending => quantityNeeded - quantityDelivered;
  double get deliveryProgress => quantityNeeded > 0 ? quantityDelivered / quantityNeeded : 0;
  bool get isCompleted => deliveryStatus == DeliveryStatus.completed;
  bool get isPartial => deliveryStatus == DeliveryStatus.partial;
  bool get isPending => deliveryStatus == DeliveryStatus.pending;

  static DateTime? _dt(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }
}

enum DeliveryStatus {
  pending('pending'),
  partial('partial'),
  completed('completed');

  final String value;
  const DeliveryStatus(this.value);

  static DeliveryStatus fromString(String? s) {
    return DeliveryStatus.values.firstWhere(
      (e) => e.value == s,
      orElse: () => DeliveryStatus.pending,
    );
  }

  String get displayName {
    switch (this) {
      case DeliveryStatus.pending:
        return 'Pending';
      case DeliveryStatus.partial:
        return 'Partial';
      case DeliveryStatus.completed:
        return 'Completed';
    }
  }
}