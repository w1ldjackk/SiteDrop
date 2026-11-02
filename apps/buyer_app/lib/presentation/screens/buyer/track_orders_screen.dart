// lib/presentation/screens/buyer/track_orders_screen.dart
// Active deliveries hub — DIFFERENT from Order History.
//
// Order History (`order_history_screen`) = full list of past orders & receipts.
// This screen = only live/trackable orders (SiteDrop-style "My trips"): each card
// shows live progress + ETA and opens the live tracker (`order_tracking`).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sitedrop_core/app/routes/route_names.dart';
import 'package:sitedrop_core/app/theme/colors.dart';
import 'package:sitedrop_core/core/utils/helpers.dart';
import 'package:sitedrop_core/data/models/order.dart';
import '../../providers/order_provider.dart';
import '../../widgets/buyer/order_status_chip.dart';
import '../../widgets/common/app_back_button.dart';
import '../../widgets/common/loading_widget.dart';

/// Canonical journey steps — same order as the live tracker hero.
const _trackSteps = [
  'Confirmed',
  'Preparing',
  'Ready',
  'On the way',
  'Delivered',
];

int _stepIndex(OrderStatus status) {
  switch (status) {
    case OrderStatus.pending:
      return -1;
    case OrderStatus.confirmed:
      return 0;
    case OrderStatus.processing:
      return 1;
    case OrderStatus.readyForDelivery:
      return 2;
    case OrderStatus.dispatched:
    case OrderStatus.inTransit:
      return 3;
    case OrderStatus.delivered:
    case OrderStatus.completed:
      return 4;
    case OrderStatus.cancelled:
    case OrderStatus.refunded:
      return -2;
  }
}

class TrackOrdersScreen extends ConsumerStatefulWidget {
  const TrackOrdersScreen({super.key});

  @override
  ConsumerState<TrackOrdersScreen> createState() =>
      _TrackOrdersScreenState();
}

class _TrackOrdersScreenState extends ConsumerState<TrackOrdersScreen>
    with WidgetsBindingObserver {
  Timer? _pollTimer;
  DateTime _lastChecked = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Fresh statuses on (re)entry — e.g. back from the live tracker,
    // which may hold newer data than this cached list.
    Future.microtask(() {
      if (mounted) _pollOnce();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Background → foreground: statuses may have moved while away.
    if (state == AppLifecycleState.resumed && mounted) {
      _pollOnce();
    }
  }

  /// One silent background refresh (no loading flash).
  void _pollOnce() {
    if (!mounted) return;
    setState(() => _lastChecked = DateTime.now());
    ref.read(ordersProvider.notifier).silentRefresh();
  }

  /// Poll every 15s while there are live orders; stop when everything
  /// is terminal (recent list barely changes — pull-to-refresh covers it).
  void _schedulePolling(bool hasActive) {
    if (!hasActive) {
      _pollTimer?.cancel();
      _pollTimer = null;
      return;
    }
    _pollTimer ??= Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      _pollOnce();
    });
  }

  String _relativeTime(DateTime at) {
    final diff = DateTime.now().difference(at);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return Helpers.formatDate(at);
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(ordersProvider);

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        backgroundColor: context.palette.surface,
        elevation: 0,
        title: appBarTitle(context, 'Track Orders'),
        leading: const AppBackButton(fallbackRoute: RouteNames.home),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () {
              setState(() => _lastChecked = DateTime.now());
              ref.read(ordersProvider.notifier).refreshOrders();
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ordersAsync.when(
        data: (orders) {
          final active =
              orders.where((o) => o.isTrackingActive).toList();
          final recent = orders
              .where((o) => !o.isTrackingActive)
              .take(5)
              .toList();
          _schedulePolling(active.isNotEmpty);
          if (active.isEmpty && recent.isEmpty) {
            return _buildEmptyState(context);
          }
          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _lastChecked = DateTime.now());
              await ref.read(ordersProvider.notifier).refreshOrders();
            },
            color: AppColors.primary,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                if (active.isNotEmpty) ...[
                  _buildSectionTitle(
                    context,
                    'Active deliveries',
                    Icons.local_shipping_outlined,
                    live: true,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Statuses auto-update • checked ${_relativeTime(_lastChecked)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.palette.textMuted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final order in active) ...[
                    _buildActiveCard(context, order),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 8),
                ] else
                  _buildNoActiveCard(context),
                if (recent.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionTitle(
                        context,
                        'Recently completed',
                        Icons.check_circle_outline,
                      ),
                      TextButton(
                        onPressed: () =>
                            context.push(RouteNames.orderHistory),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          minimumSize: const Size(64, 44),
                        ),
                        child: const Text('View all'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (final order in recent) ...[
                    _buildRecentRow(context, order),
                    const SizedBox(height: 8),
                  ],
                ],
              ],
            ),
          );
        },
        loading: () => const LoadingWidget(message: 'Loading deliveries…'),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(error.toString(), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    setState(() => _lastChecked = DateTime.now());
                    ref.read(ordersProvider.notifier).refreshOrders();
                  },
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
    );
  }

  // ============================================================
  // SECTIONS
  // ============================================================
  Widget _buildSectionTitle(
    BuildContext context,
    String title,
    IconData icon, {
    bool live = false,
  }) {
    return Row(
      children: [
        if (live) ...[
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
        ] else ...[
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: context.palette.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveCard(BuildContext context, OrderModel order) {
    final step = _stepIndex(order.status);
    final progress =
        step < 0 ? 0.0 : (step + 1) / _trackSteps.length;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: context.palette.divider),
      ),
      color: context.palette.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () =>
            context.push(RouteNames.orderTrackingWithId(order.id)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.orderNumber,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  OrderStatusChip(status: order.status),
                ],
              ),
              const SizedBox(height: 10),
              // Mini progress (same 5 steps as tracker hero).
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: context.palette.surfaceMuted,
                  valueColor: const AlwaysStoppedAnimation(
                    AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                step < 0
                    ? 'Order placed — awaiting confirmation'
                    : _trackSteps[step.clamp(0, _trackSteps.length - 1)],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.palette.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.schedule_outlined,
                    size: 14,
                    color: context.palette.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      order.eta != null
                          ? 'Arriving by ${Helpers.formatDate(order.eta!)}'
                          : Helpers.formatPrice(order.totalAmount),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.palette.textMuted,
                      ),
                    ),
                  ),
                  Text(
                    'Track live',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoActiveCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.palette.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: context.palette.primarySoft,
              shape: BoxShape.circle,
            ),
            child:
                Icon(Icons.check_circle_outline, color: AppColors.success),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'All caught up',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: context.palette.textPrimary,
                  ),
                ),
                Text(
                  'No live deliveries right now',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.palette.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentRow(BuildContext context, OrderModel order) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: context.palette.divider),
      ),
      color: context.palette.surface,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 4,
        ),
        title: Text(
          order.orderNumber,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          Helpers.formatDate(order.createdAt),
          style: TextStyle(
            fontSize: 12,
            color: context.palette.textMuted,
          ),
        ),
        trailing: OrderStatusChip(status: order.status),
        onTap: () =>
            context.push(RouteNames.orderTrackingWithId(order.id)),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: context.palette.surfaceMuted,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.local_shipping_outlined,
                  size: 60,
                  color: context.palette.iconMuted,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'No deliveries yet',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: context.palette.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your live orders will appear here for tracking',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.palette.textMuted,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go(RouteNames.home),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Browse products'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
