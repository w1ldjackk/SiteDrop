// lib/core/utils/display_names.dart
// User-friendly labels for DB-level values (statuses, methods, categories).
// Rule: never render raw snake_case / codes to users — always go through here.

import '../constants/app_constants.dart';

class DisplayNames {
  DisplayNames._();

  /// "in_transit" → "In Transit", "cash-on-delivery" → "Cash On Delivery".
  /// Already-friendly text passes through unchanged.
  static String titleCase(String? value) {
    final words = (value ?? '')
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .split(' ')
        .map((w) => w.trim())
        .where((w) => w.isNotEmpty)
        .map((w) => w.length == 1
            ? w.toUpperCase()
            : w[0].toUpperCase() + w.substring(1).toLowerCase())
        .toList();
    return words.join(' ');
  }

  /// API value ("mobile_money") or display value ("Mobile Money") → display.
  static String paymentMethodLabel(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return '—';
    return AppConstants.paymentMethodDisplayMap[raw] ??
        AppConstants.paymentMethodDisplayMap[raw.toLowerCase()] ??
        titleCase(raw);
  }

  /// "paid" → "Paid". Unknown values get title-cased, never raw.
  static String paymentStatusLabel(String? value) {
    const known = {
      'paid': 'Paid',
      'pending': 'Pending',
      'failed': 'Failed',
      'refunded': 'Refunded',
      'partial': 'Partially paid',
      'unpaid': 'Unpaid',
    };
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return '—';
    return known[raw.toLowerCase()] ?? titleCase(raw);
  }

  /// Delivery/trip statuses for buyer + driver apps.
  static String deliveryStatusLabel(String? value) {
    const known = {
      'pending': 'Pending',
      'assigned': 'Assigned',
      'accepted': 'Accepted',
      'picked_up': 'Picked up',
      'in_transit': 'In transit',
      'arrived': 'Arrived',
      'completed': 'Completed',
      'failed': 'Failed',
      'returned': 'Returned',
    };
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return '—';
    return known[raw.toLowerCase()] ?? titleCase(raw);
  }

  /// Wallet transaction category/type ("deposit" → "Deposit").
  static String transactionLabel(String? value) {
    const known = {
      'credit': 'Money in',
      'debit': 'Money out',
      'deposit': 'Deposit',
      'withdrawal': 'Withdrawal',
      'withdraw': 'Withdrawal',
      'payment': 'Payment',
      'refund': 'Refund',
      'commission': 'Commission',
      'transfer': 'Transfer',
      'topup': 'Top up',
      'top_up': 'Top up',
    };
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return 'Transaction';
    return known[raw.toLowerCase()] ?? titleCase(raw);
  }

  /// Label for generic `List<dynamic>` dropdown items. Plain strings pass
  /// through (title-cased when snake_case: "cubic_meter" → "Cubic Meter"),
  /// enums expose `displayName` (resolved dynamically — safe for raw strings
  /// that have no such member), anything else falls back to toString().
  static String dropdownLabel(dynamic item) {
    if (item == null) return '—';
    if (item is String) return titleCase(item);
    try {
      final label = (item as dynamic).displayName;
      if (label is String && label.isNotEmpty) return label;
    } catch (_) {
      // NoSuchMethodError for members without displayName — use toString.
    }
    return item.toString();
  }
}
