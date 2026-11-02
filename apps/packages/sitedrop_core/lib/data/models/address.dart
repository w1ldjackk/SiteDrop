// lib/data/models/address.dart
// Maps to Laravel App\Models\Address
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Backend address_type values: home, office, site, other
enum AddressType { home, office, site, other }

class AddressModel {
  final String id;
  final String userId;
  final AddressType addressType;
  final String? label;
  final String addressLine1;
  final String? addressLine2;
  final String city;
  final String? state;
  final String? postalCode;
  final String country;
  final double? latitude;
  final double? longitude;
  final bool isDefault;
  final String? deliveryInstructions;
  final String? phone;
  final String? receiverName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AddressModel({
    required this.id,
    required this.userId,
    this.addressType = AddressType.home,
    this.label,
    required this.addressLine1,
    this.addressLine2,
    required this.city,
    this.state,
    this.postalCode,
    this.country = 'Ghana',
    this.latitude,
    this.longitude,
    this.isDefault = false,
    this.deliveryInstructions,
    this.phone,
    this.receiverName,
    this.createdAt,
    this.updatedAt,
  });

  // ============================================================
  // PARSE HELPERS
  // ============================================================
  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) {
      return value == '1' || value.toLowerCase() == 'true';
    }
    return false;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  static Map<String, dynamic>? _parseMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  // ============================================================
  // FROM JSON
  // ============================================================
  factory AddressModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> data = json;
    if (json['address'] is Map<String, dynamic>) {
      data = json['address'] as Map<String, dynamic>;
    }

    // Backend stores coordinates as { lat, lng } or { latitude, longitude }
    final coords = _parseMap(data['coordinates']);
    final lat = _parseDouble(
      data['latitude'] ?? coords?['lat'] ?? coords?['latitude'],
    );
    final lng = _parseDouble(
      data['longitude'] ?? coords?['lng'] ?? coords?['longitude'],
    );

    // Support alternate keys from older/mobile payloads
    final line1 =
        data['address_line_1']?.toString() ??
        data['street_address']?.toString() ??
        data['street']?.toString() ??
        '';
    final line2 =
        data['address_line_2']?.toString() ?? data['apartment']?.toString();

    return AddressModel(
      id: data['id']?.toString() ?? '',
      userId: data['user_id']?.toString() ?? '',
      addressType: AddressTypeX.fromApi(
        data['address_type']?.toString() ?? data['type']?.toString(),
      ),
      label: data['label']?.toString(),
      addressLine1: line1,
      addressLine2: line2,
      city: data['city']?.toString() ?? '',
      state: data['state']?.toString() ?? data['region']?.toString(),
      postalCode: data['postal_code']?.toString(),
      country: data['country']?.toString() ?? 'Ghana',
      latitude: lat,
      longitude: lng,
      isDefault: _parseBool(data['is_default'] ?? data['isDefault']),
      deliveryInstructions:
          data['delivery_instructions']?.toString() ??
          data['additional_instructions']?.toString(),
      phone: data['phone']?.toString() ?? data['phone_number']?.toString(),
      receiverName:
          data['receiver_name']?.toString() ??
          data['recipient_name']?.toString(),
      createdAt: _parseDate(data['created_at']),
      updatedAt: _parseDate(data['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'address_type': addressType.apiValue,
      'label': label,
      'address_line_1': addressLine1,
      'address_line_2': addressLine2,
      'city': city,
      'state': state,
      'postal_code': postalCode,
      'country': country,
      // Backend stores JSON `coordinates` and also accepts flat lat/lng.
      if (hasCoordinates) 'coordinates': {'lat': latitude, 'lng': longitude},
      if (hasCoordinates) 'latitude': latitude,
      if (hasCoordinates) 'longitude': longitude,
      'is_default': isDefault,
      'delivery_instructions': deliveryInstructions,
      'phone': phone,
      'receiver_name': receiverName,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  AddressModel copyWith({
    String? id,
    String? userId,
    AddressType? addressType,
    String? label,
    String? addressLine1,
    String? addressLine2,
    String? city,
    String? state,
    String? postalCode,
    String? country,
    double? latitude,
    double? longitude,
    bool? isDefault,
    String? deliveryInstructions,
    String? phone,
    String? receiverName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AddressModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      addressType: addressType ?? this.addressType,
      label: label ?? this.label,
      addressLine1: addressLine1 ?? this.addressLine1,
      addressLine2: addressLine2 ?? this.addressLine2,
      city: city ?? this.city,
      state: state ?? this.state,
      postalCode: postalCode ?? this.postalCode,
      country: country ?? this.country,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isDefault: isDefault ?? this.isDefault,
      deliveryInstructions: deliveryInstructions ?? this.deliveryInstructions,
      phone: phone ?? this.phone,
      receiverName: receiverName ?? this.receiverName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // ============================================================
  // ACCESSORS (mirror backend getFullAddressAttribute)
  // ============================================================
  bool get hasCoordinates => latitude != null && longitude != null;

  LatLng? get latLng {
    if (!hasCoordinates) return null;
    return LatLng(latitude!, longitude!);
  }

  String get displayLabel {
    if (label != null && label!.isNotEmpty) return label!;
    return addressType.displayName;
  }

  String get fullAddress {
    final parts = <String>[
      addressLine1,
      if (addressLine2 != null && addressLine2!.isNotEmpty) addressLine2!,
      city,
      if (state != null && state!.isNotEmpty) state!,
      if (postalCode != null && postalCode!.isNotEmpty) postalCode!,
      country,
    ].where((p) => p.trim().isNotEmpty).toList();
    return parts.join(', ');
  }

  /// Field-level validation messages (empty list = valid for create/update).
  List<String> validate() {
    final errors = <String>[];
    if (addressLine1.trim().isEmpty) errors.add('Street address is required');
    if (city.trim().isEmpty) errors.add('City is required');
    if (receiverName == null || receiverName!.trim().isEmpty) {
      errors.add('Receiver name is required');
    }
    if (phone == null || phone!.trim().isEmpty) {
      errors.add('Phone number is required');
    }
    if (country.trim().isEmpty) errors.add('Country is required');
    return errors;
  }

  bool get isValid => validate().isEmpty;
}

// ============================================================
// ADDRESS BOOK (collection helper — not a backend model)
// ============================================================
class AddressBook {
  final List<AddressModel> addresses;

  const AddressBook({this.addresses = const []});

  factory AddressBook.fromJson(dynamic json) {
    if (json is List) {
      return AddressBook(
        addresses: json
            .whereType<Map<String, dynamic>>()
            .map(AddressModel.fromJson)
            .toList(),
      );
    }
    if (json is Map<String, dynamic>) {
      final list = json['addresses'] ?? json['data'] ?? [];
      if (list is List) {
        return AddressBook(
          addresses: list
              .whereType<Map<String, dynamic>>()
              .map(AddressModel.fromJson)
              .toList(),
        );
      }
    }
    return const AddressBook();
  }

  Map<String, dynamic> toJson() {
    return {
      'addresses': addresses.map((a) => a.toJson()).toList(),
      'default_address_id': defaultAddress?.id,
    };
  }

  AddressModel? get defaultAddress {
    if (addresses.isEmpty) return null;
    try {
      return addresses.firstWhere((a) => a.isDefault);
    } catch (_) {
      return addresses.first;
    }
  }

  String? get defaultAddressId => defaultAddress?.id;
}

// ============================================================
// ADDRESS TYPE
// ============================================================
extension AddressTypeX on AddressType {
  String get apiValue {
    switch (this) {
      case AddressType.home:
        return 'home';
      case AddressType.office:
        return 'office';
      case AddressType.site:
        return 'site';
      case AddressType.other:
        return 'other';
    }
  }

  String get displayName {
    switch (this) {
      case AddressType.home:
        return 'Home';
      case AddressType.office:
        return 'Office';
      case AddressType.site:
        return 'Site';
      case AddressType.other:
        return 'Other';
    }
  }

  static AddressType fromApi(String? value) {
    switch (value?.toLowerCase().trim()) {
      case 'office':
      case 'work':
        return AddressType.office;
      case 'site':
      case 'construction_site':
        return AddressType.site;
      case 'other':
        return AddressType.other;
      case 'home':
      default:
        return AddressType.home;
    }
  }
}
