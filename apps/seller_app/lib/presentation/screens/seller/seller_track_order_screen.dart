// lib/presentation/screens/seller/seller_track_order_screen.dart
// Modern live order tracker for sellers — OSM live map (driver + destination + route),
// hero progress stepper, driver card, journey timeline, order details.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sitedrop_core/app/routes/route_names.dart';
import 'package:sitedrop_core/app/theme/colors.dart';
import 'package:sitedrop_core/data/models/cart_item.dart';
import 'package:sitedrop_core/data/models/delivery.dart';
import 'package:sitedrop_core/data/models/order.dart';
import 'package:sitedrop_core/data/models/tracking.dart';
import 'package:sitedrop_core/maps/app_map_point.dart';
import 'package:sitedrop_core/core/utils/helpers.dart';
import 'package:sitedrop_core/core/utils/formatters.dart';
import 'package:sitedrop_core/presentation/widgets/cards/order_status_chip.dart';
import '../../widgets/common/app_back_button.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/maps/app_map.dart';
import '../../providers/order_provider.dart';
import '../../providers/service_providers.dart';

/// Canonical journey steps (Bolt-style). Pending sits before step 0.
const _trackerSteps = [
  'Confirmed',
  'Preparing',
  'Ready for Delivery',
  'On the Way',
  'Delivered',
];

class SellerTrackOrderScreen extends ConsumerStatefulWidget {
  final String orderId;

  const SellerTrackOrderScreen({super.key, required this.orderId});

  @override
  ConsumerState<SellerTrackOrderScreen> createState() =>
      _SellerTrackOrderScreenState();
}

class _SellerTrackOrderScreenState extends ConsumerState<SellerTrackOrderScreen>
    with SingleTickerProviderStateMixin {
  Timer? _pollTimer;
  int? _pollSecs;
  String? _pollOrderId;
  bool? _pollActive;
  DateTime _lastUpdated = DateTime.now();

  // Smooth driver glide (Bolt-style): interpolate the marker between
  // server fixes instead of jumping on every poll.
  AppMapPoint? _shownDriver;
  AppMapPoint? _glideFrom;
  AppMapPoint? _glideTo;
  AnimationController? _glideCtrl;

  // Seller-side OSRM route (driver → destination).
  List<AppMapPoint> _sellerRoute = const [];
  double? _sellerRouteKm;
  double? _sellerRouteMin;
  AppMapPoint? _sellerRouteFrom;
  bool _fetchingSellerRoute = false;

  @override
  void dispose() {
    _pollTimer?.cancel();
    _glideCtrl?.dispose();
    super.dispose();
  }

  /// Adaptive polling: 8s while driver pin is live, 10s while waiting,
  /// off once terminal. Timer restarts only when cadence changes.
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

  /// Fetch the live driver→destination OSRM route. Throttled to significant
  /// driver moves; safe to call from build — no synchronous setState.
  void _maybeSellerRoute(AppMapPoint? driver, AppMapPoint? dest) {
    if (driver == null || dest == null || _fetchingSellerRoute) return;
    final last = _sellerRouteFrom;
    if (last != null &&
        _sellerRoute.length >= 2 &&
        _haversineKm(last, driver) < 0.25) {
      return;
    }
    _fetchingSellerRoute = true;
    _sellerRouteFrom = driver;
    ref
        .read(locationServiceProvider)
        .fetchDetailedRoute(driver, dest)
        .then((result) {
      if (!mounted) return;
      setState(() {
        _fetchingSellerRoute = false;
        if (result != null) {
          _sellerRoute = result.points;
          _sellerRouteKm = result.distanceKm;
          _sellerRouteMin = result.durationMin;
        }
      });
    }).catchError((_) {
      if (mounted) setState(() => _fetchingSellerRoute = false);
    });
  }

  double _haversineKm(AppMapPoint a, AppMapPoint b) {
    const r = 6371.0;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;
    final s1 = math.sin(dLat / 2);
    final s2 = math.sin(dLng / 2);
    final h = s1 * s1 +
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
    try {
      await Future.wait([
        ref.read(orderDetailsProvider(widget.orderId).future),
        ref.read(orderTimelineProvider(widget.orderId).future),
        ref.read(deliveryForOrderProvider(widget.orderId).future),
      ]);
    } catch (_) {}
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
          fallbackRoute: RouteNames.orderManagement,
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
          final assigned = delivery != null && delivery.hasDriver;
          final checkingAssignment = deliveryAsync.isLoading && !assigned;
          _schedulePolling(order, driverLive: delivery?.driverPoint != null);
          _glideDriverTo(delivery?.driverPoint);
          _maybeSellerRoute(
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
      router.go(RouteNames.orderManagement);
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
                  Icons.local_shipping_outlined,
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
                  Icons.error_outline,
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
                Text(
                  'Live tracking',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
              ] else if (isDone) ...[
                Icon(Icons.check_circle, size: 16, color: AppColors.success),
                const SizedBox(width: 6),
                Text(
                  'Delivered',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
              ] else if (isTerminalFail) ...[
                Icon(Icons.cancel_outlined, size: 16, color: AppColors.error),
                const SizedBox(width: 6),
                Text(
                  order.statusLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.error,
                  ),
                ),
              ],
              const Spacer(),
              Text(
                'Updated ${_relativeTime(_lastUpdated)}',
                style: TextStyle(
                  fontSize: 12,
                  color: context.palette.textMuted,
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
                    Icons.schedule_outlined,
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
    // Prefer the live OSRM driver→destination route (same directions the
    // driver sees); fall back to the server breadcrumb trail, then a
    // straight connector while the route loads.
    final route = _sellerRoute.length >= 2
        ? _sellerRoute
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
      overlayTitle = 'Delivered — order completed';
      overlaySubtitle = order.deliveredAt != null
          ? Helpers.formatDate(order.deliveredAt!)
          : null;
    } else if (order.isCancelled) {
      overlayTitle = 'Order ${order.statusLabel.toLowerCase()}';
      overlaySubtitle = 'No further movement expected';
    } else if (driver != null) {
      overlayTitle = 'Driver is on the way';
      final bits = <String>[];
      final kmAway = delivery?.distanceKm ?? _sellerRouteKm;
      if (kmAway != null) {
        bits.add('${kmAway.toStringAsFixed(1)} km away');
      }
      if (delivery?.estimatedArrival != null) {
        bits.add('ETA ${Helpers.formatDate(delivery!.estimatedArrival!)}');
      } else if (order.eta != null) {
        bits.add('ETA ${Helpers.formatDate(order.eta!)}');
      } else if (_sellerRouteMin != null) {
        final m = _sellerRouteMin!.round();
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
            Text(
              'Checking driver assignment…',
              style: TextStyle(fontSize: 14, color: context.palette.textMuted),
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
  // DELIVERY INFO
  // ============================================================
  Widget _buildDeliveryInfo(BuildContext context, OrderModel order) {
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
          Text(
            'Delivery Details',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: context.palette.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _infoRow(context.palette, 'Address', order.deliveryAddress),
          _infoRow(context.palette, 'Phone', order.deliveryPhone),
          if (order.deliveryScheduledAt != null)
            _infoRow(
                context.palette, 'Scheduled', Formatters.formatDateTime(order.deliveryScheduledAt!)),
          if (order.notes.isNotEmpty)
            _infoRow(context.palette, 'Notes', order.notes),
          if (order.specialInstructions?.isNotEmpty == true)
            _infoRow(context.palette, 'Special Instructions', order.specialInstructions!),
        ],
      ),
    );
  }

  // ============================================================
  // ORDER ITEMS
  // ============================================================
  Widget _buildOrderItems(BuildContext context, OrderModel order) {
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
          Text(
            'Order Items',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: context.palette.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          for (final item in order.items) ...[
            _OrderItemRow(item: item),
            if (item != order.items.last)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Divider(color: context.palette.divider, height: 1),
              ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(AppPalette p, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: p.textMuted, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 13, color: p.textPrimary, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

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
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.success.withValues(alpha: 0.4 + 0.6 * _ctrl.value),
          boxShadow: [
            BoxShadow(
              color: AppColors.success.withValues(alpha: 0.3 * _ctrl.value),
              blurRadius: 6,
              spreadRadius: 2 * _ctrl.value,
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderItemRow extends StatelessWidget {
  final CartItemModel item;

  const _OrderItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final imageUrl = item.productImage ?? item.product.imageUrl;
    return Row(
      children: [
        // Product image
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: p.surfaceMuted,
            borderRadius: BorderRadius.circular(8),
          ),
          child: imageUrl.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        Icon(Icons.local_shipping_outlined, color: p.iconMuted, size: 24),
                  ),
                )
              : Icon(Icons.local_shipping_outlined, color: p.iconMuted, size: 24),
        ),
        const SizedBox(width: 12),
        // Product info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: p.textPrimary,
                ),
              ),
              Text(
                'Qty: ${item.quantity} ${item.unit ?? item.product.unit}',
                style: TextStyle(fontSize: 12, color: p.textMuted),
              ),
            ],
          ),
        ),
        // Price
        Text(
          Formatters.formatCurrency(item.lineTotal),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: p.textPrimary,
          ),
        ),
      ],
    );
  }
}