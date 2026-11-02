// lib/data/models/truck.dart
// Maps to Laravel App\Models\Truck + TruckMatcher eligibility.

class TruckModel {
  final String id;
  final String registrationNumber;
  final String make;
  final String model;
  final int year;
  final String? color;
  final double capacityTons;
  final double? capacityCubicMeters;
  final String vehicleType;
  final String? fuelType;
  final String? ownerType;
  final String? companyName;
  final String status;
  final bool isVerified;
  final DateTime? insuranceExpiry;
  final DateTime? registrationExpiry;
  final double? currentMileage;
  final String? driverId;
  final String? notes;

  const TruckModel({
    required this.id,
    required this.registrationNumber,
    required this.make,
    required this.model,
    required this.year,
    this.color,
    required this.capacityTons,
    this.capacityCubicMeters,
    required this.vehicleType,
    this.fuelType,
    this.ownerType,
    this.companyName,
    this.status = 'available',
    this.isVerified = false,
    this.insuranceExpiry,
    this.registrationExpiry,
    this.currentMileage,
    this.driverId,
    this.notes,
  });

  static double _d(dynamic v) {
    if (v == null) return 0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  static int _i(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    if (v is double) return v.toInt();
    return 0;
  }

  static bool _b(dynamic v) {
    if (v is bool) return v;
    if (v is int) return v == 1;
    if (v is String) return v == '1' || v.toLowerCase() == 'true';
    return false;
  }

  static DateTime? _dt(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }

  factory TruckModel.fromJson(Map<String, dynamic> json) {
    return TruckModel(
      id: '${json['id'] ?? ''}',
      registrationNumber: '${json['registration_number'] ?? ''}',
      make: '${json['make'] ?? ''}',
      model: '${json['model'] ?? ''}',
      year: _i(json['year']),
      color: json['color']?.toString(),
      capacityTons: _d(json['capacity_tons']),
      capacityCubicMeters: json['capacity_cubic_meters'] == null
          ? null
          : _d(json['capacity_cubic_meters']),
      vehicleType: '${json['vehicle_type'] ?? 'tipper'}',
      fuelType: json['fuel_type']?.toString(),
      ownerType: json['owner_type']?.toString(),
      companyName: json['company_name']?.toString(),
      status: '${json['status'] ?? 'available'}',
      isVerified: _b(json['is_verified']),
      insuranceExpiry: _dt(json['insurance_expiry']),
      registrationExpiry: _dt(json['registration_expiry']),
      currentMileage: json['current_mileage'] == null
          ? null
          : _d(json['current_mileage']),
      driverId: json['driver_id']?.toString(),
      notes: json['notes']?.toString(),
    );
  }

  String get displayName => '$make $model ($registrationNumber)';

  bool get insuranceActive =>
      insuranceExpiry == null || insuranceExpiry!.isAfter(DateTime.now());

  /// Matcher eligibility (mirrors backend TruckMatcher::rejectionReason).
  bool get matcherReady =>
      status == 'available' && isVerified && insuranceActive;

  String? get blockerReason {
    if (status != 'available') return 'Truck is $status, not available';
    if (!isVerified) return 'Pending verification';
    if (!insuranceActive) return 'Insurance expired';
    return null;
  }
}
