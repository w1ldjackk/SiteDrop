// lib/presentation/providers/service_providers.dart
// Shared Dio + domain service providers for DI
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sitedrop_core/data/services/address_service.dart';
import 'package:sitedrop_core/data/services/api_service.dart';
import 'package:sitedrop_core/data/services/connectivity_service.dart';
import 'package:sitedrop_core/data/services/location_service.dart';
import 'package:sitedrop_core/data/services/payment_service.dart';

/// Shared Dio client (auth interceptors from [ApiService]).
final dioProvider = Provider<Dio>((ref) {
  ApiService.ensureInitialized();
  return ApiService.dio;
});

final paymentServiceProvider = Provider<PaymentService>((ref) {
  final dio = ref.watch(dioProvider);
  return PaymentService(dio);
});

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

final addressServiceProvider = Provider<AddressService>((ref) {
  final dio = ref.watch(dioProvider);
  final location = ref.watch(locationServiceProvider);
  return AddressService(dio, locationService: location);
});

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService();
  service.start();
  ref.onDispose(service.dispose);
  return service;
});

/// `true` when any network interface is available.
final connectivityOnlineProvider = StreamProvider<bool>((ref) async* {
  final service = ref.watch(connectivityServiceProvider);
  yield await service.isOnline;
  yield* service.onStatusChanged;
});
