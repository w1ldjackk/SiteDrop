// lib/data/services/delivery_service.dart
// Buyer + driver delivery client: SiteDrop-style offers (first-accept wins),
// status progression, GPS pings, driver presence.

import '../../core/constants/api_constants.dart';
import '../../core/utils/app_logger.dart';
import '../models/delivery.dart';
import '../models/tracking.dart';
import 'api_service.dart';

class DeliveryService {
  /// Driver inbox: live trip requests (`GET /deliveries/offers`).
  static Future<List<DeliveryOfferModel>> fetchOffers() async {
    try {
      final response = await ApiService.get<Map<String, dynamic>>(
        ApiConstants.deliveryOffers,
      );
      final data = response['data'] as Map<String, dynamic>? ?? {};
      final raw = data['offers'] as List<dynamic>? ?? [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(DeliveryOfferModel.fromJson)
          .toList();
    } catch (e) {
      AppLogger.e('❌ Error fetching delivery offers: $e');
      return const [];
    }
  }

  /// Accept a trip request (409 when taken/expired).
  static Future<(bool, String)> acceptOffer(String offerId) async {
    try {
      final response = await ApiService.post<Map<String, dynamic>>(
        ApiConstants.deliveryOfferAccept(offerId),
      );
      final ok = response['status'] == 'success';
      return (
        ok,
        response['message']?.toString() ?? (ok ? 'Accepted' : 'Failed')
      );
    } catch (e) {
      AppLogger.e('❌ Error accepting offer: $e');
      return (false, 'Could not accept — it may be taken or expired');
    }
  }

  static Future<(bool, String)> declineOffer(String offerId) async {
    try {
      final response = await ApiService.post<Map<String, dynamic>>(
        ApiConstants.deliveryOfferDecline(offerId),
      );
      final ok = response['status'] == 'success';
      return (
        ok,
        response['message']?.toString() ?? (ok ? 'Declined' : 'Failed')
      );
    } catch (e) {
      AppLogger.e('❌ Error declining offer: $e');
      return (false, 'Could not decline');
    }
  }

  /// Accept a directly-assigned trip (admin manual assignment).
  static Future<(bool, String)> acceptAssignment(String deliveryId) async {
    try {
      final response = await ApiService.post<Map<String, dynamic>>(
        ApiConstants.deliveryAccept(deliveryId),
      );
      final ok = response['status'] == 'success';
      return (
        ok,
        response['message']?.toString() ?? (ok ? 'Accepted' : 'Failed')
      );
    } catch (e) {
      AppLogger.e('❌ Error accepting assignment: $e');
      return (false, 'Could not accept assignment');
    }
  }

  /// Decline a directly-assigned trip → re-offered to other online drivers.
  static Future<(bool, String)> declineAssignment(String deliveryId) async {
    try {
      final response = await ApiService.post<Map<String, dynamic>>(
        ApiConstants.deliveryDecline(deliveryId),
      );
      final ok = response['status'] == 'success';
      return (
        ok,
        response['message']?.toString() ?? (ok ? 'Declined' : 'Failed')
      );
    } catch (e) {
      AppLogger.e('❌ Error declining assignment: $e');
      return (false, 'Could not decline assignment');
    }
  }

  /// Delivery statistics (driver-scoped: totals + earnings).
  static Future<Map<String, dynamic>> fetchStatistics() async {
    try {
      final response = await ApiService.get<Map<String, dynamic>>(
        ApiConstants.deliveryStatistics,
      );
      final data = response['data'] as Map<String, dynamic>? ?? {};
      return Map<String, dynamic>.from(data);
    } catch (e) {
      AppLogger.e('❌ Error fetching delivery statistics: $e');
      return const {};
    }
  }

  /// My deliveries (driver-scoped server-side).
  static Future<List<DeliveryModel>> fetchMyDeliveries() async {    try {
      final response = await ApiService.get<Map<String, dynamic>>(
        ApiConstants.deliveries,
      );
      final data = response['data'] as Map<String, dynamic>? ?? {};
      final raw = data['deliveries'] as List<dynamic>? ?? [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(DeliveryModel.fromJson)
          .toList();
    } catch (e) {
      AppLogger.e('❌ Error fetching deliveries: $e');
      return const [];
    }
  }

  /// Advance delivery status (picked_up → in_transit → arrived → completed).
  static Future<(bool, String)> updateStatus(
    String deliveryId,
    String status,
  ) async {
    try {
      final response = await ApiService.put<Map<String, dynamic>>(
        ApiConstants.deliveryStatus.replaceAll('{id}', deliveryId),
        data: {'status': status},
      );
      final ok = response['status'] == 'success';
      return (
        ok,
        response['message']?.toString() ?? (ok ? 'Updated' : 'Failed')
      );
    } catch (e) {
      AppLogger.e('❌ Error updating delivery status: $e');
      return (false, 'Could not update status');
    }
  }

  /// GPS ping while carrying an order (feeds the buyer live map).
  static Future<bool> postLocation(
    String deliveryId,
    double lat,
    double lng,
  ) async {
    try {
      final response = await ApiService.post<Map<String, dynamic>>(
        ApiConstants.deliveryLocation.replaceAll('{id}', deliveryId),
        data: {'lat': lat, 'lng': lng},
      );
      return response['status'] == 'success';
    } catch (e) {
      AppLogger.e('❌ Error posting delivery location: $e');
      return false;
    }
  }

  /// Driver presence: online toggle (+GPS for offer targeting).
  static Future<(bool, String)> setPresence({
    required bool online,
    double? lat,
    double? lng,
  }) async {
    try {
      final data = <String, dynamic>{'is_online': online};
      if (lat != null) data['lat'] = lat;
      if (lng != null) data['lng'] = lng;
      final response = await ApiService.post<Map<String, dynamic>>(
        ApiConstants.deliveryPresence,
        data: data,
      );
      final ok = response['status'] == 'success';
      return (
        ok,
        response['message']?.toString() ?? (ok ? 'Updated' : 'Failed')
      );
    } catch (e) {
      AppLogger.e('❌ Error updating presence: $e');
      return (false, 'Could not update status');
    }
  }
}
