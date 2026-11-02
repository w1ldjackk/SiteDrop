// lib/presentation/providers/address_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sitedrop_core/data/models/address.dart';
import 'service_providers.dart';

export 'service_providers.dart' show addressServiceProvider;

/// Full address book for the signed-in user.
final addressBookProvider =
    FutureProvider.autoDispose<AddressBook>((ref) async {
  return ref.watch(addressServiceProvider).getAddressBook();
});

/// Default delivery address (if set).
final defaultAddressProvider =
    FutureProvider.autoDispose<AddressModel?>((ref) async {
  final book = await ref.watch(addressBookProvider.future);
  return book.defaultAddress;
});

/// Single address by id.
final addressDetailProvider =
    FutureProvider.autoDispose.family<AddressModel?, String>((ref, id) {
  return ref.watch(addressServiceProvider).getAddress(id);
});
