// lib/data/models/truck_insurance.dart
// Maps to Laravel App\Models\TruckInsurance (table `truck_insurance`).

class TruckInsuranceModel {
  final String id;
  final String truckId;
  final String policyNumber;
  final String insuranceCompany;
  final String type;
  final DateTime? coverageStartDate;
  final DateTime? coverageEndDate;
  final double? premiumAmount;
  final String premiumCurrency;
  final String paymentFrequency;
  final String status;
  final String? agentName;
  final String? agentPhone;
  final String? agentEmail;
  final int claimCount;
  final String? notes;

  const TruckInsuranceModel({
    required this.id,
    required this.truckId,
    required this.policyNumber,
    required this.insuranceCompany,
    required this.type,
    this.coverageStartDate,
    this.coverageEndDate,
    this.premiumAmount,
    this.premiumCurrency = 'GHS',
    this.paymentFrequency = 'annually',
    this.status = 'pending',
    this.agentName,
    this.agentPhone,
    this.agentEmail,
    this.claimCount = 0,
    this.notes,
  });

  String get typeLabel => type.replaceAll('_', ' ');

  bool get isActive {
    if (status != 'active') return false;
    if (coverageEndDate == null) return true;
    return coverageEndDate!.isAfter(DateTime.now());
  }

  factory TruckInsuranceModel.fromJson(Map<String, dynamic> json) {
    return TruckInsuranceModel(
      id: '${json['id'] ?? ''}',
      truckId: '${json['truck_id'] ?? ''}',
      policyNumber: '${json['policy_number'] ?? ''}',
      insuranceCompany: '${json['insurance_company'] ?? ''}',
      type: '${json['type'] ?? 'other'}',
      coverageStartDate: _dt(json['coverage_start_date']),
      coverageEndDate: _dt(json['coverage_end_date']),
      premiumAmount: _d(json['premium_amount']),
      premiumCurrency: '${json['premium_currency'] ?? 'GHS'}',
      paymentFrequency: '${json['payment_frequency'] ?? 'annually'}',
      status: '${json['status'] ?? 'pending'}',
      agentName: json['agent_name']?.toString(),
      agentPhone: json['agent_phone']?.toString(),
      agentEmail: json['agent_email']?.toString(),
      claimCount: json['claim_count'] is int
          ? json['claim_count'] as int
          : int.tryParse('${json['claim_count'] ?? 0}') ?? 0,
      notes: json['notes']?.toString(),
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
