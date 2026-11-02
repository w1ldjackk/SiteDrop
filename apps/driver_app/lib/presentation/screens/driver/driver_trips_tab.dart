// My Trips: active deliveries + trip history (real data, no placeholders).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sitedrop_core/app/routes/route_names.dart';
import 'package:sitedrop_core/app/theme/colors.dart';
import 'package:sitedrop_core/core/utils/display_names.dart';
import 'package:sitedrop_core/core/utils/helpers.dart';
import 'package:sitedrop_core/data/models/delivery.dart';
import '../../providers/delivery_provider.dart';
import '../../providers/main_tab_provider.dart';
import '../../widgets/common/app_back_button.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/notification_bell_button.dart';

class DriverTripsTab extends ConsumerWidget {
  const DriverTripsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.watch(myDeliveriesProvider);

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        backgroundColor: context.palette.surface,
        elevation: 0,
        title: appBarTitle(context, 'My trips'),
        actions: [
          const NotificationBellButton(iconSize: 26, useGo: true),
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(myDeliveriesProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: tripsAsync.when(
          data: (trips) {
            final active =
                trips.where(isDeliveryActive).toList();
            final done = trips
                .where((t) => !isDeliveryActive(t))
                .toList();
            if (trips.isEmpty) return _empty(context);
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(myDeliveriesProvider);
                await ref.read(myDeliveriesProvider.future);
              },
              color: AppColors.primary,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  _summaryRow(context, active.length, done.length),
                  const SizedBox(height: 16),
                  if (active.isNotEmpty) ...[
                    _section(context, 'Active'),
                    const SizedBox(height: 8),
                    for (final t in active) ...[
                      _TripCard(
                        trip: t,
                        active: true,
                        onTap: () {
                          // Actions live on the Available tab.
                          ref
                              .read(mainTabIndexProvider.notifier)
                              .setIndex(0);
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                    const SizedBox(height: 8),
                  ],
                  if (done.isNotEmpty) ...[
                    _section(context, 'History'),
                    const SizedBox(height: 8),
                    for (final t in done) ...[
                      _TripCard(
                        trip: t,
                        onTap: () => _detail(context, t),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ],
              ),
            );
          },
          loading: () =>
              const LoadingWidget(message: 'Loading trips…'),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    Helpers.errorMessage(e),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () =>
                        ref.invalidate(myDeliveriesProvider),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(BuildContext context, int active, int done) {
    return Row(
      children: [
        Expanded(
          child: _SummaryTile(
            icon: Icons.local_shipping_outlined,
            value: '$active',
            label: 'Active',
            highlight: active > 0,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryTile(
            icon: Icons.check_circle_outline,
            value: '$done',
            label: 'Completed',
            highlight: false,
          ),
        ),
      ],
    );
  }

  Widget _section(BuildContext context, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: context.palette.textPrimary,
      ),
    );
  }

  Widget _empty(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: context.palette.surfaceMuted,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.route_outlined,
                size: 52,
                color: context.palette.iconMuted,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No trips yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: context.palette.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Go online on the Available tab to receive trip requests',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.palette.textMuted,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _detail(BuildContext context, DeliveryModel t) {
    final title = t.orderNumber?.isNotEmpty == true
        ? 'Order ${t.orderNumber}'
        : '#${t.trackingNumber ?? t.id}';
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: context.palette.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.palette.borderStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              _kv(
                context,
                'Status',
                DisplayNames.deliveryStatusLabel(t.status),
              ),
              if ((t.dropAddress ?? '').isNotEmpty)
                _kv(context, 'Dropoff', t.dropAddress!),
              if (t.distanceKm != null)
                _kv(
                  context,
                  'Distance',
                  '${t.distanceKm!.toStringAsFixed(1)} km',
                ),
              _kv(
                context,
                'Fee',
                Helpers.formatPrice(t.deliveryFee ?? 0),
              ),
              _kv(
                context,
                'Your share (70%)',
                Helpers.formatPrice(t.effectivePayout),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () =>
                      context.push(RouteNames.deliveryAssignments),
                  child: const Text('Open assignments'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              k,
              style: TextStyle(
                fontSize: 13,
                color: context.palette.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final bool highlight;

  const _SummaryTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.primary.withValues(alpha: 0.10)
            : context.palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlight
              ? AppColors.primary.withValues(alpha: 0.4)
              : context.palette.divider,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 26),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
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
        ],
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  final DeliveryModel trip;
  final bool active;
  final VoidCallback onTap;

  const _TripCard({
    required this.trip,
    this.active = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = trip.orderNumber?.isNotEmpty == true
        ? 'Order ${trip.orderNumber}'
        : '#${trip.trackingNumber ?? trip.id}';
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: context.palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: context.palette.divider),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 4,
        ),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: context.palette.primarySoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            active
                ? Icons.local_shipping_outlined
                : Icons.check_circle_outline,
            color: AppColors.primary,
          ),
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          [
            DisplayNames.deliveryStatusLabel(trip.status),
            if ((trip.dropAddress ?? '').isNotEmpty)
              trip.dropAddress!,
          ].join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            color: context.palette.textMuted,
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: Text(
                Helpers.formatPrice(trip.deliveryFee ?? 0),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 16,
              color: context.palette.iconMuted,
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
