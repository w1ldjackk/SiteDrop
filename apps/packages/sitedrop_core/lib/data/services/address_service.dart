// lib/data/services/address_service.dart
// Address book API + local helpers for App\Models\Address
import 'package:dio/dio.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/constants/api_constants.dart';
import '../models/address.dart';
import 'api_service.dart';
import 'location_service.dart';

class AddressService {
  final Dio _dio;
  final LocationService _locationService;

  AddressService(this._dio, {LocationService? locationService})
      : _locationService = locationService ?? LocationService();

  factory AddressService.withDefaultClient() =>
      AddressService(ApiService.dio);

  // ============================================================
  // CRUD
  // ============================================================

  /// GET /addresses
  Future<AddressBook> getAddressBook() async {
    try {
      final response = await _get(ApiConstants.addresses);
      final data = response['data'] ?? response;
      return AddressBook.fromJson(data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return const AddressBook();
      }
      throw AddressException.fromDio(e);
    }
  }

  /// GET /addresses/{id}
  Future<AddressModel?> getAddress(String id) async {
    try {
      final response = await _get(ApiConstants.addressDetail(id));
      final data = response['data'];
      if (data is Map<String, dynamic>) {
        return AddressModel.fromJson(
          data['address'] is Map<String, dynamic>
              ? data['address'] as Map<String, dynamic>
              : data,
        );
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw AddressException.fromDio(e);
    }
  }

  /// POST /addresses
  Future<AddressModel> createAddress(AddressModel address) async {
    final errors = validate(address);
    if (errors.isNotEmpty) {
      throw AddressException(errors.first);
    }

    try {
      final response = await _post(
        ApiConstants.addresses,
        data: address.toJson()..remove('id'),
      );
      final data = response['data'];
      if (data is Map<String, dynamic>) {
        return AddressModel.fromJson(
          data['address'] is Map<String, dynamic>
              ? data['address'] as Map<String, dynamic>
              : data,
        );
      }
      throw AddressException(
        response['message']?.toString() ?? 'Failed to save address',
      );
    } on DioException catch (e) {
      throw AddressException.fromDio(e);
    }
  }

  /// PUT /addresses/{id}
  Future<AddressModel> updateAddress(AddressModel address) async {
    final errors = validate(address);
    if (errors.isNotEmpty) {
      throw AddressException(errors.first);
    }
    if (address.id.isEmpty) {
      throw const AddressException('Address id is required for update');
    }

    try {
      final response = await _put(
        ApiConstants.addressDetail(address.id),
        data: address.toJson(),
      );
      final data = response['data'];
      if (data is Map<String, dynamic>) {
        return AddressModel.fromJson(
          data['address'] is Map<String, dynamic>
              ? data['address'] as Map<String, dynamic>
              : data,
        );
      }
      throw AddressException(
        response['message']?.toString() ?? 'Failed to update address',
      );
    } on DioException catch (e) {
      throw AddressException.fromDio(e);
    }
  }

  /// DELETE /addresses/{id}
  Future<void> deleteAddress(String id) async {
    try {
      ApiService.ensureInitialized();
      await _dio.delete(ApiConstants.addressDetail(id));
    } on DioException catch (e) {
      throw AddressException.fromDio(e);
    }
  }

  /// POST /addresses/{id}/default
  Future<AddressModel> setDefault(String id) async {
    try {
      final response = await _post(ApiConstants.addressSetDefault(id));
      final data = response['data'];
      if (data is Map<String, dynamic>) {
        return AddressModel.fromJson(
          data['address'] is Map<String, dynamic>
              ? data['address'] as Map<String, dynamic>
              : data,
        );
      }
      final book = await getAddressBook();
      return book.defaultAddress ??
          (throw const AddressException('Default address not found'));
    } on DioException catch (e) {
      throw AddressException.fromDio(e);
    }
  }

  // ============================================================
  // VALIDATION
  // ============================================================

  /// Returns list of validation messages (empty = valid).
  List<String> validate(AddressModel address) {
    final errors = <String>[];
    if (address.addressLine1.trim().isEmpty) {
      errors.add('Street address is required');
    }
    if (address.city.trim().isEmpty) {
      errors.add('City is required');
    }
    if (address.receiverName == null || address.receiverName!.trim().isEmpty) {
      errors.add('Receiver name is required');
    }
    if (address.phone == null || address.phone!.trim().isEmpty) {
      errors.add('Phone number is required');
    }
    if (address.country.trim().isEmpty) {
      errors.add('Country is required');
    }
    return errors;
  }

  bool isValid(AddressModel address) => validate(address).isEmpty;

  // ============================================================
  // DISTANCE
  // ============================================================

  /// Distance in km between two saved addresses (requires coordinates).
  double? distanceBetweenAddressesKm(AddressModel a, AddressModel b) {
    if (!a.hasCoordinates || !b.hasCoordinates) return null;
    return _locationService.calculateDistance(a.latLng!, b.latLng!);
  }

  /// Distance from current device location to an address.
  Future<double?> distanceFromCurrentKm(AddressModel address) async {
    if (!address.hasCoordinates) return null;
    try {
      final current = await _locationService.getCurrentLatLng();
      return _locationService.calculateDistance(current, address.latLng!);
    } catch (_) {
      return null;
    }
  }

  /// Sort addresses by distance from [origin] (unknown coords last).
  List<AddressModel> sortByDistance(
    List<AddressModel> addresses,
    LatLng origin,
  ) {
    final copy = List<AddressModel>.from(addresses);
    copy.sort((a, b) {
      final da = a.hasCoordinates
          ? _locationService.calculateDistance(origin, a.latLng!)
          : double.infinity;
      final db = b.hasCoordinates
          ? _locationService.calculateDistance(origin, b.latLng!)
          : double.infinity;
      return da.compareTo(db);
    });
    return copy;
  }

  // ============================================================
  // HTTP
  // ============================================================

  Future<Map<String, dynamic>> _get(String path) async {
    ApiService.ensureInitialized();
    final response = await _dio.get<Map<String, dynamic>>(path);
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> _post(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    ApiService.ensureInitialized();
    final response =
        await _dio.post<Map<String, dynamic>>(path, data: data);
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> _put(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    ApiService.ensureInitialized();
    final response = await _dio.put<Map<String, dynamic>>(path, data: data);
    return response.data ?? <String, dynamic>{};
  }
}

class AddressException implements Exception {
  final String message;
  final int? code;

  const AddressException(this.message, {this.code});

  factory AddressException.fromDio(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;
    String? serverMessage;
    if (data is Map) {
      serverMessage = data['message']?.toString();
    }
    return AddressException(
      serverMessage ?? 'Address service error. Please try again.',
      code: status,
    );
  }

  String get userMessage => message;

  @override
  String toString() => message;
}
