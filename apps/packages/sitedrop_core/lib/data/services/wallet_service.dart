// lib/data/services/wallet_service.dart
import '../../core/constants/api_constants.dart';
import '../../core/utils/app_logger.dart';
import 'api_service.dart';

class WalletService {
  WalletService._();

  static Future<Map<String, dynamic>> fetchWallet() async {
    final response = await ApiService.get<Map<String, dynamic>>(
      ApiConstants.wallet,
    );
    final data = response['data'] as Map<String, dynamic>? ?? {};
    return data['wallet'] as Map<String, dynamic>? ?? {};
  }

  static Future<({Map<String, dynamic> wallet, List<Map<String, dynamic>> txs})>
      fetchTransactions() async {
    try {
      final response = await ApiService.get<Map<String, dynamic>>(
        ApiConstants.walletTransactions,
      );
      final data = response['data'] as Map<String, dynamic>? ?? {};
      final wallet = data['wallet'] as Map<String, dynamic>? ?? {};
      final raw = data['transactions'] as List<dynamic>? ?? [];
      final txs = raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      return (wallet: wallet, txs: txs);
    } catch (e) {
      AppLogger.e('Wallet fetch error: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> requestDeposit({
    required double amount,
    String? note,
    String? paymentMethod,
    String? instrumentId,
  }) async {
    final response = await ApiService.post<Map<String, dynamic>>(
      ApiConstants.walletDeposit,
      data: {
        'amount': amount,
        if (note != null && note.isNotEmpty) 'note': note,
        if (paymentMethod != null && paymentMethod.isNotEmpty)
          'payment_method': paymentMethod,
        if (instrumentId != null && instrumentId.isNotEmpty)
          'instrument_id': instrumentId,
      },
    );
    return response;
  }

  static Future<Map<String, dynamic>> requestWithdraw({
    required double amount,
    String? note,
    String? destination,
  }) async {
    final response = await ApiService.post<Map<String, dynamic>>(
      ApiConstants.walletWithdraw,
      data: {
        'amount': amount,
        if (note != null && note.isNotEmpty) 'note': note,
        if (destination != null && destination.isNotEmpty)
          'destination': destination,
      },
    );
    return response;
  }

  /// Look up a transfer recipient by phone or email (masked for privacy).
  /// Returns null when not found (caller shows friendly error).
  static Future<Map<String, dynamic>?> lookupRecipient(
    String recipient,
  ) async {
    try {
      final response = await ApiService.get<Map<String, dynamic>>(
        ApiConstants.walletLookup,
        queryParams: {'recipient': recipient.trim()},
      );
      if (response['status'] != 'success') return null;
      final data = response['data'] as Map<String, dynamic>? ?? {};
      final r = data['recipient'];
      if (r is Map<String, dynamic>) return r;
      if (r is Map) return Map<String, dynamic>.from(r);
      return null;
    } catch (e) {
      AppLogger.e('Wallet lookup error: $e');
      return null;
    }
  }

  /// Internal transfer to another SiteDrop user (instant).
  /// Throws on validation/balance errors with server messages.
  static Future<Map<String, dynamic>> transfer({
    required String recipient,
    required double amount,
    String? note,
  }) async {
    try {
      final response = await ApiService.post<Map<String, dynamic>>(
        ApiConstants.walletTransfer,
        data: {
          'recipient': recipient.trim(),
          'amount': amount,
          if (note != null && note.isNotEmpty) 'note': note.trim(),
        },
      );
      if (response['status'] != 'success') {
        throw Exception(
          response['message']?.toString() ?? 'Transfer failed',
        );
      }
      return response['data'] as Map<String, dynamic>? ?? {};
    } catch (e) {
      AppLogger.e('Wallet transfer error: $e');
      rethrow;
    }
  }
}
