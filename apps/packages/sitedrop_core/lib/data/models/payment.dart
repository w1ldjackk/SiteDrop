// lib/data/models/payment.dart
// Maps to Laravel App\Models\Payment
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../app/theme/colors.dart';

/// Backend: Payment::STATUS_*
enum PaymentStatus {
  pending,
  success,
  failed,
  refunded,
  cancelled,
}

/// Backend: Payment::METHOD_* and payment_channel values
enum PaymentMethodType {
  mobileMoney,
  bankTransfer,
  card,
  wallet,
  cash,
}

class PaymentModel {
  final String id;
  final String? orderId;
  final String? userId;
  final String paymentReference;
  final String? transactionId;
  final double amount;
  final String currency;
  final PaymentMethodType paymentMethod;
  final String? paymentChannel;
  final PaymentStatus status;
  final Map<String, dynamic>? metadata;
  final DateTime? paidAt;
  final DateTime? refundedAt;
  final double? refundAmount;
  final String? refundReason;
  final Map<String, dynamic>? gatewayResponse;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const PaymentModel({
    required this.id,
    this.orderId,
    this.userId,
    required this.paymentReference,
    this.transactionId,
    required this.amount,
    this.currency = 'GHS',
    required this.paymentMethod,
    this.paymentChannel,
    required this.status,
    this.metadata,
    this.paidAt,
    this.refundedAt,
    this.refundAmount,
    this.refundReason,
    this.gatewayResponse,
    this.createdAt,
    this.updatedAt,
  });

  // ============================================================
  // PARSE HELPERS
  // ============================================================
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
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
  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    // Nested payment payload support
    Map<String, dynamic> data = json;
    if (json['payment'] is Map<String, dynamic>) {
      data = json['payment'] as Map<String, dynamic>;
    }

    final methodRaw =
        data['payment_method']?.toString() ??
        data['payment_channel']?.toString() ??
        data['method']?.toString() ??
        'mobile_money';

    final statusRaw =
        data['status']?.toString() ?? data['payment_status']?.toString() ?? 'pending';

    return PaymentModel(
      id: data['id']?.toString() ?? '',
      orderId: data['order_id']?.toString(),
      userId: data['user_id']?.toString(),
      paymentReference:
          data['payment_reference']?.toString() ??
          data['reference']?.toString() ??
          '',
      transactionId: data['transaction_id']?.toString(),
      amount: _parseDouble(data['amount']),
      currency: data['currency']?.toString() ?? 'GHS',
      paymentMethod: PaymentMethodTypeX.fromApi(methodRaw),
      paymentChannel: data['payment_channel']?.toString(),
      status: PaymentStatusX.fromApi(statusRaw),
      metadata: _parseMap(data['metadata']),
      paidAt: _parseDate(data['paid_at']),
      refundedAt: _parseDate(data['refunded_at']),
      refundAmount: data['refund_amount'] != null
          ? _parseDouble(data['refund_amount'])
          : null,
      refundReason: data['refund_reason']?.toString(),
      gatewayResponse: _parseMap(data['gateway_response']),
      createdAt: _parseDate(data['created_at']),
      updatedAt: _parseDate(data['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'user_id': userId,
      'payment_reference': paymentReference,
      'transaction_id': transactionId,
      'amount': amount,
      'currency': currency,
      'payment_method': paymentMethod.apiValue,
      'payment_channel': paymentChannel ?? paymentMethod.apiValue,
      'status': status.apiValue,
      'metadata': metadata,
      'paid_at': paidAt?.toIso8601String(),
      'refunded_at': refundedAt?.toIso8601String(),
      'refund_amount': refundAmount,
      'refund_reason': refundReason,
      'gateway_response': gatewayResponse,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  PaymentModel copyWith({
    String? id,
    String? orderId,
    String? userId,
    String? paymentReference,
    String? transactionId,
    double? amount,
    String? currency,
    PaymentMethodType? paymentMethod,
    String? paymentChannel,
    PaymentStatus? status,
    Map<String, dynamic>? metadata,
    DateTime? paidAt,
    DateTime? refundedAt,
    double? refundAmount,
    String? refundReason,
    Map<String, dynamic>? gatewayResponse,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PaymentModel(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      userId: userId ?? this.userId,
      paymentReference: paymentReference ?? this.paymentReference,
      transactionId: transactionId ?? this.transactionId,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentChannel: paymentChannel ?? this.paymentChannel,
      status: status ?? this.status,
      metadata: metadata ?? this.metadata,
      paidAt: paidAt ?? this.paidAt,
      refundedAt: refundedAt ?? this.refundedAt,
      refundAmount: refundAmount ?? this.refundAmount,
      refundReason: refundReason ?? this.refundReason,
      gatewayResponse: gatewayResponse ?? this.gatewayResponse,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // ============================================================
  // DOMAIN HELPERS (mirror backend)
  // ============================================================
  bool get isSuccessful => status == PaymentStatus.success;
  bool get isRefunded => status == PaymentStatus.refunded;
  bool get isPending => status == PaymentStatus.pending;
  bool get isFailed => status == PaymentStatus.failed;

  String get formattedAmount =>
      '$currency ${amount.toStringAsFixed(2)}';

  /// Alias for UI code that expects `reference`
  String get reference => paymentReference;
}

// ============================================================
// PAYMENT STATUS EXTENSIONS
// ============================================================
extension PaymentStatusX on PaymentStatus {
  String get apiValue {
    switch (this) {
      case PaymentStatus.pending:
        return 'pending';
      case PaymentStatus.success:
        return 'success';
      case PaymentStatus.failed:
        return 'failed';
      case PaymentStatus.refunded:
        return 'refunded';
      case PaymentStatus.cancelled:
        return 'cancelled';
    }
  }

  String get displayName {
    switch (this) {
      case PaymentStatus.pending:
        return 'Pending';
      case PaymentStatus.success:
        return 'Success';
      case PaymentStatus.failed:
        return 'Failed';
      case PaymentStatus.refunded:
        return 'Refunded';
      case PaymentStatus.cancelled:
        return 'Cancelled';
    }
  }

  Color get color {
    switch (this) {
      case PaymentStatus.pending:
        return AppColors.warning;
      case PaymentStatus.success:
        return AppColors.success;
      case PaymentStatus.failed:
        return AppColors.error;
      case PaymentStatus.refunded:
        return Colors.purple;
      case PaymentStatus.cancelled:
        return AppColors.grey500;
    }
  }

  static PaymentStatus fromApi(String? value) {
    switch (value?.toLowerCase().trim()) {
      case 'success':
      case 'successful':
      case 'completed': // tolerate older/mobile wording
      case 'paid':
        return PaymentStatus.success;
      case 'failed':
      case 'failure':
        return PaymentStatus.failed;
      case 'refunded':
        return PaymentStatus.refunded;
      case 'cancelled':
      case 'canceled':
        return PaymentStatus.cancelled;
      case 'processing':
        return PaymentStatus.pending;
      case 'pending':
      default:
        return PaymentStatus.pending;
    }
  }
}

// ============================================================
// PAYMENT METHOD EXTENSIONS
// ============================================================
extension PaymentMethodTypeX on PaymentMethodType {
  String get apiValue {
    switch (this) {
      case PaymentMethodType.mobileMoney:
        return 'mobile_money';
      case PaymentMethodType.bankTransfer:
        return 'bank_transfer';
      case PaymentMethodType.card:
        return 'card';
      case PaymentMethodType.wallet:
        return 'wallet';
      case PaymentMethodType.cash:
        return 'cash';
    }
  }

  String get displayName {
    switch (this) {
      case PaymentMethodType.mobileMoney:
        return 'Mobile Money';
      case PaymentMethodType.bankTransfer:
        return 'Bank Transfer';
      case PaymentMethodType.card:
        return 'Card';
      case PaymentMethodType.wallet:
        return 'Wallet';
      case PaymentMethodType.cash:
        return 'Cash on Delivery';
    }
  }

  /// Material icon (fallback / Icon widgets).
  IconData get icon {
    switch (this) {
      case PaymentMethodType.mobileMoney:
        return Icons.phone_android;
      case PaymentMethodType.bankTransfer:
        return Icons.account_balance_outlined;
      case PaymentMethodType.card:
        return Icons.credit_card;
      case PaymentMethodType.wallet:
        return Icons.account_balance_wallet_outlined;
      case PaymentMethodType.cash:
        return Icons.payments_outlined;
    }
  }

  /// Font Awesome brand-quality icon for payment method tiles.
  FaIconData get faIcon {
    switch (this) {
      case PaymentMethodType.mobileMoney:
        return FontAwesomeIcons.mobileScreenButton;
      case PaymentMethodType.bankTransfer:
        return FontAwesomeIcons.buildingColumns;
      case PaymentMethodType.card:
        return FontAwesomeIcons.creditCard;
      case PaymentMethodType.wallet:
        return FontAwesomeIcons.wallet;
      case PaymentMethodType.cash:
        return FontAwesomeIcons.moneyBillWave;
    }
  }

  static PaymentMethodType fromApi(String? value) {
    final v = value?.toLowerCase().trim().replaceAll(' ', '_') ?? '';
    switch (v) {
      case 'mobile_money':
      case 'momo':
      case 'mtn':
      case 'vodafone':
      case 'airteltigo':
        return PaymentMethodType.mobileMoney;
      case 'bank_transfer':
      case 'bank':
        return PaymentMethodType.bankTransfer;
      case 'card':
      case 'debit_card':
      case 'credit_card':
        return PaymentMethodType.card;
      case 'wallet':
        return PaymentMethodType.wallet;
      case 'cash':
      case 'cash_on_delivery':
      case 'cod':
        return PaymentMethodType.cash;
      default:
        return PaymentMethodType.mobileMoney;
    }
  }
}
