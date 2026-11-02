// lib/presentation/screens/seller/seller_onboarding_screen.dart
// Seller verification status — backed by GET /seller/onboarding + /status.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sitedrop_core/app/routes/route_names.dart';
import 'package:sitedrop_core/app/theme/colors.dart';
import 'package:sitedrop_core/core/utils/helpers.dart';
import 'package:sitedrop_core/data/models/seller_profile.dart';
import '../../providers/seller_profile_provider.dart';
import '../../widgets/common/app_back_button.dart';
import '../../widgets/common/loading_widget.dart';

class SellerOnboardingScreen extends ConsumerStatefulWidget {
  const SellerOnboardingScreen({super.key});

  @override
  ConsumerState<SellerOnboardingScreen> createState() =>
      _SellerOnboardingScreenState();
}

class _SellerOnboardingScreenState
    extends ConsumerState<SellerOnboardingScreen> {
  bool _submitting = false;

  Future<void> _submitForReview() async {
    setState(() => _submitting = true);
    try {
      await ref.read(sellerProfileProvider.notifier).submitForReview();
      if (mounted) {
        Helpers.showSuccessToast('Submitted for review');
      }
    } catch (e) {
      if (mounted) {
        Helpers.showErrorToast(Helpers.errorMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final onboardingAsync = ref.watch(sellerProfileProvider);
    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.surface,
        elevation: 0,
        title: appBarTitle(context, 'Seller Status'),
        leading: const AppBackButton(
          fallbackRoute: RouteNames.sellerDashboard,
          fallbackTabIndex: 0,
        ),
      ),
      body: onboardingAsync.when(
        loading: () => const LoadingWidget(message: 'Loading status…'),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Could not load status: ${Helpers.errorMessage(e)}'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () =>
                      ref.read(sellerProfileProvider.notifier).refresh(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (onboarding) {
          final profile = onboarding.profile;
          if (profile == null) {
            return _NoProfileView(p: p);
          }
          return RefreshIndicator(
            onRefresh: () =>
                ref.read(sellerProfileProvider.notifier).refresh(),
            color: AppColors.primary,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _StatusCard(profile: profile),
                const SizedBox(height: 16),
                if (profile.rejectedReason != null &&
                    profile.rejectedReason!.isNotEmpty)
                  _ReasonCard(
                    title: profile.status == SellerProfileStatus.rejected
                        ? 'Rejection reason'
                        : 'Reviewer note',
                    message: profile.rejectedReason!,
                  ),
                if (onboarding.missingFields.isNotEmpty) ...[
                  _MissingFieldsCard(missing: onboarding.missingFields),
                  const SizedBox(height: 16),
                ],
                if (!onboarding.isComplete)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.infoSurface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: AppColors.info),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Finish the required fields so your account can be approved.',
                            style: TextStyle(
                              fontSize: 13,
                              color: p.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () =>
                        context.push(RouteNames.editProfile),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Edit Business Profile',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    // Verification documents live inside Edit Business
                    // Profile — this screen stays strictly about status.
                    onPressed: () => context.push(RouteNames.editProfile),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'Manage Verification Documents (${profile.verificationDocuments.length})',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (profile.status != SellerProfileStatus.approved)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: (_submitting ||
                              onboarding.missingFields.isNotEmpty)
                          ? null
                          : _submitForReview,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.secondaryDark,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Submit for Review',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _NoProfileView extends StatelessWidget {
  final AppPalette p;

  const _NoProfileView({required this.p});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: p.surfaceMuted,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.storefront_outlined,
                size: 60,
                color: p.iconMuted,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No business profile yet',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: p.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your business profile to start selling on SiteDrop',
              textAlign: TextAlign.center,
              style: TextStyle(color: p.textMuted, fontSize: 15),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.push(RouteNames.editProfile),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Create Business Profile'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final SellerProfileModel profile;

  const _StatusCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(profile.status);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.storefront,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.businessName.isEmpty
                          ? 'Your Business'
                          : profile.businessName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      profile.businessType.displayName,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              // ignore: deprecated_member_use
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                // ignore: deprecated_member_use
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_outlined, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  profile.status.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (profile.sellerCode != null && profile.sellerCode!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Seller code: ${profile.sellerCode}',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
          if (profile.approvedAt != null) ...[
            Text(
              'Approved: ${profile.approvedAt!.day}/${profile.approvedAt!.month}/${profile.approvedAt!.year}',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  Color _statusColor(SellerProfileStatus status) {
    switch (status) {
      case SellerProfileStatus.approved:
        return AppColors.success;
      case SellerProfileStatus.pending:
        return AppColors.warning;
      case SellerProfileStatus.suspended:
      case SellerProfileStatus.rejected:
        return AppColors.error;
    }
  }
}

class _ReasonCard extends StatelessWidget {
  final String title;
  final String message;

  const _ReasonCard({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.error,
            ),
          ),
          const SizedBox(height: 4),
          Text(message),
        ],
      ),
    );
  }
}

class _MissingFieldsCard extends StatelessWidget {
  final List<String> missing;

  const _MissingFieldsCard({required this.missing});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warningSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Missing required fields',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: p.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          ...missing.map(
            (m) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                children: [
                  Icon(Icons.circle, size: 6, color: p.textMuted),
                  const SizedBox(width: 8),
                  Expanded(child: Text(m)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

