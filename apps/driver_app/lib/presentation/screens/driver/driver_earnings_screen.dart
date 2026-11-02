// lib/presentation/screens/driver/driver_earnings_screen.dart
// Real earnings: server totals + per-trip 70% share list.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sitedrop_core/app/routes/route_names.dart';
import 'package:sitedrop_core/app/theme/colors.dart';
import 'package:sitedrop_core/core/utils/helpers.dart';
import 'package:sitedrop_core/data/models/delivery.dart';
import '../../providers/delivery_provider.dart';
import '../../widgets/common/app_back_button.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/notification_bell_button.dart';

class DriverEarningsScreen extends ConsumerWidget {
  const DriverEarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(deliveryStatsProvider);
    final tripsAsync = ref.watch(myDeliveriesProvider);

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        backgroundColor: context.palette.surface,
        elevation: 0,
        title: appBarTitle(context, 'Earnings'),
        leading: const AppBackButton(
          fallbackRoute: RouteNames.driverDashboard,
        ),
        actions: [
          const NotificationBellButton(iconSize: 26, useGo: true),
          IconButton(
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(deliveryStatsProvider);
              ref.invalidate(myDeliveriesProvider);
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(deliveryStatsProvider);
            ref.invalidate(myDeliveriesProvider);
            try {
              await Future.wait([
                ref.read(deliveryStatsProvider.future),
                ref.read(myDeliveriesProvider.future),
              ]);
            } catch (_) {}
          },
          color: AppColors.primary,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              statsAsync.when(
                data: (s) => _hero(context, s),
                loading: () => Container(
                  height: 150,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.palette.surface,
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: context.palette.divider),
                  ),
                  child: const LoadingWidget.compact(),
                ),
                error: (_, _) => _hero(context, const {}),
              ),
              const SizedBox(height: 16),
              Text(
                'Paid trips',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: context.palette.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              tripsAsync.when(
                data: (trips) {
                  final paid = trips
                      .where((t) => t.status == 'completed')
                      .toList();
                  if (paid.isEmpty) {
                    return _emptyBox(
                      context,
                      'Completed trips and their payouts appear here',
                    );
                  }
                  return Column(
                    children: [
                      for (var i = 0; i < paid.length; i++) ...[
                        _EarningRow(trip: paid[i]),
                        if (i < paid.length - 1)
                          const SizedBox(height: 8),
                      ],
                    ],
                  );
                },
                loading: () => const SizedBox(
                  height: 80,
                  child: LoadingWidget.compact(),
                ),
                error: (_, _) => _emptyBox(
                  context,
                  'Could not load trip payouts',
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'You keep 70% of every delivery fee.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: context.palette.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hero(BuildContext context, Map<String, dynamic> s) {
    num n(dynamic v) =>
        v is num ? v : num.tryParse(v.toString()) ?? 0;
    final earnings = s['formatted_earnings']?.toString() ??
        Helpers.formatPrice(
          (n(s['earnings'])).toDouble(),
        );
    final completed = n(s['completed']).toInt();
    final active = n(s['in_transit']).toInt() +
        n(s['assigned']).toInt() +
        n(s['accepted'] ?? 0).toInt();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.success,
            AppColors.success.withValues(alpha: 0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total earned',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            earnings,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _heroStat('$completed', 'Completed'),
              const SizedBox(width: 20),
              _heroStat('$active', 'In progress'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroStat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _emptyBox(BuildContext context, String message) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.palette.divider),
      ),
      child: Row(
        children: [
          Icon(
            Icons.payments_outlined,
            size: 28,
            color: context.palette.iconMuted,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color: context.palette.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EarningRow extends StatelessWidget {
  final DeliveryModel trip;

  const _EarningRow({required this.trip});

  @override
  Widget build(BuildContext context) {
    final title = trip.orderNumber?.isNotEmpty == true
        ? 'Order ${trip.orderNumber}'
        : '#${trip.trackingNumber ?? trip.id}';
    final share = trip.effectivePayout;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.palette.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.check_circle_outline,
              color: AppColors.success,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Fee ${Helpers.formatPrice(trip.deliveryFee ?? 0)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.palette.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '+${Helpers.formatPrice(share)}',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }
}
