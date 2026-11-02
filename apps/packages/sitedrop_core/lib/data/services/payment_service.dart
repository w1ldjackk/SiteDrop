// lib/data/services/payment_service.dart
// Client for Laravel Api\PaymentController + App\Services\Payment\PaymentService
import 'package:dio/dio.dart';

import '../../core/constants/api_constants.dart';
import '../models/payment.dart';
import 'api_service.dart';

/// Injectable payment client. Prefer [paymentServiceProvider] in UI.
class PaymentService {
  final Dio _dio;

  PaymentService(this._dio);

  /// Convenience when not using Riverpod DI.
  factory PaymentService.withDefaultClient() => PaymentService(ApiService.dio);

  // ============================================================
  // PAYMENT METHODS
  // ============================================================

  /// GET /payments/methods
  Future<List<Map<String, dynamic>>> getPaymentMethods() async {
    try {
      final response = await _get(ApiConstants.paymentMethods);
      final data = response['data'];
      if (data is List) {
        return data.whereType<Map<String, dynamic>>().toList();
      }
      if (data is Map<String, dynamic>) {
        final methods = data['methods'] ?? data['payment_methods'];
        if (methods is List) {
          return methods.whereType<Map<String, dynamic>>().toList();
        }
      }
      return const [];
    } on DioException catch (e) {
      throw PaymentException.fromDio(e);
    } catch (e) {
      throw PaymentException(e.toString());
    }
  }

  // ============================================================
  // INITIATE
  // ============================================================

  /// POST /payments/initiate
  /// Body: order_id, payment_method, optional MoMo/card fields
  Future<PaymentInitResponse> initiatePayment({
    required String orderId,
    required PaymentMethodType method,
    String? phoneNumber,
    String? network,
    String? cardToken,
    String? authorizationCode,
    Map<String, dynamic>? extra,
    int maxRetries = 2,
  }) async {
    _validateMethodPayload(
      method: method,
      phoneNumber: phoneNumber,
      network: network,
    );

    final body = <String, dynamic>{
      'order_id': orderId,
      'payment_method': method.apiValue,
      if (phoneNumber != null && phoneNumber.isNotEmpty)
        'phone_number': phoneNumber,
      if (network != null && network.isNotEmpty)
        'network': _normalizeNetwork(network),
      if (cardToken != null && cardToken.isNotEmpty) 'card_token': cardToken,
      if (authorizationCode != null && authorizationCode.isNotEmpty)
        'authorization_code': authorizationCode,
      ...?extra,
    };

    return _withRetry(
      maxRetries: maxRetries,
      action: () async {
        final response = await _post(ApiConstants.paymentInitiate, data: body);

        if (response['status'] == 'success') {
          final data = response['data'];
          final map =
              data is Map<String, dynamic> ? data : <String, dynamic>{};
          return PaymentInitResponse.fromJson({
            ...map,
            'message': map['message'] ?? response['message'],
          });
        }

        throw PaymentException(
          response['message']?.toString() ?? 'Unable to initiate payment',
          code: 400,
        );
      },
    );
  }

  // ============================================================
  // VERIFY
  // ============================================================

  /// GET /payments/verify?payment_reference=
  Future<PaymentVerifyResponse> verifyPayment(
    String reference, {
    int maxRetries = 2,
  }) async {
    if (reference.trim().isEmpty) {
      throw PaymentException('Payment reference is required', code: 400);
    }

    return _withRetry(
      maxRetries: maxRetries,
      action: () async {
        final response = await _get(
          ApiConstants.paymentVerify,
          query: {'payment_reference': reference},
        );

        final data = response['data'];
        final map = data is Map<String, dynamic> ? data : <String, dynamic>{};

        PaymentModel? payment;
        if (map['payment'] is Map<String, dynamic>) {
          payment =
              PaymentModel.fromJson(map['payment'] as Map<String, dynamic>);
        } else if (map.containsKey('payment_reference') ||
            map.containsKey('id')) {
          payment = PaymentModel.fromJson(map);
        }

        return PaymentVerifyResponse(
          success:
              response['status'] == 'success' || map['success'] == true,
          message: response['message']?.toString() ??
              map['message']?.toString() ??
              '',
          payment: payment,
          raw: map,
        );
      },
    );
  }

  // ============================================================
  // HISTORY / BY ORDER
  // ============================================================

  /// GET /payments/history
  Future<List<PaymentModel>> getPaymentHistory({
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final response = await _get(
        ApiConstants.paymentHistory,
        query: {'page': page, 'per_page': perPage},
      );

      final data = response['data'] as Map<String, dynamic>? ?? {};
      final list = data['payments'] as List<dynamic>? ??
          data['data'] as List<dynamic>? ??
          [];

      return list
          .whereType<Map<String, dynamic>>()
          .map(PaymentModel.fromJson)
          .toList();
    } on DioException catch (e) {
      throw PaymentException.fromDio(e);
    }
  }

  /// GET /payments/order/{orderId} when available; falls back to history filter.
  Future<PaymentModel?> getPaymentByOrder(String orderId) async {
    try {
      final response = await _get(ApiConstants.paymentByOrder(orderId));
      final data = response['data'];
      if (data is Map<String, dynamic>) {
        if (data['payment'] is Map<String, dynamic>) {
          return PaymentModel.fromJson(
            data['payment'] as Map<String, dynamic>,
          );
        }
        return PaymentModel.fromJson(data);
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        // Fallback: scan recent history
        final history = await getPaymentHistory(perPage: 50);
        try {
          return history.firstWhere((p) => p.orderId == orderId);
        } catch (_) {
          return null;
        }
      }
      throw PaymentException.fromDio(e);
    }
  }

  // ============================================================
  // HTTP HELPERS
  // ============================================================

  Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    ApiService.ensureInitialized();
    final response = await _dio.get<Map<String, dynamic>>(
      path,
      queryParameters: query,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> _post(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    ApiService.ensureInitialized();
    final response = await _dio.post<Map<String, dynamic>>(
      path,
      data: data,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<T> _withRetry<T>({
    required Future<T> Function() action,
    int maxRetries = 2,
  }) async {
    Object? lastError;
    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        return await action();
      } on DioException catch (e) {
        lastError = e;
        final status = e.response?.statusCode ?? 0;
        // Don't retry client errors (except 408/429)
        final retriable = status == 0 ||
            status == 408 ||
            status == 429 ||
            status >= 500 ||
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.connectionError;

        if (!retriable || attempt == maxRetries) {
          throw PaymentException.fromDio(e);
        }
        await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
      } on PaymentException {
        rethrow;
      } catch (e) {
        lastError = e;
        if (attempt == maxRetries) {
          throw PaymentException(e.toString());
        }
        await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
      }
    }
    throw PaymentException(lastError?.toString() ?? 'Payment failed');
  }

  void _validateMethodPayload({
    required PaymentMethodType method,
    String? phoneNumber,
    String? network,
  }) {
    switch (method) {
      case PaymentMethodType.mobileMoney:
        if (phoneNumber == null || phoneNumber.trim().isEmpty) {
          throw PaymentException(
            'Phone number is required for Mobile Money',
            code: 422,
          );
        }
        if (network == null || network.trim().isEmpty) {
          throw PaymentException(
            'Network is required for Mobile Money (MTN, Vodafone, AirtelTigo)',
            code: 422,
          );
        }
      case PaymentMethodType.card:
      case PaymentMethodType.bankTransfer:
      case PaymentMethodType.wallet:
      case PaymentMethodType.cash:
        break;
    }
  }

  /// Backend expects MTN | Vodafone | AirtelTigo
  String _normalizeNetwork(String network) {
    final n = network.toLowerCase().replaceAll(' ', '');
    if (n.contains('mtn')) return 'MTN';
    if (n.contains('vodafone') || n.contains('telecel')) return 'Vodafone';
    if (n.contains('airtel') || n.contains('tigo')) return 'AirtelTigo';
    return network;
  }
}

// ============================================================
// USER-FACING EXCEPTION
// ============================================================
class PaymentException implements Exception {
  final String message;
  final int? code;

  const PaymentException(this.message, {this.code});

  factory PaymentException.fromDio(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;

    String? serverMessage;
    if (data is Map) {
      serverMessage = data['message']?.toString() ?? data['error']?.toString();
      if (data['errors'] is Map) {
        final errors = data['errors'] as Map;
        if (errors.isNotEmpty) {
          final first = errors.values.first;
          if (first is List && first.isNotEmpty) {
            serverMessage = first.first.toString();
          }
        }
      }
    }

    switch (status) {
      case 400:
        return PaymentException(
          serverMessage ?? 'Invalid payment request',
          code: 400,
        );
      case 402:
        return PaymentException(
          serverMessage ?? 'Payment failed — insufficient funds',
          code: 402,
        );
      case 403:
        return PaymentException(
          serverMessage ?? 'You cannot access this payment',
          code: 403,
        );
      case 404:
        return PaymentException(
          serverMessage ?? 'Payment not found',
          code: 404,
        );
      case 409:
        return PaymentException(
          serverMessage ?? 'Payment already processed',
          code: 409,
        );
      case 422:
        return PaymentException(
          serverMessage ?? 'Payment validation failed',
          code: 422,
        );
      default:
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout) {
          return const PaymentException(
            'Connection timeout. Please try again.',
          );
        }
        if (e.type == DioExceptionType.connectionError) {
          return const PaymentException(
            'No internet connection. Please check your network.',
          );
        }
        return PaymentException(
          serverMessage ?? 'Payment service error. Please try again.',
          code: status,
        );
    }
  }

  /// Alias for UI toasts
  String get userMessage => message;

  @override
  String toString() => message;
}

// ============================================================
// INIT RESPONSE
// ============================================================
class PaymentInitResponse {
  final bool success;
  final String reference;
  final String? paymentId;
  final String? transactionId;
  final String? paymentUrl;
  final String message;
  final bool requiresVerification;
  final bool requiresAction;
  final String? status;
  final PaymentModel? payment;
  final Map<String, dynamic> raw;

  const PaymentInitResponse({
    required this.success,
    required this.reference,
    this.paymentId,
    this.transactionId,
    this.paymentUrl,
    this.message = '',
    this.requiresVerification = false,
    this.requiresAction = false,
    this.status,
    this.payment,
    this.raw = const {},
  });

  factory PaymentInitResponse.fromJson(Map<String, dynamic> json) {
    PaymentModel? payment;
    if (json['payment'] is Map<String, dynamic>) {
      payment = PaymentModel.fromJson(json['payment'] as Map<String, dynamic>);
    }

    final reference = json['reference']?.toString() ??
        json['payment_reference']?.toString() ??
        payment?.paymentReference ??
        '';

    final paymentUrl = json['payment_url']?.toString() ??
        json['paymentUrl']?.toString() ??
        json['authorization_url']?.toString() ??
        json['checkout_url']?.toString();

    final requiresVerification = json['requires_verification'] == true ||
        json['requiresVerification'] == true;

    final requiresAction = requiresVerification ||
        (paymentUrl != null && paymentUrl.isNotEmpty) ||
        json['requires_action'] == true ||
        json['requiresAction'] == true;

    return PaymentInitResponse(
      success: json['success'] != false,
      reference: reference,
      paymentId: json['payment_id']?.toString() ?? payment?.id,
      transactionId: json['transaction_id']?.toString(),
      paymentUrl: paymentUrl,
      message: json['message']?.toString() ?? '',
      requiresVerification: requiresVerification,
      requiresAction: requiresAction,
      status: json['status']?.toString(),
      payment: payment,
      raw: json,
    );
  }
}

// ============================================================
// VERIFY RESPONSE
// ============================================================
class PaymentVerifyResponse {
  final bool success;
  final String message;
  final PaymentModel? payment;
  final Map<String, dynamic> raw;

  const PaymentVerifyResponse({
    required this.success,
    required this.message,
    this.payment,
    this.raw = const {},
  });
}
