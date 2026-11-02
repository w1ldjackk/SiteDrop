// lib/presentation/screens/buyer/order_tracking_screen.dart
// Live order tracker (SiteDrop/SiteDrop style) — NOT a second order history.
//
// History (`order_history_screen`) = the list of past orders.
// This screen = one order's live journey: hero progress, OSM live map
// (driver + destination + route, free tiles, no API key), driver card,
// journey timeline, then the order details (items, delivery, help).
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sitedrop_core/app/routes/route_names.dart';
import 'package:sitedrop_core/app/theme/colors.dart';
import 'package:sitedrop_core/data/models/order.dart';
import 'package:sitedrop_core/data/models/delivery.dart';
import 'package:sitedrop_core/data/models/tracking.dart';
import 'package:sitedrop_core/data/services/order_service.dart';
import 'package:sitedrop_core/maps/app_map_point.dart';
import '../../../core/extensions/context_extensions.dart';
import 'package:sitedrop_core/core/utils/helpers.dart';
import '../../providers/order_provider.dart';
import '../../providers/service_providers.dart';
import '../../providers/tracking_provider.dart';
import '../../widgets/buyer/order_status_chip.dart';
import '../../widgets/common/app_back_button.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/maps/app_map.dart';
import '../../widgets/reviews/order_review_sheet.dart';

/// Canonical journey steps (SiteDrop-style). Pending sits before step 0.
const _trackerSteps = [
  'Confirmed',
  'Preparing',
  'Ready',
  'On the way',
  'Delivered',
];

class OrderTrackingScreen extends ConsumerStatefulWidget {
  final String orderId;

  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  ConsumerState<OrderTrackingScreen> createState() =>
      _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends ConsumerState<OrderTrackingScreen>
    with SingleTickerProviderStateMixin {
  Timer? _pollTimer;
  int? _pollSecs;
  String? _pollOrderId;
  bool? _pollActive;
  DateTime _lastUpdated = DateTime.now();
  bool _cancelling = false;

  // Smooth driver glide (SiteDrop-style): interpolate the marker between
  // server fixes instead of jumping on every poll.
  AppMapPoint? _shownDriver;
  AppMapPoint? _glideFrom;
  AppMapPoint? _glideTo;
  AnimationController? _glideCtrl;

  // Buyer-side OSRM route (same directions the driver sees). The server
  // only stores a breadcrumb trail once in transit, so the live
  // driver→dropoff route is fetched directly for the map line + ETA.
  List<AppMapPoint> _buyerRoute = const [];
  double? _buyerRouteKm;
  double? _buyerRouteMin;
  AppMapPoint? _buyerRouteFrom;
  bool _fetchingBuyerRoute = false;

  @override
  void dispose() {
    _pollTimer?.cancel();
    _glideCtrl?.dispose();
    super.dispose();
  }

  /// Adaptive polling: 8s while the driver pin is live (real movement),
  /// 10s while waiting for assignment/first ping, off once terminal.
  /// Timer restarts only when the cadence changes.
  void _schedulePolling(OrderModel order, {required bool driverLive}) {
    if (!order.isTrackingActive) {
      _pollTimer?.cancel();
      _pollTimer = null;
      _pollSecs = null;
      return;
    }
    final secs = driverLive ? 8 : 10;
    if (_pollTimer != null &&
        _pollSecs == secs &&
        _pollOrderId == order.id &&
        _pollActive == order.isTrackingActive) {
      return;
    }
    _pollTimer?.cancel();
    _pollOrderId = order.id;
    _pollSecs = secs;
    _pollActive = order.isTrackingActive;
    _pollTimer = Timer.periodic(Duration(seconds: secs), (_) {
      if (!mounted) return;
      ref.invalidate(orderDetailsProvider(widget.orderId));
      ref.invalidate(orderTimelineProvider(widget.orderId));
      ref.invalidate(deliveryForOrderProvider(widget.orderId));
      setState(() => _lastUpdated = DateTime.now());
    });
  }

  /// Ease the rendered driver pin toward each new server fix.
  void _glideDriverTo(AppMapPoint? target) {
    if (target == null) {
      _shownDriver = null;
      _glideFrom = null;
      _glideTo = null;
      _glideCtrl?.stop();
      return;
    }
    final current = _shownDriver;
    if (current == null) {
      // First fix — place immediately (no setState: called during build).
      _shownDriver = target;
      _glideFrom = target;
      _glideTo = target;
      return;
    }
    if (current == target || _glideTo == target) return;
    _glideFrom = current;
    _glideTo = target;
    _glideCtrl ??=
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 2500),
        )..addListener(() {
          final t = _glideCtrl?.value ?? 1;
          final from = _glideFrom;
          final to = _glideTo;
          if (!mounted || from == null || to == null) return;
          // Ease-in-out interpolation.
          final e = t < 0.5 ? 2 * t * t : 1 - ((-2 * t + 2) * (-2 * t + 2)) / 2;
          setState(() {
            _shownDriver = AppMapPoint(
              from.latitude + (to.latitude - from.latitude) * e,
              from.longitude + (to.longitude - from.longitude) * e,
            );
          });
        });
    _glideCtrl!.forward(from: 0);
  }

  /// Fetch the live driver→dropoff OSRM route (same directions the
  /// driver sees). Throttled to significant driver moves; safe to call
  /// from build — no synchronous setState, flag flips before the gap.
  void _maybeBuyerRoute(AppMapPoint? driver, AppMapPoint? dest) {
    if (driver == null || dest == null || _fetchingBuyerRoute) return;
    final last = _buyerRouteFrom;
    if (last != null &&
        _buyerRoute.length >= 2 &&
        _haversineKm(last, driver) < 0.25) {
      return;
    }
    _fetchingBuyerRoute = true;
    _buyerRouteFrom = driver;
    ref
        .read(locationServiceProvider)
        .fetchDetailedRoute(driver, dest)
        .then((result) {
          if (!mounted) return;
          setState(() {
            _fetchingBuyerRoute = false;
            if (result != null) {
              _buyerRoute = result.points;
              _buyerRouteKm = result.distanceKm;
              _buyerRouteMin = result.durationMin;
            }
          });
        })
        .catchError((_) {
          if (mounted) setState(() => _fetchingBuyerRoute = false);
        });
  }

  double _haversineKm(AppMapPoint a, AppMapPoint b) {
    const r = 6371.0;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;
    final s1 = math.sin(dLat / 2);
    final s2 = math.sin(dLng / 2);
    final h =
        s1 * s1 +
        math.cos(a.latitude * math.pi / 180) *
            math.cos(b.latitude * math.pi / 180) *
            s2 *
            s2;
    return 2 * r * math.asin(math.sqrt(h.clamp(0.0, 1.0)));
  }

  Future<void> _refresh() async {
    ref.invalidate(orderDetailsProvider(widget.orderId));
    ref.invalidate(orderTimelineProvider(widget.orderId));
    ref.invalidate(deliveryForOrderProvider(widget.orderId));
    // Await the fresh reads so RefreshIndicator settles correctly.
    try {
      await Future.wait([
        ref.read(orderDetailsProvider(widget.orderId).future),
        ref.read(orderTimelineProvider(widget.orderId).future),
        ref.read(deliveryForOrderProvider(widget.orderId).future),
      ]);
    } catch (_) {
      // Errors surface through the providers' own error states.
    }
    if (mounted) setState(() => _lastUpdated = DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(orderDetailsProvider(widget.orderId));

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        backgroundColor: context.palette.surface,
        elevation: 0,
        title: appBarTitle(context, 'Track Order'),
        leading: AppBackButton(
          fallbackRoute: RouteNames.orderHistory,
          onPressed: () => _goBack(context),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh tracking',
            onPressed: () => _refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: orderAsync.when(
        data: (order) {
          if (order == null) return _buildNotFound(context);
          final timelineAsync = ref.watch(
            orderTimelineProvider(widget.orderId),
          );
          final deliveryAsync = ref.watch(
            deliveryForOrderProvider(widget.orderId),
          );
          final events = timelineAsync.asData?.value ?? order.timeline;
          final delivery = deliveryAsync.asData?.value;
          // Once a driver has accepted / been assigned, stop showing the
          // assignment-checking state — background refreshes keep the
          // driver card stable while live updates keep flowing.
          final assigned = delivery != null && delivery.hasDriver;
          final checkingAssignment = deliveryAsync.isLoading && !assigned;
          _schedulePolling(order, driverLive: delivery?.driverPoint != null);
          _glideDriverTo(delivery?.driverPoint);
          _maybeBuyerRoute(
            _shownDriver ?? delivery?.driverPoint,
            order.destinationPoint,
          );

          return SafeArea(
            child: RefreshIndicator(
              onRefresh: _refresh,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTrackerHero(context, order),
                    const SizedBox(height: 16),
                    _buildLiveMap(
                      context,
                      order,
                      delivery,
                      deliveryLoading: checkingAssignment,
                    ),
                    const SizedBox(height: 16),
                    _buildDriverCard(
                      context,
                      order,
                      delivery,
                      deliveryLoading: checkingAssignment,
                    ),
                    const SizedBox(height: 16),
                    _buildJourneyTimeline(
                      context,
                      order,
                      events,
                      timelineLoading: timelineAsync.isLoading,
                    ),
                    const SizedBox(height: 16),
                    _buildDeliveryInfo(context, order),
                    const SizedBox(height: 16),
                    _buildOrderItems(context, order),
                    const SizedBox(height: 16),
                    if (order.specialInstructions != null &&
                        order.specialInstructions!.isNotEmpty) ...[
                      _buildSpecialInstructions(context, order),
                      const SizedBox(height: 16),
                    ],
                    if (order.effectiveCanCancel && !order.isCancelled) ...[
                      _buildCancelAction(context, order),
                      const SizedBox(height: 16),
                    ],
                    if (order.effectiveCanReview && order.isCompleted) ...[
                      _buildRateAction(context, order),
                      const SizedBox(height: 16),
                    ],
                    _buildHelpSection(context),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          );
        },
        loading: () => const LoadingWidget(message: 'Loading live tracking…'),
        error: (error, stack) => _buildError(context, error, ref),
      ),
    );
  }

  // ============================================================
  // BACK NAVIGATION
  // ============================================================
  void _goBack(BuildContext context) {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
    } else {
      router.go(RouteNames.orderHistory);
    }
  }

  // ============================================================
  // STEP MAPPING
  // ============================================================
  /// Canonical step index for an order status. -1 = placed, awaiting confirm.
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
        return -2; // terminal failure — stepper hidden
    }
  }

  /// Map a free-text timeline status to a canonical step (or null).
  int? _eventStep(String status) {
    final s = status.toLowerCase();
    if (s.contains('cancel') ||
        s.contains('refund') ||
        s.contains('fail') ||
        s.contains('return')) {
      return -2;
    }
    if (s.contains('deliver') && !s.contains('ready')) return 4;
    if (s.contains('complet')) return 4;
    if (s.contains('transit') ||
        s.contains('dispatch') ||
        s.contains('pick') ||
        s.contains('arriv') ||
        s.contains('on the way') ||
        s.contains('on_the_way')) {
      return 3;
    }
    if (s.contains('ready')) return 2;
    if (s.contains('process') || s.contains('prepar') || s.contains('pack')) {
      return 1;
    }
    if (s.contains('confirm') || s.contains('accept') || s.contains('approv')) {
      return 0;
    }
    if (s.contains('pend') || s.contains('plac') || s.contains('creat')) {
      return -1;
    }
    return null;
  }

  String _relativeTime(DateTime at) {
    final diff = DateTime.now().difference(at);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return Helpers.formatDate(at);
  }

  // ============================================================
  // NOT FOUND / ERROR
  // ============================================================
  Widget _buildNotFound(BuildContext context) {
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
                  CupertinoIcons.exclamationmark_circle,
                  size: 60,
                  color: context.palette.iconMuted,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Order Not Found',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: context.palette.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'The order you are looking for does not exist',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.palette.textMuted,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => _goBack(context),
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
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, Object error, WidgetRef ref) {
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
                  color: AppColors.errorSurface,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  CupertinoIcons.exclamationmark_triangle,
                  size: 60,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Something went wrong',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: context.palette.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Could not load live tracking',
                style: TextStyle(
                  color: context.palette.textMuted,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      ref.invalidate(orderDetailsProvider(widget.orderId));
                      ref.invalidate(orderTimelineProvider(widget.orderId));
                      ref.invalidate(deliveryForOrderProvider(widget.orderId));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('Retry'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: () => _goBack(context),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: context.palette.borderStrong),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HERO TRACKER CARD
  // ============================================================
  Widget _buildTrackerHero(BuildContext context, OrderModel order) {
    final step = _stepIndex(order.status);
    final isTerminalFail = order.isCancelled;
    final isDone = order.isCompleted;
    final live = order.isTrackingActive;

    return Container(
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.palette.divider, width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #${order.code}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: context.palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      Helpers.formatDate(order.createdAt),
                      style: TextStyle(
                        color: context.palette.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              OrderStatusChip(status: order.status),
            ],
          ),
          const SizedBox(height: 12),
          // Live / updated row
          Row(
            children: [
              if (live) ...[
                _LiveDot(),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Live tracking',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                ),
              ] else if (isDone) ...[
                Icon(Icons.check_circle, size: 16, color: AppColors.success),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Delivered',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                ),
              ] else if (isTerminalFail) ...[
                Icon(Icons.cancel_outlined, size: 16, color: AppColors.error),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    order.statusLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.error,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              Flexible(
                child: Text(
                  'Updated ${_relativeTime(_lastUpdated)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.palette.textMuted,
                  ),
                ),
              ),
            ],
          ),
          if (!isTerminalFail) ...[
            const SizedBox(height: 14),
            _buildStepper(context, step),
          ],
          if (order.eta != null && !isTerminalFail) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: context.palette.primarySoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons.time_solid,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Arriving by ${Helpers.formatDate(order.eta!)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.palette.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStepper(BuildContext context, int step) {
    // step -1 (pending): all grey with the first node pulsing.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _trackerSteps.length; i++) ...[
          Expanded(child: _buildStepNode(context, i, step)),
          if (i < _trackerSteps.length - 1)
            Expanded(child: _buildStepLink(context, i, step)),
        ],
      ],
    );
  }

  Widget _buildStepNode(BuildContext context, int index, int step) {
    final done = index < step || step >= _trackerSteps.length;
    final current = index == step;
    final pendingPulse = step == -1 && index == 0;
    final color = done || current
        ? AppColors.primary
        : context.palette.borderStrong;
    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done
                ? AppColors.primary
                : current || pendingPulse
                ? context.palette.primarySoft
                : context.palette.surfaceMuted,
            border: Border.all(color: color, width: done ? 0 : 1.5),
          ),
          child: Icon(
            done
                ? Icons.check
                : current || pendingPulse
                ? Icons.local_shipping_outlined
                : Icons.circle,
            size: done ? 16 : 14,
            color: done
                ? Colors.white
                : current || pendingPulse
                ? AppColors.primary
                : context.palette.iconMuted,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _trackerSteps[index],
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10,
            fontWeight: current ? FontWeight.w700 : FontWeight.w500,
            color: done || current
                ? context.palette.textPrimary
                : context.palette.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLink(BuildContext context, int index, int step) {
    final filled = index < step;
    return Container(
      margin: const EdgeInsets.only(top: 14),
      height: 3,
      decoration: BoxDecoration(
        color: filled ? AppColors.primary : context.palette.borderStrong,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  // ============================================================
  // LIVE MAP CARD (OSM — free, no API key)
  // ============================================================
  Widget _buildLiveMap(
    BuildContext context,
    OrderModel order,
    DeliveryModel? delivery, {
    required bool deliveryLoading,
  }) {
    final dest = order.destinationPoint;
    // Animated pin (glides between server fixes); fall back to raw fix.
    final driver = _shownDriver ?? delivery?.driverPoint;
    final serverRoute = delivery != null && delivery.routePoints.length >= 2
        ? delivery.routePoints
        : const <AppMapPoint>[];
    // Prefer the live OSRM driver→dropoff route (same directions the
    // driver sees); fall back to the server breadcrumb trail, then a
    // straight connector while the route loads.
    final route = _buyerRoute.length >= 2
        ? _buyerRoute
        : (serverRoute.isNotEmpty
              ? [
                  ...serverRoute,
                  if (driver != null && serverRoute.last != driver) driver,
                ]
              : (driver != null && dest != null
                    ? <AppMapPoint>[driver, dest]
                    : const <AppMapPoint>[]));

    AppMapPoint? center = driver ?? dest;
    double zoom = 15;
    if (driver != null && dest != null) {
      center = AppMapPoint(
        (driver.latitude + dest.latitude) / 2,
        (driver.longitude + dest.longitude) / 2,
      );
      zoom = 13;
    }

    final markers = <AppMapMarker>{
      if (dest != null) AppMapMarker(id: 'destination', point: dest),
      if (driver != null)
        AppMapMarker(id: 'driver', point: driver, kind: AppMarkerKind.driver),
    };

    String overlayTitle = 'Live tracking';
    String? overlaySubtitle;
    if (order.isCompleted) {
      overlayTitle = 'Delivered — enjoy your materials';
      overlaySubtitle = order.deliveredAt != null
          ? Helpers.formatDate(order.deliveredAt!)
          : null;
    } else if (order.isCancelled) {
      overlayTitle = 'Order ${order.statusLabel.toLowerCase()}';
      overlaySubtitle = 'No further movement expected';
    } else if (driver != null) {
      overlayTitle = 'Driver is on the way';
      final bits = <String>[];
      final kmAway = delivery?.distanceKm ?? _buyerRouteKm;
      if (kmAway != null) {
        bits.add('${kmAway.toStringAsFixed(1)} km away');
      }
      if (delivery?.estimatedArrival != null) {
        bits.add('ETA ${Helpers.formatDate(delivery!.estimatedArrival!)}');
      } else if (order.eta != null) {
        bits.add('ETA ${Helpers.formatDate(order.eta!)}');
      } else if (_buyerRouteMin != null) {
        final m = _buyerRouteMin!.round();
        bits.add(m >= 60 ? '${m ~/ 60}h ${m % 60}m away' : '$m min away');
      }
      overlaySubtitle = bits.isEmpty ? null : bits.join(' · ');
    } else if (deliveryLoading) {
      overlayTitle = 'Locating your delivery…';
    } else if (delivery != null && delivery.hasDriver) {
      overlayTitle = '${delivery.driverName} is getting ready';
      overlaySubtitle = 'Live position appears once they move';
    } else if (order.status == OrderStatus.readyForDelivery ||
        order.status == OrderStatus.dispatched) {
      overlayTitle = 'Finding your driver…';
      overlaySubtitle = 'We\u2019ll show live movement here';
    } else {
      overlayTitle = 'Preparing your order';
      overlaySubtitle = 'Seller is getting your materials ready';
    }

    return Container(
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.palette.divider, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 240,
            child: center == null
                ? _buildMapPlaceholder(context, overlayTitle, deliveryLoading)
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      AppMap(
                        initialCameraPosition: AppCameraPosition(
                          target: center,
                          zoom: zoom,
                        ),
                        interactive: true,
                        hideAttribution: true,
                        markers: markers,
                        routePoints: route,
                      ),
                      Positioned(
                        left: 8,
                        bottom: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            '© OpenStreetMap contributors',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: context.palette.primarySoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    driver != null
                        ? Icons.local_shipping_outlined
                        : Icons.explore_outlined,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        overlayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: context.palette.textPrimary,
                        ),
                      ),
                      if (overlaySubtitle != null)
                        Text(
                          overlaySubtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.palette.textMuted,
                          ),
                        ),
                    ],
                  ),
                ),
                if (delivery?.trackingNumber != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: context.palette.surfaceMuted,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '#${delivery!.trackingNumber}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: context.palette.textMuted,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapPlaceholder(
    BuildContext context,
    String? title,
    bool loading,
  ) {
    return Container(
      color: context.palette.surfaceMuted,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            else
              Icon(
                Icons.local_shipping_outlined,
                size: 44,
                color: AppColors.primary.withValues(alpha: 0.7),
              ),
            const SizedBox(height: 10),
            Text(
              title ?? 'Preparing your order',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: context.palette.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DRIVER CARD
  // ============================================================
  Widget _buildDriverCard(
    BuildContext context,
    OrderModel order,
    DeliveryModel? delivery, {
    required bool deliveryLoading,
  }) {
    // Terminal orders: no driver section needed.
    if (order.isCancelled || order.isCompleted) {
      return const SizedBox.shrink();
    }
    if (deliveryLoading) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.palette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.palette.divider, width: 1),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Checking driver assignment…',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, color: context.palette.textMuted),
              ),
            ),
          ],
        ),
      );
    }
    if (delivery == null || !delivery.hasDriver) {
      final searching =
          order.status == OrderStatus.readyForDelivery ||
          order.status == OrderStatus.dispatched ||
          order.status == OrderStatus.inTransit;
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.palette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.palette.divider, width: 1),
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
              child: searching
                  ? const Padding(
                      padding: EdgeInsets.all(11),
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : Icon(
                      Icons.person_search_outlined,
                      color: AppColors.primary,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    searching ? 'Finding your driver…' : 'No driver yet',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: context.palette.textPrimary,
                    ),
                  ),
                  Text(
                    searching
                        ? 'We\u2019ll notify you once one accepts'
                        : 'A driver is assigned before dispatch',
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

    final name = delivery.driverName!.trim();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'D';
    final phone = delivery.driverPhone?.trim() ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.palette.divider, width: 1),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
            child: Text(
              initial,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: context.palette.textPrimary,
                  ),
                ),
                Text(
                  delivery.vehicleLabel ?? 'Your delivery driver',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.palette.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (phone.isNotEmpty)
            FilledButton.icon(
              onPressed: () => _callDriver(phone),
              icon: const Icon(Icons.call, size: 18),
              label: const Text('Call'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(64, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _callDriver(String phone) async {
    final uri = Uri.parse('tel:$phone');
    try {
      final ok = await launchUrl(uri);
      if (!ok && mounted) {
        Helpers.showErrorToast('Could not open the dialer');
      }
    } catch (_) {
      if (mounted) Helpers.showErrorToast('Could not open the dialer');
    }
  }

  // ============================================================
  // JOURNEY TIMELINE
  // ============================================================
  Widget _buildJourneyTimeline(
    BuildContext context,
    OrderModel order,
    List<OrderTimelineEvent> events, {
    required bool timelineLoading,
  }) {
    // Merge: canonical steps (with matched timestamps) + unmatched feed.
    final byStep = <int, List<OrderTimelineEvent>>{};
    final unmatched = <OrderTimelineEvent>[];
    for (final e in events) {
      final s = _eventStep(e.status);
      if (s == null || s < -1) {
        unmatched.add(e);
      } else {
        byStep.putIfAbsent(s, () => []).add(e);
      }
    }
    // Ensure the current order step shows even without events yet.
    final current = _stepIndex(order.status);

    return Container(
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.palette.divider, width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Journey',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: context.palette.textPrimary,
                  ),
                ),
              ),
              if (timelineLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Canonical steps with timestamps from matched events.
          for (var i = 0; i < _trackerSteps.length; i++)
            _buildJourneyRow(
              context,
              title: _trackerSteps[i],
              events: byStep[i] ?? const [],
              reached: current >= i || order.isCompleted,
              isCurrent: current == i && !order.isCompleted,
              isLast: i == _trackerSteps.length - 1 && unmatched.isEmpty,
            ),
          // Extra feed (cancellations, notes, unmatched statuses).
          for (final e in unmatched)
            _buildJourneyRow(
              context,
              title: e.label,
              events: [e],
              reached: true,
              isCurrent: false,
              isLast: e == unmatched.last,
              tone:
                  e.status.toLowerCase().contains('cancel') ||
                      e.status.toLowerCase().contains('fail')
                  ? AppColors.error
                  : null,
            ),
          if (events.isEmpty && !timelineLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Updates appear here as your order moves.',
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

  Widget _buildJourneyRow(
    BuildContext context, {
    required String title,
    required List<OrderTimelineEvent> events,
    required bool reached,
    required bool isCurrent,
    required bool isLast,
    Color? tone,
  }) {
    final dotColor =
        tone ?? (reached ? AppColors.primary : context.palette.borderStrong);
    final latest = events.isNotEmpty ? events.last : null;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: reached
                      ? (tone ?? AppColors.primary).withValues(alpha: 0.15)
                      : context.palette.surfaceMuted,
                  border: Border.all(color: dotColor, width: 1.5),
                ),
                child: Icon(
                  reached ? Icons.check : Icons.circle,
                  size: reached ? 12 : 8,
                  color: dotColor,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    color: reached
                        ? (tone ?? AppColors.primary).withValues(alpha: 0.4)
                        : context.palette.divider,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600,
                      fontSize: 14,
                      color: reached
                          ? context.palette.textPrimary
                          : context.palette.textMuted,
                    ),
                  ),
                  if (latest?.createdAt != null)
                    Text(
                      Helpers.formatDate(latest!.createdAt!),
                      style: TextStyle(
                        fontSize: 12,
                        color: context.palette.textMuted,
                      ),
                    ),
                  if (events.length > 1)
                    Text(
                      '+${events.length - 1} more update${events.length - 1 == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.palette.textMuted,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CANCEL ACTION
  // ============================================================
  Widget _buildCancelAction(BuildContext context, OrderModel order) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _cancelling ? null : () => _confirmCancel(context, order),
        icon: _cancelling
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.cancel_outlined, size: 18),
        label: Text(_cancelling ? 'Cancelling…' : 'Cancel order'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.error,
          side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // RATE ACTION (seller + trip) — completed orders only
  // ============================================================
  Widget _buildRateAction(BuildContext context, OrderModel order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.star_rounded, color: AppColors.warning, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enjoy your materials?',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: context.palette.textPrimary,
                  ),
                ),
                Text(
                  'Rate your order and trip',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.palette.textMuted,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => showOrderReviewSheet(context, ref, order),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(64, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Rate'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context, OrderModel order) async {
    // NOTE: no TextEditingController — disposing a dialog-owned controller
    // at close races the exit animation rebuild ("used after dispose").
    var reasonText = '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('The seller will be notified. This cannot be undone.'),
            const SizedBox(height: 12),
            TextField(
              maxLines: 2,
              onChanged: (v) => reasonText = v,
              decoration: const InputDecoration(
                hintText: 'Reason (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep order'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Cancel order'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _cancelling = true);
    try {
      final result = await OrderService.cancelOrder(
        orderId: order.id,
        reason: reasonText.trim().isEmpty
            ? 'Cancelled by buyer'
            : reasonText.trim(),
      );
      if (!mounted) return;
      if (result['success'] == true) {
        Helpers.showSuccessToast('Order cancelled');
        ref.invalidate(orderDetailsProvider(order.id));
        ref.invalidate(orderTimelineProvider(order.id));
        ref.invalidate(ordersProvider);
      } else {
        Helpers.showErrorToast(result['message'] ?? 'Could not cancel this order');
      }
    } catch (e) {
      if (mounted) Helpers.showErrorToast(e);
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  // ============================================================
  // DELIVERY INFO (kept from details view — same card system)
  // ============================================================
  Widget _buildDeliveryInfo(BuildContext context, OrderModel order) {
    return Container(
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.palette.divider, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Delivery Information',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: context.palette.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: context.palette.primarySoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    CupertinoIcons.location_solid,
                    size: 20,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    order.deliveryAddress.isNotEmpty
                        ? order.deliveryAddress
                        : 'No delivery address provided',
                    style: TextStyle(color: context.palette.icon, fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: context.palette.primarySoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    CupertinoIcons.phone_solid,
                    size: 20,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    order.deliveryPhone.isNotEmpty
                        ? order.deliveryPhone
                        : 'No phone number provided',
                    style: TextStyle(color: context.palette.icon, fontSize: 14),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SPECIAL INSTRUCTIONS
  // ============================================================
  Widget _buildSpecialInstructions(BuildContext context, OrderModel order) {
    return Container(
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.palette.divider, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  CupertinoIcons.doc_text,
                  size: 20,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Special Instructions',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: context.palette.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.palette.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.palette.divider, width: 1),
              ),
              child: Text(
                order.specialInstructions!,
                style: TextStyle(
                  fontSize: 14,
                  color: context.palette.textSecondary,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ORDER ITEMS (kept — same receipt card as before)
  // ============================================================
  Widget _buildOrderItems(BuildContext context, OrderModel order) {
    return Container(
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.palette.divider, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order Items',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: context.palette.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            if (order.items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'No items found for this order',
                    style: TextStyle(
                      color: context.palette.textMuted,
                      fontSize: 14,
                    ),
                  ),
                ),
              )
            else
              ...order.items.map(
                (item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      if (item.productImage != null &&
                          item.productImage!.isNotEmpty) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            item.productImage!,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: context.palette.surfaceMuted,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  CupertinoIcons.photo,
                                  color: context.palette.iconMuted,
                                  size: 24,
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.productName ?? item.product.name,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: context.palette.textSecondary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (item.unit != null && item.unit!.isNotEmpty)
                              Text(
                                'Unit: ${item.unit}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: context.palette.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${item.quantity}x ',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: context.palette.textMuted,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              Helpers.formatPrice(item.price),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Divider(color: context.palette.divider, height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'Subtotal',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: context.palette.textMuted,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    Helpers.formatPrice(order.subtotal),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 14,
                      color: context.palette.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'Delivery Fee',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: context.palette.textMuted,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    order.deliveryFee > 0
                        ? Helpers.formatPrice(order.deliveryFee)
                        : 'Free',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: order.deliveryFee > 0
                          ? context.palette.textSecondary
                          : AppColors.success,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'Service Fee (10%)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: context.palette.textMuted,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    Helpers.formatPrice(order.serviceFee),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 14,
                      color: context.palette.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Divider(color: context.palette.divider, height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'Total Amount',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: context.palette.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    Helpers.formatPrice(order.totalAmount),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HELP SECTION
  // ============================================================
  Widget _buildHelpSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.palette.primarySoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            CupertinoIcons.question_circle,
            color: AppColors.primary,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Need help with your order?',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: context.palette.textSecondary,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'Contact our support team',
                  style: TextStyle(
                    color: context.palette.textMuted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              final router = GoRouter.of(context);
              try {
                router.go(RouteNames.helpSupport);
              } catch (_) {
                context.showInfoToast('Support coming soon!');
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              minimumSize: const Size(64, 48),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: const Text(
              'Contact',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pulsing live dot (SiteDrop-style) for the tracker hero.
class _LiveDot extends StatefulWidget {
  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 1.0, end: 0.35).animate(_ctrl),
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: AppColors.success,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
