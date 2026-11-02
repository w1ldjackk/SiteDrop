// lib/presentation/screens/profile/user/profile_screen.dart
// Profile for non-seller roles backed by backend UserProfile (profiles table).
// Roles: buyer, driver, admin, and any other non-seller user.
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sitedrop_core/app/routes/route_names.dart';
import 'package:sitedrop_core/app/theme/app_palette.dart';
import 'package:sitedrop_core/core/utils/helpers.dart';
import 'package:sitedrop_core/data/models/user.dart';
import 'package:sitedrop_core/data/services/public_config_service.dart';
import '../../../../core/i18n/app_strings.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/locale_provider.dart';
import '../../../providers/main_tab_provider.dart';
import '../../../providers/profile_stats_provider.dart';
import '../shared/profile_ui.dart';

/// Maps to Laravel `App\Models\UserProfile` (table: profiles).
class UserProfileScreen extends ConsumerWidget {
  const UserProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState is AsyncData && authState.value is AuthAuthenticated
        ? (authState.value as AuthAuthenticated).user
        : null;
    final statsAsync = ref.watch(profileStatsProvider);

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: buildProfileAppBar(
        context: context,
        user: user,
        subtitle: user != null ? _roleLabel(user) : null,
      ),
      body: user != null
          ? SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  buildProfileStatsRow(
                    context,
                    _statsFor(user, statsAsync),
                  ),
                  const SizedBox(height: 24),
                  ..._sectionsFor(context, ref, user),
                  const SizedBox(height: 24),
                  buildProfileLogoutButton(ref, context),
                  const SizedBox(height: 20),
                ],
              ),
            )
          : buildProfileGuestView(context),
    );
  }

  String _roleLabel(User user) {
    if (user.isDriver) return 'Driver · ${user.phone}';
    if (user.isAdmin || user.isSuperAdmin) return 'Admin · ${user.phone}';
    return user.phone;
  }

  String _fmtCount(int n) => n > 999 ? '999+' : '$n';

  List<ProfileStat> _statsFor(User user, AsyncValue<ProfileStats> statsAsync) {
    final stats = statsAsync.asData?.value ?? const ProfileStats();
    final loading = statsAsync.isLoading && statsAsync.asData == null;

    if (user.isDriver) {
      return [
        ProfileStat(
          label: 'Deliveries',
          value: loading ? '…' : _fmtCount(stats.deliveriesCount),
          icon: Icons.local_shipping_outlined,
        ),
        ProfileStat(
          label: 'Orders',
          value: loading ? '…' : _fmtCount(stats.ordersCount),
          icon: Icons.payments_outlined,
        ),
        ProfileStat(
          label: 'Rating',
          value: loading
              ? '…'
              : (stats.rating > 0 ? stats.rating.toStringAsFixed(1) : '—'),
          icon: Icons.star_outline,
        ),
      ];
    }

    // Buyer / default UserProfile
    return [
      ProfileStat(
        label: 'Orders',
        value: loading ? '…' : _fmtCount(stats.ordersCount),
        icon: Icons.shopping_bag_outlined,
      ),
      ProfileStat(
        label: 'Reviews',
        value: loading ? '…' : _fmtCount(stats.reviewsCount),
        icon: Icons.star_outline,
      ),
      ProfileStat(
        label: 'Wishlist',
        value: loading ? '…' : _fmtCount(stats.wishlistCount),
        icon: Icons.favorite_outline,
      ),
    ];
  }

  List<Widget> _sectionsFor(BuildContext context, WidgetRef ref, User user) {
    if (user.isDriver) {
      return [
        buildProfileMenuSection(
          context: context,
          title: 'Account',
          items: [
            ProfileMenuItem(
              icon: Icons.person_outline,
              title: 'Edit Profile',
              subtitle: 'Personal details',
              onTap: () => context.push(RouteNames.editProfile),
            ),
          ],
        ),
        const SizedBox(height: 16),
        buildProfileMenuSection(
          context: context,
          title: 'Deliveries',
          items: [
            ProfileMenuItem(
              icon: Icons.dashboard_outlined,
              title: 'Driver Dashboard',
              onTap: () => context.push(RouteNames.driverDashboard),
            ),
            ProfileMenuItem(
              icon: Icons.assignment_outlined,
              title: 'Assignments',
              onTap: () => context.push(RouteNames.deliveryAssignments),
            ),
            ProfileMenuItem(
              icon: Icons.payments_outlined,
              title: 'Earnings / Wallet',
              onTap: () => context.push(RouteNames.wallet),
            ),
          ],
        ),
        const SizedBox(height: 16),
        buildSupportMenuSection(context),
      ];
    }

    // Buyer / general UserProfile menus
    final locale = ref.watch(localeProvider);
    String t(String k) => tr(locale, k);
    return [
      buildProfileMenuSection(
        context: context,
        title: t('menu.account'),
        items: [
ProfileMenuItem(
              icon: Icons.person_outline,
              title: t('menu.edit_profile'),
              subtitle: t('profile.personal'),
              onTap: () => context.push(RouteNames.editProfile),
            ),
          ProfileMenuItem(
            icon: Icons.account_balance_wallet_outlined,
            title: t('menu.wallet'),
            subtitle: 'Balance, deposit & withdraw',
            onTap: () => context.push(RouteNames.wallet),
          ),
          ProfileMenuItem(
            icon: Icons.location_on_outlined,
            title: t('menu.addresses'),
            onTap: () => context.push(RouteNames.addresses),
          ),
          ProfileMenuItem(
            icon: Icons.construction_outlined,
            title: 'My Construction Sites',
            subtitle: 'Manage your project sites',
            onTap: () => context.push(RouteNames.buyerSites),
          ),
          ProfileMenuItem(
            icon: Icons.credit_card_outlined,
            title: t('menu.payment_methods'),
            onTap: () => context.push(RouteNames.paymentMethods),
          ),
          ProfileMenuItem(
            icon: Icons.favorite_border,
            title: t('menu.wishlist'),
            onTap: () {
              ref.read(mainTabIndexProvider.notifier).setIndex(3);
              context.go(RouteNames.home);
            },
          ),
        ],
      ),
      const SizedBox(height: 16),
      buildProfileMenuSection(
        context: context,
        title: t('menu.orders'),
        items: [
          ProfileMenuItem(
            icon: Icons.history,
            title: t('menu.order_history'),
            subtitle: 'Past orders & receipts',
            onTap: () => context.push(RouteNames.orderHistory),
          ),
          ProfileMenuItem(
            icon: Icons.local_shipping_outlined,
            title: t('menu.track_orders'),
            subtitle: 'Live delivery status',
            onTap: () => context.push(RouteNames.trackOrders),
          ),
          ProfileMenuItem(
            icon: Icons.star_outline,
            title: t('menu.ratings'),
            subtitle: 'Rate orders, trips & products',
            onTap: () => context.push(RouteNames.reviews),
          ),
        ],
      ),
      const SizedBox(height: 16),
      buildProfileMenuSection(
        context: context,
        title: t('menu.support'),
        items: [
          ProfileMenuItem(
            icon: CupertinoIcons.chat_bubble_fill,
            title: t('menu.whatsapp'),
            onTap: _launchWhatsApp,
          ),
          ProfileMenuItem(
            icon: Icons.help_outline,
            title: t('menu.help'),
            onTap: () => context.push(RouteNames.helpSupport),
          ),
          ProfileMenuItem(
            icon: Icons.description_outlined,
            title: t('menu.terms'),
            onTap: () => context.push(RouteNames.termsOfService),
          ),
          ProfileMenuItem(
            icon: Icons.lock_outline,
            title: t('menu.privacy'),
            onTap: () => context.push(RouteNames.privacyPolicy),
          ),
        ],
      ),
    ];
  }

  void _launchWhatsApp() async {
    final digits = PublicConfigService.supportWhatsappDigits;
    if (digits == null) {
      Helpers.showInfoToast('WhatsApp support is not set up yet');
      return;
    }
    final url = 'https://wa.me/$digits';
    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        Helpers.showErrorToast('Could not open WhatsApp');
      }
    } catch (_) {
      Helpers.showErrorToast('Could not open WhatsApp');
    }
  }
}
