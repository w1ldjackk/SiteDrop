// lib/data/services/truck_service.dart
// Driver fleet client: my trucks CRUD for TruckMatcher eligibility.

import 'package:dio/dio.dart';

import '../../core/constants/api_constants.dart';
import '../../core/utils/app_logger.dart';
import '../models/trip.dart';
import '../models/truck.dart';
import '../models/truck_document.dart';
import '../models/truck_insurance.dart';
import '../models/truck_log.dart';
import '../models/truck_maintenance.dart';
import 'api_service.dart';

class TruckService {
  /// GET /trucks?user_id=me — backend filters by owner; pass userId when known.
  static Future<List<TruckModel>> myTrucks({String? userId}) async {
    try {
      final response = await ApiService.get<Map<String, dynamic>>(
        ApiConstants.trucks,
        queryParams: userId != null && userId.isNotEmpty
            ? {'user_id': userId}
            : null,
      );
      final data = response['data'] as Map<String, dynamic>? ?? {};
      final raw = data['trucks'] as List<dynamic>? ?? [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(TruckModel.fromJson)
          .toList();
    } catch (e) {
      AppLogger.e('❌ Error fetching trucks: $e');
      return const [];
    }
  }

  static Future<(bool, String, TruckModel?)> createTruck(
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await ApiService.post<Map<String, dynamic>>(
        ApiConstants.trucks,
        data: payload,
      );
      final ok = response['status'] == 'success';
      final data = response['data'];
      TruckModel? truck;
      if (ok && data is Map<String, dynamic>) {
        final raw = data['truck'];
        if (raw is Map<String, dynamic>) truck = TruckModel.fromJson(raw);
      }
      return (
        ok,
        response['message']?.toString() ??
            (ok ? 'Truck added' : 'Failed to add truck'),
        truck,
      );
    } catch (e) {
      AppLogger.e('❌ Error creating truck: $e');
      return (false, 'Could not save truck — check connection', null);
    }
  }

  static Future<(bool, String)> updateTruck(
    String id,
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await ApiService.put<Map<String, dynamic>>(
        ApiConstants.truckDetail(id),
        data: payload,
      );
      final ok = response['status'] == 'success';
      return (
        ok,
        response['message']?.toString() ??
            (ok ? 'Truck updated' : 'Failed to update truck'),
      );
    } catch (e) {
      AppLogger.e('❌ Error updating truck: $e');
      return (false, 'Could not update truck');
    }
  }

  // ============================================================
  // DOCUMENTS — GET|POST /trucks/{id}/documents, DELETE …/{docId}
  // ============================================================
  static Future<List<TruckDocumentModel>> truckDocuments(String truckId) async {
    try {
      final response = await ApiService.get<Map<String, dynamic>>(
        ApiConstants.trucksDocuments.replaceAll('{truckId}', truckId),
      );
      final data = response['data'];
      final raw = data is List ? data : const [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(TruckDocumentModel.fromJson)
          .toList();
    } catch (e) {
      AppLogger.e('❌ Error fetching truck documents: $e');
      return const [];
    }
  }

  static Future<(bool, String)> uploadTruckDocument({
    required String truckId,
    required String filePath,
    required String fileName,
    required String documentType,
    required String title,
    String? description,
    String? expiryDate,
  }) async {
    try {
      final form = FormData.fromMap({
        'document': await MultipartFile.fromFile(filePath, filename: fileName),
        'document_type': documentType,
        'title': title,
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
        if (expiryDate != null && expiryDate.trim().isNotEmpty)
          'expiry_date': expiryDate.trim(),
      });
      final response = await ApiService.post<Map<String, dynamic>>(
        ApiConstants.trucksDocuments.replaceAll('{truckId}', truckId),
        data: form,
      );
      final ok = response['status'] == 'success';
      return (
        ok,
        response['message']?.toString() ??
            (ok ? 'Document uploaded' : 'Failed to upload document'),
      );
    } catch (e) {
      AppLogger.e('❌ Error uploading truck document: $e');
      return (false, 'Could not upload document — check connection');
    }
  }

  static Future<(bool, String)> deleteTruckDocument({
    required String truckId,
    required String documentId,
  }) async {
    try {
      final response = await ApiService.delete<Map<String, dynamic>>(
        '${ApiConstants.trucksDocuments.replaceAll('{truckId}', truckId)}/$documentId',
      );
      final ok = response['status'] == 'success';
      return (
        ok,
        response['message']?.toString() ??
            (ok ? 'Document deleted' : 'Failed to delete document'),
      );
    } catch (e) {
      AppLogger.e('❌ Error deleting truck document: $e');
      return (false, 'Could not delete document');
    }
  }

  // ============================================================
  // INSURANCE — GET|POST /trucks/{id}/insurance, PUT …/{insuranceId}
  // ============================================================
  static Future<TruckInsuranceModel?> truckInsurance(String truckId) async {
    try {
      final response = await ApiService.get<Map<String, dynamic>>(
        ApiConstants.trucksInsurance.replaceAll('{truckId}', truckId),
      );
      final data = response['data'];
      if (data is Map<String, dynamic>) {
        return TruckInsuranceModel.fromJson(data);
      }
      return null;
    } catch (e) {
      AppLogger.e('❌ Error fetching truck insurance: $e');
      return null;
    }
  }

  static Future<(bool, String)> saveTruckInsurance({
    required String truckId,
    String? insuranceId,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final base =
          ApiConstants.trucksInsurance.replaceAll('{truckId}', truckId);
      final response = insuranceId == null
          ? await ApiService.post<Map<String, dynamic>>(base, data: payload)
          : await ApiService.put<Map<String, dynamic>>(
              '$base/$insuranceId',
              data: payload,
            );
      final ok = response['status'] == 'success';
      return (
        ok,
        response['message']?.toString() ??
            (ok ? 'Insurance saved' : 'Failed to save insurance'),
      );
    } catch (e) {
      AppLogger.e('❌ Error saving truck insurance: $e');
      return (false, 'Could not save insurance — check connection');
    }
  }

  // ============================================================
  // MAINTENANCE — GET|POST /trucks/{id}/maintenance, PUT …/{recordId}
  // ============================================================
  static Future<List<TruckMaintenanceModel>> truckMaintenance(
    String truckId,
  ) async {
    try {
      final response = await ApiService.get<Map<String, dynamic>>(
        ApiConstants.trucksMaintenance.replaceAll('{truckId}', truckId),
      );
      final data = response['data'];
      final raw = data is List ? data : const [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(TruckMaintenanceModel.fromJson)
          .toList();
    } catch (e) {
      AppLogger.e('❌ Error fetching truck maintenance: $e');
      return const [];
    }
  }

  static Future<(bool, String)> addTruckMaintenance({
    required String truckId,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final response = await ApiService.post<Map<String, dynamic>>(
        ApiConstants.trucksMaintenance.replaceAll('{truckId}', truckId),
        data: payload,
      );
      final ok = response['status'] == 'success';
      return (
        ok,
        response['message']?.toString() ??
            (ok ? 'Maintenance logged' : 'Failed to log maintenance'),
      );
    } catch (e) {
      AppLogger.e('❌ Error adding truck maintenance: $e');
      return (false, 'Could not log maintenance — check connection');
    }
  }

  // ============================================================
  // TRUCK LOGS — GET /trucks/{id}/logs (activity history)
  // ============================================================
  static Future<List<TruckLogModel>> truckLogs(String truckId) async {
    try {
      final response = await ApiService.get<Map<String, dynamic>>(
        ApiConstants.truckLogs(truckId),
        queryParams: {'per_page': 50},
      );
      final data = response['data'];
      final raw = data is Map<String, dynamic> ? data['logs'] : null;
      final list = raw is List ? raw : const [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(TruckLogModel.fromJson)
          .toList();
    } catch (e) {
      AppLogger.e('❌ Error fetching truck logs: $e');
      return const [];
    }
  }

  // ============================================================
  // TRIP LOGS — GET /trips?truck_id= (server-created on dispatch)
  // ============================================================
  static Future<List<TripModel>> truckTrips(String truckId) async {
    try {
      final response = await ApiService.get<Map<String, dynamic>>(
        ApiConstants.trips,
        queryParams: {'truck_id': truckId, 'per_page': 20},
      );
      final data = response['data'];
      final raw = data is Map<String, dynamic> ? data['trips'] : null;
      final list = raw is List ? raw : const [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(TripModel.fromJson)
          .toList();
    } catch (e) {
      AppLogger.e('❌ Error fetching truck trips: $e');
      return const [];
    }
  }
}
