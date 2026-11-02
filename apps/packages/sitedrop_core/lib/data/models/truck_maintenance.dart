// lib/data/models/truck_maintenance.dart
// Maps to Laravel App\Models\TruckMaintenance.

class TruckMaintenanceModel {
  final String id;
  final String truckId;
  final String maintenanceType;
  final String? description;
  final double? cost;
  final DateTime? performedAt;
  final String? performedBy;
  final String? notes;
  final double? mileageAtService;
  final double? nextServiceMileage;
  final String status;

  const TruckMaintenanceModel({
    required this.id,
    required this.truckId,
    required this.maintenanceType,
    this.description,
    this.cost,
    this.performedAt,
    this.performedBy,
    this.notes,
    this.mileageAtService,
    this.nextServiceMileage,
    this.status = 'completed',
  });

  String get typeLabel => maintenanceType.replaceAll('_', ' ');

  factory TruckMaintenanceModel.fromJson(Map<String, dynamic> json) {
    return TruckMaintenanceModel(
      id: '${json['id'] ?? ''}',
      truckId: '${json['truck_id'] ?? ''}',
      maintenanceType: '${json['maintenance_type'] ?? 'routine'}',
      description: json['description']?.toString(),
      cost: _d(json['cost']),
      performedAt: _dt(json['performed_at']),
      performedBy: json['performed_by']?.toString(),
      notes: json['notes']?.toString(),
      mileageAtService: _d(json['mileage_at_service']),
      nextServiceMileage: _d(json['next_service_mileage']),
      status: '${json['status'] ?? 'completed'}',
    );
  }

  static DateTime? _dt(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }

  static double? _d(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}
