// lib/presentation/providers/instruments_provider.dart
// Saved MoMo / card / bank instruments.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sitedrop_core/sitedrop_core.dart';

/// My saved instruments (masked), default first server-side.
final instrumentsProvider =
    FutureProvider.autoDispose<List<PaymentInstrumentModel>>((ref) {
  return InstrumentService.fetchMine();
});

/// Default instrument, if any.
final defaultInstrumentProvider =
    FutureProvider.autoDispose<PaymentInstrumentModel?>((ref) async {
  final all = await ref.watch(instrumentsProvider.future);
  for (final i in all) {
    if (i.isDefault) return i;
  }
  return null;
});

/// Saved MoMo wallet for checkout: default MoMo instrument first, else the
/// first MoMo instrument (users rarely flag one as default explicitly).
final defaultMomoInstrumentProvider =
    FutureProvider.autoDispose<PaymentInstrumentModel?>((ref) async {
  final all = await ref.watch(instrumentsProvider.future);
  final momo = all.where((i) => i.type == 'mobile_money').toList();
  if (momo.isEmpty) return null;
  for (final i in momo) {
    if (i.isDefault) return i;
  }
  return momo.first;
});
