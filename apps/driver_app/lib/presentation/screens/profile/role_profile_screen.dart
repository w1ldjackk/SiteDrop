// Driver profile: header stats + work/account menus (no placeholders).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Drivers don't have a dedicated profile screen in monolith; use shared settings
// via a lightweight shell.
import 'package:sitedrop_core/app/theme/colors.dart';
import 'package:sitedrop_core/core/utils/helpers.dart';
import 'package:go_router/go_router.dart';
import 'package:sitedrop_core/app/routes/route_names.dart';
import 'package:sitedrop_core/data/models/delivery.dart';
import '../../providers/auth_provider.dart';
import '../../providers/delivery_provider.dart';
import '../../providers/main_tab_provider.dart';
import '../../widgets/common/app_back_button.dart';
import '../../widgets/common/notification_bell_button.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final auth = ref.watch(authProvider);
    final user = auth is AsyncData && auth.value is AuthAuthenticated
        ? (auth.value as AuthAuthenticated).user
        : null;
    final online = ref.watch(driverOnlineProvider);
    final tripsAsync = ref.watch(myDeliveriesProvider);
    final trips = tripsAsync.asData?.value ?? const <DeliveryModel>[];
    final completed =
        trips.where((t) => t.status == 'completed').length;
    final ratings = [
      for (final t in trips)
        if (t.deliveryRating != null) t.deliveryRating!,
    ];
    final avgRating = ratings.isEmpty
        ? 0.0
        : ratings.reduce((a, b) => a + b) / ratings.length;

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.surface,
        elevation: 0,
        title: appBarTitle(context, 'Profile'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 8),
            child: NotificationBellButton(iconSize: 26, useGo: true),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ---- Header ----
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: p.border),
              ),
              child: Row(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: AppColors.primary,
                        backgroundImage:
                            user?.avatar != null &&
                                    user!.avatar!.isNotEmpty
                                ? NetworkImage(user.avatar!)
                                : null,
                        child: (user?.avatar == null ||
                                user!.avatar!.isEmpty)
                            ? Text(
                                (user?.name.isNotEmpty == true
                                        ? user!.name[0]
                                        : 'D')
                                    .toUpperCase(),
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: p.textOnPrimary,
                                ),
                              )
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: online
                                ? AppColors.success
                                : p.iconMuted,
                            border: Border.all(
                              color: p.surface,
                              width: 2.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? 'Driver',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: p.textPrimary,
                          ),
                        ),
                        Text(
                          user?.phone ?? user?.email ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: p.textMuted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _miniStat(
                              context,
                              '$completed',
                              'Trips',
                            ),
                            const SizedBox(width: 14),
                            _miniStat(
                              context,
                              avgRating > 0
                                  ? avgRating.toStringAsFixed(1)
                                  : '—',
                              'Rating',
                            ),
                            const SizedBox(width: 14),
                            _miniStat(
                              context,
                              online ? 'Online' : 'Offline',
                              'Status',
                              highlight: online,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _menuSection(context, 'Work', [
              _item(
                context,
                Icons.local_shipping_outlined,
                'Available',
                'Go online & accept trips',
                () => context.push(
                  RouteNames.deliveryAssignments,
                ),
              ),
              _item(
                context,
                Icons.route_outlined,
                'My trips',
                'Active and past deliveries',
                () => ref
                    .read(mainTabIndexProvider.notifier)
                    .setIndex(1),
              ),
              _item(
                context,
                Icons.payments_outlined,
                'Earnings',
                'Payouts and trip history',
                () => context.push(RouteNames.driverEarnings),
              ),
              _item(
                context,
                Icons.local_shipping_outlined,
                'My trucks',
                'Update details for matching',
                () => context.push(RouteNames.driverTrucks),
              ),
            ]),
            const SizedBox(height: 16),
            _menuSection(context, 'Account', [
              _item(
                context,
                Icons.account_balance_wallet_outlined,
                'Wallet',
                'Balance and transactions',
                () => context.push(RouteNames.wallet),
              ),
              _item(
                context,
                Icons.settings_outlined,
                'Settings',
                'App preferences',
                () => context.push(RouteNames.settings),
              ),
              _item(
                context,
                Icons.help_outline,
                'Help & support',
                'FAQs and contact',
                () => context.push(RouteNames.helpSupport),
              ),
            ]),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _confirmLogout(context, ref),
                icon: Icon(
                  Icons.logout,
                  color: AppColors.error,
                ),
                label: Text(
                  'Sign out',
                  style: TextStyle(color: AppColors.error),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color:
                        AppColors.error.withValues(alpha: 0.5),
                  ),
                  padding:
                      const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(
    BuildContext context,
    String value,
    String label, {
    bool highlight = false,
  }) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: highlight ? AppColors.success : p.textPrimary,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: p.textMuted),
        ),
      ],
    );
  }

  Widget _menuSection(
    BuildContext context,
    String title,
    List<Widget> items,
  ) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: p.textMuted,
              letterSpacing: 0.4,
            ),
          ),
        ),
        Material(
          color: p.surface,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.border),
            ),
            child: Column(children: items),
          ),
        ),
      ],
    );
  }

  Widget _item(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    final p = context.palette;
    return ListTile(
      tileColor: Colors.transparent,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: p.primarySoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: p.textMuted),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: p.iconMuted,
      ),
      onTap: onTap,
    );
  }

  Future<void> _confirmLogout(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You will stop receiving trip requests.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await ref.read(authProvider.notifier).logout();
      if (context.mounted) {
        Helpers.showSuccessToast('Signed out');
        context.go(RouteNames.login);
      }
    }
  }
}
