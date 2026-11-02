// lib/data/services/instrument_service.dart
// Saved instruments client (MoMo / card / bank).

import '../../core/constants/api_constants.dart';
import '../../core/utils/app_logger.dart';
import '../models/payment.dart';
import '../models/payment_instrument.dart';
import 'api_service.dart';

class InstrumentService {
  InstrumentService._();

  static Future<List<PaymentInstrumentModel>> fetchMine() async {
    try {
      final response = await ApiService.get<Map<String, dynamic>>(
        ApiConstants.paymentInstruments,
      );
      final data = response['data'] as Map<String, dynamic>? ?? {};
      final raw = data['instruments'] as List<dynamic>? ?? [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(PaymentInstrumentModel.fromJson)
          .toList();
    } catch (e) {
      AppLogger.e('❌ Error fetching instruments: $e');
      return const [];
    }
  }

  static Future<(bool, String)> add(Map<String, dynamic> body) async {
    try {
      final response = await ApiService.post<Map<String, dynamic>>(
        ApiConstants.paymentInstruments,
        data: body,
      );
      final ok = response['status'] == 'success';
      return (
        ok,
        response['message']?.toString() ??
            (ok ? 'Payment method saved' : 'Could not save')
      );
    } catch (e) {
      AppLogger.e('❌ Error adding instrument: $e');
      return (false, _serverMessage(e) ?? 'Could not save. Check the details.');
    }
  }

  static Future<(bool, String)> update(
    String id,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await ApiService.put<Map<String, dynamic>>(
        ApiConstants.paymentInstrument(id),
        data: body,
      );
      final ok = response['status'] == 'success';
      return (
        ok,
        response['message']?.toString() ??
            (ok ? 'Payment method updated' : 'Could not update')
      );
    } catch (e) {
      AppLogger.e('❌ Error updating instrument: $e');
      return (false, _serverMessage(e) ?? 'Could not update.');
    }
  }

  static Future<(bool, String)> remove(String id) async {
    try {
      final response = await ApiService.delete<Map<String, dynamic>>(
        ApiConstants.paymentInstrument(id),
      );
      final ok = response['status'] == 'success';
      return (
        ok,
        response['message']?.toString() ??
            (ok ? 'Payment method removed' : 'Could not remove')
      );
    } catch (e) {
      AppLogger.e('❌ Error removing instrument: $e');
      return (false, 'Could not remove.');
    }
  }

  static Future<(bool, String)> setDefault(String id) async {
    try {
      final response = await ApiService.post<Map<String, dynamic>>(
        ApiConstants.paymentInstrumentDefault(id),
      );
      final ok = response['status'] == 'success';
      return (
        ok,
        response['message']?.toString() ??
            (ok ? 'Default updated' : 'Could not update default')
      );
    } catch (e) {
      AppLogger.e('❌ Error setting default instrument: $e');
      return (false, 'Could not update default.');
    }
  }

  /// Server validation message when present (422 JSON).
  static String? _serverMessage(Object e) {
    final text = ApiService.messageFromError(e);
    if (text.trim().isEmpty) return null;
    if (text.contains('Exception') || text.contains('DioException')) {
      return null;
    }
    return text;
  }

  // ============================================================
  // CLIENT-SIDE CHECKS (mirror server rules for instant feedback)
  // ============================================================

  static bool luhnValid(String digits) {
    final number = digits.replaceAll(RegExp(r'\s+'), '');
    if (!RegExp(r'^\d{13,19}$').hasMatch(number)) return false;
    var sum = 0;
    var alt = false;
    for (var i = number.length - 1; i >= 0; i--) {
      var d = int.parse(number[i]);
      if (alt) {
        d *= 2;
        if (d > 9) d -= 9;
      }
      sum += d;
      alt = !alt;
    }
    return sum % 10 == 0;
  }

  static bool expValid(String exp) {
    final m = RegExp(r'^(0[1-9]|1[0-2])\/(\d{2})$').firstMatch(exp.trim());
    if (m == null) return false;
    final month = int.parse(m.group(1)!);
    final year = 2000 + int.parse(m.group(2)!);
    final end = DateTime(year, month + 1, 0, 23, 59, 59);
    return end.isAfter(DateTime.now());
  }

  static String cardBrand(String digits) {
    final n = digits.replaceAll(RegExp(r'\s+'), '');
    if (n.startsWith('4')) return 'Visa';
    if (RegExp(r'^(5[1-5]|2[2-7])').hasMatch(n)) return 'Mastercard';
    if (RegExp(r'^3[47]').hasMatch(n)) return 'Amex';
    return 'Card';
  }

  static String? guessMethodApi(PaymentInstrumentModel i) {
    return switch (i.methodType) {
      PaymentMethodType.mobileMoney => 'mobile_money',
      PaymentMethodType.card => 'card',
      PaymentMethodType.bankTransfer => 'bank_transfer',
      PaymentMethodType.wallet => 'wallet',
      PaymentMethodType.cash => 'cash_on_delivery',
    };
  }
}
