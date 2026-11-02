// lib/presentation/providers/payment_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sitedrop_core/core/constants/app_constants.dart';
import 'package:sitedrop_core/core/utils/app_logger.dart';
import 'package:sitedrop_core/data/models/payment.dart';
import 'package:sitedrop_core/data/services/payment_service.dart';
import 'package:sitedrop_core/data/services/preferences_service.dart';
import 'service_providers.dart';

export 'service_providers.dart' show paymentServiceProvider, dioProvider;

/// Local mirror key for the default method (display name, e.g. Mobile Money).
const _kDefaultMethod = 'default_payment_method';

/// Payment history for the authenticated user.
final paymentHistoryProvider =
    FutureProvider.autoDispose<List<PaymentModel>>((ref) {
  return ref.watch(paymentServiceProvider).getPaymentHistory();
});

/// Available payment methods from the backend.
final paymentMethodsListProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(paymentServiceProvider).getPaymentMethods();
});

/// Verify a payment by reference.
final paymentVerifyProvider = FutureProvider.autoDispose
    .family<PaymentVerifyResponse, String>((ref, reference) {
  return ref.watch(paymentServiceProvider).verifyPayment(reference);
});

/// Payment for a specific order (if any).
final paymentByOrderProvider =
    FutureProvider.autoDispose.family<PaymentModel?, String>((ref, orderId) {
  return ref.watch(paymentServiceProvider).getPaymentByOrder(orderId);
});

/// Default payment method (display name). Local mirror first (fast/offline),
/// then server preference, else Mobile Money.
final defaultPaymentMethodProvider =
    FutureProvider.autoDispose<String>((ref) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final local = prefs.getString(_kDefaultMethod);
    if (local != null && AppConstants.paymentMethods.contains(local)) {
      return local;
    }
  } catch (_) {}
  try {
    final map = await PreferencesService.getPreferences();
    final api = map['default_payment_method']?.toString();
    final display = api == null
        ? null
        : (AppConstants.paymentMethodDisplayMap[api] ??
            AppConstants.paymentMethodDisplayMap[api.toLowerCase()]);
    if (display != null && AppConstants.paymentMethods.contains(display)) {
      return display;
    }
  } catch (e) {
    AppLogger.w('Default payment method sync failed: $e');
  }
  return AppConstants.paymentMethods.first;
});

/// Save default method: local mirror always, server best-effort.
Future<void> saveDefaultPaymentMethod(
  WidgetRef ref,
  String displayName,
) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDefaultMethod, displayName);
  } catch (_) {}
  try {
    await PreferencesService.updatePreferences({
      'default_payment_method':
          AppConstants.paymentMethodApiMap[displayName] ?? displayName,
    });
  } catch (e) {
    AppLogger.w('Default payment method server sync failed: $e');
  }
  ref.invalidate(defaultPaymentMethodProvider);
}
