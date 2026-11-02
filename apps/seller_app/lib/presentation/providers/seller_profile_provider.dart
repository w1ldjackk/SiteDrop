// lib/presentation/providers/seller_profile_provider.dart
// Seller business profile state: onboarding snapshot + mutations.
// Backed by Laravel SellerOnboardingController (/seller/onboarding, /status,
// /submit-for-review, /documents).

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sitedrop_core/data/models/seller_profile.dart';
import 'package:sitedrop_core/data/models/service_area.dart';
import 'package:sitedrop_core/data/services/site_service.dart';

final sellerProfileProvider =
    AsyncNotifierProvider<SellerProfileNotifier, SellerOnboarding>(
      SellerProfileNotifier.new,
    );

class SellerProfileNotifier extends AsyncNotifier<SellerOnboarding> {
  @override
  FutureOr<SellerOnboarding> build() {
    return SiteService.fetchSellerOnboarding();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => SiteService.fetchSellerOnboarding(),
    );
  }

  Future<SellerProfileModel> save({
    required String businessName,
    required SellerBusinessType businessType,
    String? businessRegistrationNumber,
    String? taxId,
    String? businessPhone,
    String? businessEmail,
    String? website,
    String? description,
    List<ServiceArea>? serviceAreas,
    double? deliveryRadiusKm,
    double? minimumOrderAmount,
    String? bankAccountName,
    String? bankAccountNumber,
    String? bankName,
    String? bankBranch,
    Map<String, String>? socialLinks,
    Map<String, dynamic>? businessHours,
    String? logoPath,
    String? coverImagePath,
    List<int>? logoBytes,
    List<int>? coverImageBytes,
    String? logoFileName,
    String? coverFileName,
  }) async {
    final saved = await SiteService.saveSellerProfile(
      businessName: businessName,
      businessType: businessType,
      businessRegistrationNumber: businessRegistrationNumber,
      taxId: taxId,
      businessPhone: businessPhone,
      businessEmail: businessEmail,
      website: website,
      description: description,
      serviceAreas: serviceAreas,
      deliveryRadiusKm: deliveryRadiusKm,
      minimumOrderAmount: minimumOrderAmount,
      bankAccountName: bankAccountName,
      bankAccountNumber: bankAccountNumber,
      bankName: bankName,
      bankBranch: bankBranch,
      socialLinks: socialLinks,
      businessHours: businessHours,
      logoPath: logoPath,
      coverImagePath: coverImagePath,
      logoBytes: logoBytes,
      coverImageBytes: coverImageBytes,
      logoFileName: logoFileName,
      coverFileName: coverFileName,
    );
    await refresh();
    return saved;
  }

  Future<void> uploadVerificationDocument({
    required String filePath,
    required String documentType,
    String? fileName,
    List<int>? fileBytes,
  }) async {
    // Use the upload response's authoritative documents list to patch state
    // immediately, so the list no longer depends on refetch timing. A
    // background refetch then reconciles with the server snapshot.
    final docs = await SiteService.uploadSellerVerificationDocument(
      filePath: filePath,
      documentType: documentType,
      fileName: fileName,
      fileBytes: fileBytes,
    );
    final entries = VerificationDocEntry.listFrom(docs);
    final urls = entries.map((e) => e.url).toList();
    debugPrint(
      '[SellerProfile] upload ok: ${entries.length} doc(s) in response',
    );
    final current = state.value;
    if (current?.profile != null) {
      state = AsyncData(
        SellerOnboarding(
          profile: current!.profile!.copyWith(
            verificationDocuments: urls,
            verificationEntries: entries,
          ),
          isComplete: current.isComplete,
          missingFields: current.missingFields,
        ),
      );
    }
    try {
      final fresh = await SiteService.fetchSellerOnboarding();
      debugPrint(
        '[SellerProfile] background refetch: '
        '${fresh.profile?.verificationEntries.length ?? 0} doc(s)',
      );
      state = AsyncData(fresh);
    } catch (e) {
      // Keep the immediate patch visible; the next watch/refresh reconciles.
      debugPrint('[SellerProfile] background refetch failed: $e');
    }
  }

  Future<SellerProfileModel> submitForReview() async {
    final profile = await SiteService.submitSellerForReview();
    await refresh();
    return profile;
  }
}
