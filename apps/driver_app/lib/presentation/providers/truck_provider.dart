// lib/presentation/providers/truck_provider.dart
// Driver fleet: my trucks for TruckMatcher eligibility.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sitedrop_core/sitedrop_core.dart';

import 'auth_provider.dart';

/// Trucks owned by the signed-in driver.
final myTrucksProvider =
    FutureProvider.autoDispose<List<TruckModel>>((ref) async {
  final auth = ref.watch(authProvider);
  final user = auth is AsyncData && auth.value is AuthAuthenticated
      ? (auth.value as AuthAuthenticated).user
      : null;
  return TruckService.myTrucks(userId: user?.id);
});

/// Documents for one truck.
final truckDocumentsProvider = FutureProvider.autoDispose
    .family<List<TruckDocumentModel>, String>((ref, truckId) {
  return TruckService.truckDocuments(truckId);
});

/// Insurance policy for one truck (null when none yet).
final truckInsuranceProvider = FutureProvider.autoDispose
    .family<TruckInsuranceModel?, String>((ref, truckId) {
  return TruckService.truckInsurance(truckId);
});

/// Maintenance records for one truck (newest first server-side).
final truckMaintenanceProvider = FutureProvider.autoDispose
    .family<List<TruckMaintenanceModel>, String>((ref, truckId) {
  return TruckService.truckMaintenance(truckId);
});

/// Activity history for one truck (server-logged: created/updated/status,
/// maintenance, insurance, documents, trips).
final truckLogsProvider = FutureProvider.autoDispose
    .family<List<TruckLogModel>, String>((ref, truckId) {
  return TruckService.truckLogs(truckId);
});

/// Trip logs for one truck (auto-created by dispatch on accept/complete).
final truckTripsProvider = FutureProvider.autoDispose
    .family<List<TripModel>, String>((ref, truckId) {
  return TruckService.truckTrips(truckId);
});
