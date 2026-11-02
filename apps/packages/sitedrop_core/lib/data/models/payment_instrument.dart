// lib/data/models/payment_instrument.dart
// Saved instrument (MoMo / card / bank). Server never returns full numbers
// except the owner's MoMo phone (needed for prompts); display uses masked.

import 'payment.dart';

class PaymentInstrumentModel {
  final String id;
  final String type; // mobile_money | card | bank
  final String? label;
  final String? network;
  final String? last4;
  final String? exp;
  final String? holder;
  final String? masked;
  final String? phone;
  final bool isDefault;
  final DateTime? createdAt;

  const PaymentInstrumentModel({
    required this.id,
    required this.type,
    this.label,
    this.network,
    this.last4,
    this.exp,
    this.holder,
    this.masked,
    this.phone,
    this.isDefault = false,
    this.createdAt,
  });

  PaymentMethodType get methodType => PaymentMethodTypeX.fromApi(type);

  /// "MTN ••••1234" style headline.
  String get headline {
    final bits = <String>[
      if (network != null && network!.trim().isNotEmpty) network!.trim(),
      if (masked != null && masked!.trim().isNotEmpty) masked!.trim(),
    ];
    if (bits.isNotEmpty) return bits.join(' ');
    return label?.trim().isNotEmpty == true ? label!.trim() : methodType.displayName;
  }

  String get subline {
    switch (type) {
      case 'mobile_money':
        return phone?.trim().isNotEmpty == true ? phone!.trim() : 'Mobile Money';
      case 'card':
        final parts = [
          if (holder != null && holder!.trim().isNotEmpty) holder!.trim(),
          if (exp != null && exp!.trim().isNotEmpty) 'Exp $exp',
        ];
        return parts.isEmpty ? 'Card' : parts.join(' · ');
      default:
        final parts = [
          if (holder != null && holder!.trim().isNotEmpty) holder!.trim(),
          if (network != null && network!.trim().isNotEmpty) network!.trim(),
        ];
        return parts.isEmpty ? 'Bank account' : parts.join(' · ');
    }
  }

  factory PaymentInstrumentModel.fromJson(Map<String, dynamic> json) {
    return PaymentInstrumentModel(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'mobile_money',
      label: json['label']?.toString(),
      network: json['network']?.toString(),
      last4: json['last4']?.toString(),
      exp: json['exp']?.toString(),
      holder: json['holder']?.toString(),
      masked: json['masked']?.toString(),
      phone: json['phone']?.toString(),
      isDefault: json['is_default'] == true ||
          json['is_default'] == 1 ||
          json['is_default'] == '1',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }
}
