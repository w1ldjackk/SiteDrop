// lib/presentation/providers/delivery_provider.dart
// Bolt-style driver loop: live offers inbox + my active deliveries + presence.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sitedrop_core/sitedrop_core.dart';

/// Live trip requests for this driver (`GET /deliveries/offers`).
final deliveryOffersProvider = AsyncNotifierProvider.autoDispose<
    DeliveryOffersNotifier, List<DeliveryOfferModel>>(
  DeliveryOffersNotifier.new,
);

class DeliveryOffersNotifier extends AsyncNotifier<List<DeliveryOfferModel>> {
  @override
  FutureOr<List<DeliveryOfferModel>> build() {
    return DeliveryService.fetchOffers();
  }

  /// Manual refresh — clears to loading so the screen shows the
  /// loading state (same as buyer track-orders refresh).
  Future<void> refresh() async {
    state = const AsyncLoading<List<DeliveryOfferModel>>();
    try {
      state = AsyncData(await DeliveryService.fetchOffers());
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }

  /// Background refresh that keeps showing the last known list while
  /// fetching (no loading flash). Used by the auto-poll timer.
  Future<void> silentRefresh() async {
    try {
      state = AsyncData(await DeliveryService.fetchOffers());
    } catch (_) {
      // Keep showing the last known list on transient errors.
    }
  }
}

/// Deliveries assigned to / accepted by this driver.
final myDeliveriesProvider =
    AsyncNotifierProvider.autoDispose<MyDeliveriesNotifier, List<DeliveryModel>>(
  MyDeliveriesNotifier.new,
);

class MyDeliveriesNotifier extends AsyncNotifier<List<DeliveryModel>> {
  @override
  FutureOr<List<DeliveryModel>> build() {
    return DeliveryService.fetchMyDeliveries();
  }

  /// Manual refresh — clears to loading so the screen shows the
  /// loading state (same as buyer track-orders refresh).
  Future<void> refresh() async {
    state = const AsyncLoading<List<DeliveryModel>>();
    try {
      state = AsyncData(await DeliveryService.fetchMyDeliveries());
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }

  /// Background refresh that keeps showing the last known list while
  /// fetching (no loading flash). Used by the auto-poll timer.
  Future<void> silentRefresh() async {
    try {
      state = AsyncData(await DeliveryService.fetchMyDeliveries());
    } catch (_) {
      // Keep showing the last known list on transient errors.
    }
  }
}

/// Driver statistics (totals, earnings) for Earnings + Profile.
final deliveryStatsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  return DeliveryService.fetchStatistics();
});

/// Online toggle (Bolt "Go online"). Synced to server presence on change.
final driverOnlineProvider =
    NotifierProvider<DriverOnlineNotifier, bool>(
        DriverOnlineNotifier.new);

class DriverOnlineNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

/// Active delivery statuses (still moving) — controls GPS pinging.
const activeDeliveryStatuses = {
  'accepted',
  'picked_up',
  'in_transit',
  'arrived',
};

bool isDeliveryActive(DeliveryModel d) =>
    activeDeliveryStatuses.contains(d.status);
