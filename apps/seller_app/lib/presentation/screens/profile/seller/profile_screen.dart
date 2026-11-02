// lib/presentation/screens/profile/seller/profile_screen.dart
// Profile for sellers backed by backend SellerProfile.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sitedrop_core/app/routes/route_names.dart';
import 'package:sitedrop_core/app/theme/colors.dart';
import 'package:sitedrop_core/data/models/seller_profile.dart';
import 'package:sitedrop_core/data/models/truck.dart';
import 'package:sitedrop_core/data/services/truck_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/seller_profile_provider.dart';
import '../../../providers/site_provider.dart'
    hide sellerProfileProvider;
import '../shared/profile_ui.dart';

/// Maps to Laravel `App\Models\SellerProfile`.
/// Fields: business_name, business_type, status, service_areas,
/// commission_rate, bank details, verification, etc.
class SellerProfileScreen extends ConsumerWidget {
  const SellerProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState is AsyncData && authState.value is AuthAuthenticated
        ? (authState.value as AuthAuthenticated).user
        : null;
    final onboardingAsync = ref.watch(sellerProfileProvider);
    final profile = onboardingAsync.asData?.value.profile;

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: buildProfileAppBar(
        context: context,
        user: user,
        subtitle: _subtitle(user?.phone, profile),
      ),
      body: user != null
          ? SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (profile != null) _BusinessHeader(profile: profile),
                  if (profile != null) const SizedBox(height: 16),
                  buildProfileMenuSection(
                    context: context,
                    title: 'Business',
                    items: [
                      ProfileMenuItem(
                        icon: Icons.storefront_outlined,
                        title: 'Edit Business Profile',
                        subtitle: profile != null
                            ? '${profile.businessName} · ${profile.businessType.displayName} · ${profile.verificationDocuments.length} docs'
                            : 'Business name, type, areas, bank, documents',
                        onTap: () => context.push(RouteNames.editProfile),
                      ),
                      ProfileMenuItem(
                        icon: Icons.verified_outlined,
                        title: 'Seller Status',
                        subtitle: profile != null
                            ? profile.status.displayName
                            : 'pending / approved / suspended',
                        badge: profile != null &&
                                profile.status ==
                                    SellerProfileStatus.pending
                            ? '!'
                            : null,
                        onTap: () => context.push(RouteNames.sellerOnboarding),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const _SitesSection(),
                  const SizedBox(height: 16),
                  const _TrucksSection(),
                  const SizedBox(height: 16),
                  buildSupportMenuSection(context),
                  const SizedBox(height: 24),
                  buildProfileLogoutButton(ref, context),
                  const SizedBox(height: 20),
                ],
              ),
            )
          : buildProfileGuestView(context),
    );
  }

  String? _subtitle(String? phone, SellerProfileModel? profile) {
    final parts = <String>['Seller'];
    if (profile != null && profile.businessName.isNotEmpty) {
      parts.add(profile.businessName);
    }
    if (phone != null && phone.isNotEmpty) {
      parts.add(phone);
    }
    return parts.join(' · ');
  }
}

class _BusinessHeader extends StatelessWidget {
  final SellerProfileModel profile;

  const _BusinessHeader({required this.profile});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: profile.status.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.storefront_outlined,
              color: profile.status.color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.businessName.isEmpty
                      ? 'Business profile'
                      : profile.businessName,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: p.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${profile.businessType.displayName} · ${profile.status.displayName}',
                  style: TextStyle(fontSize: 12, color: p.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

extension on SellerProfileStatus {
  Color get color {
    switch (this) {
      case SellerProfileStatus.approved:
        return Colors.green;
      case SellerProfileStatus.pending:
        return Colors.orange;
      case SellerProfileStatus.suspended:
      case SellerProfileStatus.rejected:
        return Colors.red;
    }
  }
}

/// "My Sites" — the seller's construction sites with quick add + manage.
/// First page of [sitesProvider]; rows open the site detail screen.
class _SitesSection extends ConsumerWidget {
  const _SitesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    String? userId;
    ref.read(authProvider).when(
      data: (state) {
        if (state is AuthAuthenticated) {
          userId = state.user.id;
        }
      },
      loading: () {},
      error: (_, _) {},
    );
    final sitesAsync = ref.watch(
      sitesProvider((status: null, siteType: null, page: 1)),
    );

    return Material(
      color: p.surface,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: p.border, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
              child: Row(
                children: [
                  const Text(
                    'My Sites',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  sitesAsync.maybeWhen(
                    data: (sites) {
                      final filtered = userId != null ? sites.where((s) => s.userId == userId).toList() : [];
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${filtered.length}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      );
                    },
                    orElse: () => const SizedBox.shrink(),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Refresh sites',
                    onPressed: () => ref.invalidate(
                      sitesProvider((status: null, siteType: null, page: 1)),
                    ),
                    icon: Icon(Icons.refresh, size: 20, color: p.iconMuted),
                  ),
                  IconButton(
                    tooltip: 'Add site',
                    onPressed: () => context.push(RouteNames.addSite),
                    icon: const Icon(
                      Icons.add_circle_outline,
                      size: 22,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            sitesAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                ),
              ),
              error: (_, _) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Could not load sites.',
                        style: TextStyle(fontSize: 13, color: p.textMuted),
                      ),
                    ),
                    TextButton(
                      onPressed: () => ref.invalidate(
                        sitesProvider((status: null, siteType: null, page: 1)),
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (sites) {
                final filtered = userId != null ? sites.where((s) => s.userId == userId).toList() : [];
                if (filtered.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No sites yet — add your first construction site, quarry or warehouse.',
                          style: TextStyle(
                            fontSize: 13,
                            color: p.textMuted,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => context.push(RouteNames.addSite),
                            icon: const Icon(Icons.add),
                            label: const Text('Add Site'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(
                                color: AppColors.primary,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                final shown = filtered.take(3).toList();
                return Column(
                  children: [
                    ...shown.asMap().entries.map((entry) {
                      final site = entry.value;
                      final last = entry.key == shown.length - 1;
                      return Column(
                        children: [
                          ListTile(
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                site.siteType.icon,
                                color: AppColors.primary,
                                size: 22,
                              ),
                            ),
                            title: Text(
                              site.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              '${site.siteType.displayName} · ${site.status.displayName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: p.textMuted,
                              ),
                            ),
                            trailing: Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: p.iconMuted,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 2,
                            ),
                            onTap: () => context.push(
                              RouteNames.siteDetailWithId(site.id),
                            ),
                          ),
                          if (!last)
                            Divider(
                              height: 1,
                              color: p.divider,
                              indent: 16,
                              endIndent: 16,
                            ),
                        ],
                      );
                    }),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  context.push(RouteNames.addSite),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Add Site'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: const BorderSide(
                                  color: AppColors.primary,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: () => context.push(
                                RouteNames.sitesManagement,
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Manage Sites'),
                            ),
                          ),
                        ],
                      ),
                     ),
                   ],
                 );
               },
             ),
           ],
         ),
       ),
     );
   }
}

class _TrucksSection extends ConsumerWidget {
  const _TrucksSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    String? userId;
    ref.read(authProvider).when(
      data: (state) {
        if (state is AuthAuthenticated) {
          userId = state.user.id;
        }
      },
      loading: () {},
      error: (_, _) {},
    );

    return Material(
      color: p.surface,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: p.border, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
              child: Row(
                children: [
                  const Text(
                    'My Trucks',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FutureBuilder<List<TruckModel>>(
                    future: userId != null ? TruckService.myTrucks(userId: userId) : Future.value([]),
                    builder: (context, snap) {
                      final count = snap.data?.length ?? 0;
                      if (snap.connectionState == ConnectionState.waiting) return const SizedBox.shrink();
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      );
                    },
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Refresh trucks',
                    onPressed: () {},
                    icon: Icon(Icons.refresh, size: 20, color: p.iconMuted),
                  ),
                ],
              ),
            ),
            FutureBuilder<List<TruckModel>>(
              future: userId != null ? TruckService.myTrucks(userId: userId) : Future.value([]),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    ),
                  );
                }
                if (snap.hasError) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Could not load trucks.',
                            style: TextStyle(fontSize: 13, color: p.textMuted),
                          ),
                        ),
                        TextButton(
                          onPressed: () {},
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }
                final trucks = snap.data ?? [];
                if (trucks.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No trucks yet — add your first truck.',
                          style: TextStyle(fontSize: 13, color: p.textMuted),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.add),
                            label: const Text('Add Truck'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                final shown = trucks.take(3).toList();
                return Column(
                  children: [
                    ...shown.asMap().entries.map((entry) {
                      final truck = entry.value;
                      final last = entry.key == shown.length - 1;
                      return Column(
                        children: [
                          ListTile(
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.local_shipping,
                                color: AppColors.primary,
                                size: 22,
                              ),
                            ),
                            title: Text(
                              '${truck.make} ${truck.model}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                            ),
                            subtitle: Text(
                              '${truck.registrationNumber} • ${truck.capacityTons}t',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: p.textMuted),
                            ),
                            trailing: Icon(Icons.arrow_forward_ios, size: 16, color: p.iconMuted),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                            onTap: () {},
                          ),
                          if (!last)
                            Divider(height: 1, color: p.divider, indent: 16, endIndent: 16),
                        ],
                      );
                    }),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

