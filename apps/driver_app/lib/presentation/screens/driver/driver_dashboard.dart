// lib/presentation/screens/driver/driver_dashboard.dart
// Real driver home: online toggle, today snapshot, active trip, shortcuts.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sitedrop_core/app/routes/route_names.dart';
import 'package:sitedrop_core/app/theme/colors.dart';
import 'package:sitedrop_core/core/utils/helpers.dart';
import 'package:sitedrop_core/data/models/delivery.dart';
import 'package:sitedrop_core/data/services/delivery_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/delivery_provider.dart';
import '../../providers/main_tab_provider.dart';
import '../../providers/truck_provider.dart';
import '../../widgets/common/app_back_button.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/notification_bell_button.dart';

class DriverDashboard extends ConsumerStatefulWidget {
  const DriverDashboard({super.key});

  @override
  ConsumerState<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends ConsumerState<DriverDashboard> {
  bool _toggling = false;

  Future<void> _toggleOnline(bool online) async {
    if (_toggling) return;
    setState(() => _toggling = true);
    try {
      final (ok, message) =
          await DeliveryService.setPresence(online: online);
      if (!mounted) return;
      if (ok) {
        ref.read(driverOnlineProvider.notifier).set(online);
        if (online) {
          ref.invalidate(deliveryOffersProvider);
          ref.invalidate(myDeliveriesProvider);
        }
        Helpers.showSuccessToast(message);
      } else {
        Helpers.showErrorToast(message);
      }
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final online = ref.watch(driverOnlineProvider);
    final auth = ref.watch(authProvider);
    final user = auth is AsyncData && auth.value is AuthAuthenticated
        ? (auth.value as AuthAuthenticated).user
        : null;
    final statsAsync = ref.watch(deliveryStatsProvider);
    final tripsAsync = ref.watch(myDeliveriesProvider);
    final offersAsync = ref.watch(deliveryOffersProvider);

    final trips = tripsAsync.asData?.value ?? const <DeliveryModel>[];
    final active = trips.where(isDeliveryActive).toList();
    final offers = offersAsync.asData?.value ?? const [];
    final trucksAsync = ref.watch(myTrucksProvider);
    final trucks = trucksAsync.asData?.value ?? const [];
    final needsTruck = trucksAsync is AsyncData && trucks.isEmpty;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        backgroundColor: context.palette.surface,
        elevation: 0,
        title: appBarTitle(context, 'Driver'),
        leading: const AppBackButton(
          fallbackRoute: RouteNames.driverDashboard,
        ),
        actions: const [
          NotificationBellButton(iconSize: 26, useGo: true),
          SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(deliveryStatsProvider);
            ref.invalidate(myDeliveriesProvider);
            ref.invalidate(deliveryOffersProvider);
            try {
              await Future.wait([
                ref.read(deliveryStatsProvider.future),
                ref.read(myDeliveriesProvider.future),
                ref.read(deliveryOffersProvider.future),
              ]);
            } catch (_) {}
          },
          color: AppColors.primary,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                '$greeting${user != null ? ', ${user.name.split(' ').first}' : ''} 👋',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: context.palette.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                online
                    ? 'You are online — requests come straight here'
                    : 'Go online to start receiving trips',
                style: TextStyle(
                  fontSize: 13,
                  color: context.palette.textMuted,
                ),
              ),
              const SizedBox(height: 16),
              // ---- Online toggle ----
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: online
                      ? AppColors.success.withValues(alpha: 0.10)
                      : context.palette.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: online
                        ? AppColors.success.withValues(alpha: 0.4)
                        : context.palette.divider,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: online
                            ? AppColors.success
                            : context.palette.iconMuted,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        online ? 'Online' : 'Offline',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    if (_toggling)
                      const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                        ),
                      )
                    else
                      Switch(
                        value: online,
                        activeThumbColor: AppColors.success,
                        onChanged: _toggleOnline,
                      ),
                  ],
                ),
              ),
              // ---- No-truck nudge (matcher needs capacity + insurance) ----
              if (needsTruck) ...[
                const SizedBox(height: 12),
                Material(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () =>
                        context.push(RouteNames.driverTruckSetup),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.primary
                              .withValues(alpha: 0.35),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.local_shipping_outlined,
                            size: 28,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Add your truck',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  'Capacity + insurance unlocks trip matching',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              // ---- Incoming requests banner ----
              if (online && offers.isNotEmpty) ...[
                const SizedBox(height: 12),
                Material(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => ref
                        .read(mainTabIndexProvider.notifier)
                        .setIndex(0),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.warning
                              .withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.delivery_dining,
                            color: AppColors.warning,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${offers.length} trip request${offers.length == 1 ? '' : 's'}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                                const Text(
                                  'Tap to review and accept',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: context.palette.iconMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              // ---- Active trip ----
              if (active.isNotEmpty) ...[
                const SizedBox(height: 12),
                _ActiveTripCard(trip: active.first),
              ],
              const SizedBox(height: 16),
              // ---- Today snapshot ----
              statsAsync.when(
                data: (s) => _StatsRow(stats: s),
                loading: () => Container(
                  height: 96,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.palette.surface,
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: context.palette.divider),
                  ),
                  child: const LoadingWidget.compact(),
                ),
                error: (_, _) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 16),
              // ---- Shortcuts ----
              Row(
                children: [
                  Expanded(
                    child: _Shortcut(
                      icon: Icons.route_outlined,
                      label: 'My trips',
                      onTap: () => ref
                          .read(mainTabIndexProvider.notifier)
                          .setIndex(1),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Shortcut(
                      icon: Icons.payments_outlined,
                      label: 'Earnings',
                      onTap: () => ref
                          .read(mainTabIndexProvider.notifier)
                          .setIndex(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Shortcut(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Wallet',
                      onTap: () =>
                          context.push(RouteNames.wallet),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // ---- Fleet ----
              Material(
                color: context.palette.surface,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => context.push(RouteNames.driverTrucks),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border:
                          Border.all(color: context.palette.divider),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.local_shipping_outlined,
                          color: AppColors.primary,
                          size: 26,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'My trucks',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                trucksAsync.when(
                                  data: (t) => t.isEmpty
                                      ? 'No truck added'
                                      : '${t.length} truck${t.length == 1 ? '' : 's'} · ${t.where((e) => e.matcherReady).length} match-ready',
                                  loading: () => 'Loading…',
                                  error: (_, _) => 'Tap to manage',
                                ),
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      context.palette.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: context.palette.iconMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveTripCard extends StatelessWidget {
  final DeliveryModel trip;

  const _ActiveTripCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    final title = trip.orderNumber?.isNotEmpty == true
        ? 'Order ${trip.orderNumber}'
        : '#${trip.trackingNumber ?? trip.id}';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.local_shipping,
            color: Colors.white,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'On trip · $title',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if ((trip.dropAddress ?? '').isNotEmpty)
                  Text(
                    trip.dropAddress!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color:
                          Colors.white.withValues(alpha: 0.85),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final Map<String, dynamic> stats;

  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    num n(dynamic v) => v is num ? v : num.tryParse('$v') ?? 0;
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            label: 'Completed',
            value: '${n(stats['completed']).toInt()}',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            label: 'Earned',
            value: stats['formatted_earnings']?.toString() ??
                'GHS ${n(stats['earnings']).toStringAsFixed(2)}',
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;

  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.palette.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: context.palette.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _Shortcut({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.palette.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.palette.divider),
          ),
          child: Column(
            children: [
              Icon(icon, color: AppColors.primary, size: 26),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
