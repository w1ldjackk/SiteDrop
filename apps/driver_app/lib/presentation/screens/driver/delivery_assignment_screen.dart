// lib/presentation/screens/driver/delivery_assignment_screen.dart
// SiteDrop-style driver loop: online toggle, live trip requests (accept/decline),
// my active trips with status progression + GPS pinging (feeds buyer map).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sitedrop_core/app/routes/route_names.dart';
import 'package:sitedrop_core/app/theme/colors.dart';
import 'package:sitedrop_core/core/utils/display_names.dart';
import 'package:sitedrop_core/core/utils/helpers.dart';
import 'package:sitedrop_core/data/models/delivery.dart';
import 'package:sitedrop_core/data/models/tracking.dart';
import 'package:sitedrop_core/data/services/delivery_service.dart';
import 'package:sitedrop_core/maps/app_map_point.dart';
import '../../providers/delivery_provider.dart';
import '../../providers/service_providers.dart';
import '../../widgets/common/app_back_button.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/notification_bell_button.dart';
import '../../widgets/maps/trip_route_map.dart';

/// Next driver action per delivery status (SiteDrop trip flow).
const _nextStep = {
  'accepted': ('picked_up', 'Picked up — start trip'),
  'picked_up': ('in_transit', 'Start trip'),
  'in_transit': ('arrived', 'Arrived at dropoff'),
  'arrived': ('completed', 'Complete delivery'),
};

class DeliveryAssignmentScreen extends ConsumerStatefulWidget {
  const DeliveryAssignmentScreen({super.key});

  @override
  ConsumerState<DeliveryAssignmentScreen> createState() =>
      _DeliveryAssignmentScreenState();
}

class _DeliveryAssignmentScreenState
    extends ConsumerState<DeliveryAssignmentScreen>
    with WidgetsBindingObserver {
  Timer? _pollTimer;
  StreamSubscription<Position>? _gpsSub;
  String? _trackedDeliveryId;
  DateTime? _lastPing;
  bool _toggling = false;
  bool _reloading = false;
  final Set<String> _busy = {};

  /// Offers already alerted (never pop twice for the same request).
  final Set<String> _alertedOffers = {};
  bool _alertOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Offer + trip polling (10s) while online — buyer sees a driver fast.
    // Silent: keeps the last known list, no loading flash (like buyer).
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted || !ref.read(driverOnlineProvider)) return;
      ref.read(deliveryOffersProvider.notifier).silentRefresh();
      ref.read(myDeliveriesProvider.notifier).silentRefresh();
    });
    // Movement-based GPS follows the active trip (feeds buyer live map).
    ref.listenManual(
      myDeliveriesProvider,
      (previous, next) => next.whenData(_syncGpsTracking),
    );
    // SiteDrop-style pop-up the moment a NEW request lands.
    ref.listenManual(
      deliveryOffersProvider,
      (previous, next) => next.whenData(_alertNewOffers),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _stopGps();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Resume → instant refresh + presence heartbeat so dispatch
    // targeting stays fresh (reliable online sync).
    if (state == AppLifecycleState.resumed && mounted) {
      if (ref.read(driverOnlineProvider)) {
        _refresh();
        _heartbeatPresence();
      }
    }
  }

  Future<void> _heartbeatPresence() async {
    try {
      AppMapPoint? pos;
      try {
        pos = await ref.read(locationServiceProvider).getCurrentMapPoint();
      } catch (_) {}
      await DeliveryService.setPresence(
        online: true,
        lat: pos?.latitude,
        lng: pos?.longitude,
      );
    } catch (_) {}
  }

  /// Pop an alert sheet for offers we haven't shown yet (online only).
  void _alertNewOffers(List<DeliveryOfferModel> offers) {
    if (!mounted || !ref.read(driverOnlineProvider) || _alertOpen) return;
    final fresh = offers.where((o) => !_alertedOffers.contains(o.id)).toList();
    if (fresh.isEmpty) return;
    for (final o in fresh) {
      _alertedOffers.add(o.id);
    }
    // Prune ids that are gone (accepted/expired elsewhere).
    final liveIds = offers.map((o) => o.id).toSet();
    _alertedOffers.retainAll(liveIds);
    _alertedOffers.add(fresh.first.id);
    _alertOpen = true;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => _OfferAlertSheet(offer: fresh.first),
    ).then((_) {
      _alertOpen = false;
      if (mounted) _refresh();
    });
  }

  /// Start/stop motion tracking to match the active trip (SiteDrop-style:
  /// ping on movement, not wall-clock, throttled to ≥12s).
  void _syncGpsTracking(List<DeliveryModel> deliveries) {
    if (!mounted) return;
    final online = ref.read(driverOnlineProvider);
    final active =
        online ? deliveries.where(isDeliveryActive).toList() : [];
    if (active.isEmpty) {
      _stopGps();
      return;
    }
    final id = active.first.id;
    if (_gpsSub != null && _trackedDeliveryId == id) return;
    _stopGps();
    _trackedDeliveryId = id;
    try {
      final stream = ref
          .read(locationServiceProvider)
          .watchLocation(distanceFilterMeters: 15);
      _gpsSub = stream.listen(
        (pos) => _onGps(pos, id),
        onError: (_) {},
        cancelOnError: false,
      );
    } catch (_) {
      _trackedDeliveryId = null;
    }
  }

  Future<void> _onGps(Position pos, String deliveryId) async {
    final now = DateTime.now();
    if (_lastPing != null && now.difference(_lastPing!).inSeconds < 12) {
      return;
    }
    _lastPing = now;
    await DeliveryService.postLocation(
      deliveryId,
      pos.latitude,
      pos.longitude,
    );
  }

  void _stopGps() {
    _gpsSub?.cancel();
    _gpsSub = null;
    _trackedDeliveryId = null;
  }

  /// Manual refresh (button + pull-to-refresh) — shows the full loading
  /// screen while fetching, like the buyer track-orders refresh.
  Future<void> _refresh() async {
    if (!mounted || _reloading) return;
    setState(() => _reloading = true);
    try {
      await Future.wait([
        ref.read(deliveryOffersProvider.notifier).refresh(),
        ref.read(myDeliveriesProvider.notifier).refresh(),
      ]);
    } finally {
      if (mounted) setState(() => _reloading = false);
    }
  }

  Future<void> _toggleOnline(bool online) async {
    if (_toggling) return;
    setState(() => _toggling = true);
    try {
      AppMapPoint? pos;
      try {
        pos = await ref
            .read(locationServiceProvider)
            .getCurrentMapPoint();
      } catch (_) {}
      final (ok, message) = await DeliveryService.setPresence(
        online: online,
        lat: pos?.latitude,
        lng: pos?.longitude,
      );
      if (!mounted) return;
      if (ok) {
        ref.read(driverOnlineProvider.notifier).set(online);
        if (online) {
          _refresh();
        } else {
          _stopGps();
        }
        Helpers.showSuccessToast(message);
      } else {
        Helpers.showErrorToast(message);
      }
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  Future<void> _answerOffer(DeliveryOfferModel offer, bool accept) async {
    if (_busy.contains(offer.id)) return;
    setState(() => _busy.add(offer.id));
    try {
      final (ok, message) = accept
          ? await DeliveryService.acceptOffer(offer.id)
          : await DeliveryService.declineOffer(offer.id);
      if (!mounted) return;
      if (ok) {
        Helpers.showSuccessToast(message);
      } else {
        Helpers.showErrorToast(message);
      }
      _refresh();
      if (accept && ok) _pingAcceptedTripOnce();
    } finally {
      if (mounted) setState(() => _busy.remove(offer.id));
    }
  }

  Future<void> _advance(DeliveryModel d) async {
    final next = _nextStep[d.status];
    if (next == null || _busy.contains(d.id)) return;
    setState(() => _busy.add(d.id));
    try {
      final (ok, message) =
          await DeliveryService.updateStatus(d.id, next.$1);
      if (!mounted) return;
      if (ok) {
        Helpers.showSuccessToast(message);
      } else {
        Helpers.showErrorToast(message);
      }
      _refresh();
    } finally {
      if (mounted) setState(() => _busy.remove(d.id));
    }
  }

  /// Accept a directly-assigned trip (admin manual assignment).
  Future<void> _acceptAssignment(DeliveryModel d) async {
    if (_busy.contains(d.id)) return;
    setState(() => _busy.add(d.id));
    try {
      final (ok, message) = await DeliveryService.acceptAssignment(d.id);
      if (!mounted) return;
      if (ok) {
        Helpers.showSuccessToast(message);
      } else {
        Helpers.showErrorToast(message);
      }
      _refresh();
      if (ok) _pingAcceptedTripOnce();
    } finally {
      if (mounted) setState(() => _busy.remove(d.id));
    }
  }

  /// Decline a directly-assigned trip → re-offered to other online drivers.
  Future<void> _declineAssignment(DeliveryModel d) async {
    if (_busy.contains(d.id)) return;
    setState(() => _busy.add(d.id));
    try {
      final (ok, message) = await DeliveryService.declineAssignment(d.id);
      if (!mounted) return;
      if (ok) {
        Helpers.showSuccessToast(message);
      } else {
        Helpers.showErrorToast(message);
      }
      _refresh();
    } finally {
      if (mounted) setState(() => _busy.remove(d.id));
    }
  }

  /// Post the driver's current GPS once for the newly accepted trip so
  /// the buyer sees a live pin instantly (the motion stream only pings
  /// after the driver actually moves ≥15m).
  Future<void> _pingAcceptedTripOnce() async {
    try {
      final trips = await ref.read(myDeliveriesProvider.future);
      final active = trips.where(isDeliveryActive).toList();
      if (active.isEmpty || !mounted) return;
      final pos = await ref
          .read(locationServiceProvider)
          .getCurrentLocation();
      await DeliveryService.postLocation(
        active.first.id,
        pos.latitude,
        pos.longitude,
      );
    } catch (_) {}
  }

  Future<void> _call(String phone) async {
    final uri = Uri.parse('tel:$phone');
    try {
      final ok = await launchUrl(uri);
      if (!ok && mounted) Helpers.showErrorToast('Could not open the dialer');
    } catch (_) {
      if (mounted) Helpers.showErrorToast('Could not open the dialer');
    }
  }

  @override
  Widget build(BuildContext context) {
    final online = ref.watch(driverOnlineProvider);
    final offersAsync = ref.watch(deliveryOffersProvider);
    final tripsAsync = ref.watch(myDeliveriesProvider);

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        backgroundColor: context.palette.surface,
        elevation: 0,
        title: appBarTitle(context, 'Delivery Assignments'),
        leading: const AppBackButton(
          fallbackRoute: RouteNames.driverDashboard,
        ),
        actions: [
          const NotificationBellButton(iconSize: 26, useGo: true),
          if (_reloading)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            )
          else
            IconButton(
              tooltip: 'Refresh',
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: AppColors.primary,
          child: _reloading
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: const [
                    SizedBox(height: 120),
                    Center(
                      child: LoadingWidget(message: 'Loading trips…'),
                    ),
                  ],
                )
              : ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              _buildOnlineCard(context, online),
              const SizedBox(height: 16),
              _buildSectionTitle(
                context,
                'Trip requests',
                Icons.directions_car_outlined,
                count: offersAsync.asData?.value.length,
                live: true,
              ),
              const SizedBox(height: 12),
              offersAsync.when(
                data: (offers) => offers.isEmpty
                    ? _buildEmptyOffers(context, online)
                    : Column(
                        children: [
                          for (final o in offers) ...[
                            _buildOfferCard(context, o),
                            const SizedBox(height: 12),
                          ],
                        ],
                      ),
                loading: () => const LoadingWidget.compact(),
                error: (e, _) => _buildInlineError(
                  context,
                  'Could not load requests',
                  () => ref.read(deliveryOffersProvider.notifier).refresh(),
                ),
              ),
              const SizedBox(height: 16),
              _buildSectionTitle(
                context,
                'My trips',
                Icons.local_shipping_outlined,
              ),
              const SizedBox(height: 12),
              tripsAsync.when(
                data: (trips) {
                  final assigned = trips.where((t) => t.status == 'assigned').toList();
                  final active =
                      trips.where(isDeliveryActive).toList();
                  final done = trips
                      .where((t) => !isDeliveryActive(t) && t.status != 'assigned')
                      .take(5)
                      .toList();
                  if (assigned.isEmpty && active.isEmpty && done.isEmpty) {
                    return _buildEmptyTrips(context);
                  }
                  return Column(
                    children: [
                      for (final t in assigned) ...[
                        _buildAssignedCard(context, t),
                        const SizedBox(height: 12),
                      ],
                      for (final t in active) ...[
                        _buildTripCard(context, t),
                        const SizedBox(height: 12),
                      ],
                      for (final t in done) ...[
                        _buildTripCard(context, t, compact: true),
                        const SizedBox(height: 8),
                      ],
                    ],
                  );
                },
                loading: () => const LoadingWidget.compact(),
                error: (e, _) => _buildInlineError(
                  context,
                  'Could not load trips',
                  () => ref.read(myDeliveriesProvider.notifier).refresh(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ONLINE TOGGLE
  // ============================================================
  Widget _buildOnlineCard(BuildContext context, bool online) {
    return Container(
      padding: const EdgeInsets.all(16),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  online ? 'You are online' : 'You are offline',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: context.palette.textPrimary,
                  ),
                ),
                Text(
                  online
                      ? 'Trip requests will appear below'
                      : 'Go online to receive trip requests',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.palette.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (_toggling)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          else
            Switch(
              value: online,
              activeThumbColor: AppColors.success,
              onChanged: _toggleOnline,
            ),
        ],
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
    int? count,
    bool live = false,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: context.palette.textPrimary,
            ),
          ),
        ),
        if (live && (count ?? 0) > 0)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: AppColors.error,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count new',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }

  // ============================================================
  // OFFER CARD (SiteDrop-style trip request)
  // ============================================================
  Widget _buildOfferCard(BuildContext context, DeliveryOfferModel o) {
    final busy = _busy.contains(o.id);
    final earnings = o.effectivePayout;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.45),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  o.orderNumber.isNotEmpty
                      ? 'Order ${o.orderNumber}'
                      : 'New trip request',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: context.palette.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 14,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      o.secondsLeft > 0 ? '${o.secondsLeft}s' : 'expiring',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.warning,
                        fontFeatures: const [
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.place_outlined,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  o.deliveryAddress.isNotEmpty
                      ? o.deliveryAddress
                      : 'Dropoff shown after accept',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: context.palette.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(
                context,
                Icons.payments_outlined,
                'GHS ${o.deliveryFee.toStringAsFixed(2)} fee',
              ),
              _chip(
                context,
                Icons.account_balance_wallet_outlined,
                'You earn GHS ${earnings.toStringAsFixed(2)}',
              ),
              if (o.itemCount > 0)
                _chip(
                  context,
                  Icons.inventory_2_outlined,
                  '${o.itemCount} item${o.itemCount == 1 ? '' : 's'}',
                ),
              if (o.distanceKm != null)
                _chip(
                  context,
                  Icons.route_outlined,
                  '${o.distanceKm!.toStringAsFixed(1)} km',
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (o.destination != null)
            _RouteSection(
              destination: o.destination!,
              label: o.orderNumber.isNotEmpty
                  ? 'Order ${o.orderNumber}'
                  : 'Dropoff',
              initiallyExpanded: false,
            ),
          if (o.destination != null) const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      busy ? null : () => _answerOffer(o, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: BorderSide(
                      color: AppColors.error.withValues(alpha: 0.5),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: busy ? null : () => _answerOffer(o, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Accept trip',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: context.palette.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: context.palette.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.palette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ASSIGNED CARD (admin direct assignment — accept / decline)
  // ============================================================
  Widget _buildAssignedCard(BuildContext context, DeliveryModel t) {
    final busy = _busy.contains(t.id);
    final title = t.orderNumber?.isNotEmpty == true
        ? 'Order ${t.orderNumber}'
        : '#${t.trackingNumber ?? t.id}';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.55),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Assigned to you · $title',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: context.palette.textPrimary,
                  ),
                ),
              ),
              _statusPill(context, t.status),
            ],
          ),
          if ((t.dropAddress ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.place_outlined,
                  size: 16,
                  color: context.palette.textMuted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    t.dropAddress!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.palette.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if ((t.buyerName ?? '').isNotEmpty ||
              (t.buyerPhone ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.person_outline,
                  size: 16,
                  color: context.palette.textMuted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    t.buyerName?.isNotEmpty == true
                        ? t.buyerName!
                        : (t.buyerPhone ?? ''),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.palette.textSecondary,
                    ),
                  ),
                ),
                if ((t.buyerPhone ?? '').isNotEmpty)
                  IconButton(
                    tooltip: 'Call buyer',
                    onPressed: () => _call(t.buyerPhone!),
                    icon: Icon(
                      Icons.call_outlined,
                      color: AppColors.primary,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : () => _declineAssignment(t),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: BorderSide(
                      color: AppColors.error.withValues(alpha: 0.5),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: busy ? null : () => _acceptAssignment(t),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Accept trip',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TRIP CARD
  // ============================================================
  Widget _buildTripCard(
    BuildContext context,
    DeliveryModel t, {
    bool compact = false,
  }) {
    final busy = _busy.contains(t.id);
    final next = _nextStep[t.status];
    final active = isDeliveryActive(t);
    final title = t.orderNumber?.isNotEmpty == true
        ? 'Order ${t.orderNumber}'
        : '#${t.trackingNumber ?? t.id}';

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
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: context.palette.textPrimary,
                  ),
                ),
              ),
              _statusPill(context, t.status),
            ],
          ),
          if (!compact) ...[
            const SizedBox(height: 8),
            if ((t.dropAddress ?? '').isNotEmpty)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.place_outlined,
                    size: 16,
                    color: context.palette.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      t.dropAddress!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.palette.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            if ((t.buyerName ?? '').isNotEmpty ||
                (t.buyerPhone ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 16,
                    color: context.palette.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      t.buyerName?.isNotEmpty == true
                          ? t.buyerName!
                          : (t.buyerPhone ?? ''),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.palette.textSecondary,
                      ),
                    ),
                  ),
                  if ((t.buyerPhone ?? '').isNotEmpty)
                    IconButton(
                      tooltip: 'Call buyer',
                      onPressed: () => _call(t.buyerPhone!),
                      icon: Icon(
                        Icons.call_outlined,
                        color: AppColors.primary,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: 44,
                      ),
                    ),
                ],
              ),
            ],
            if (active && next != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: busy ? null : () => _advance(t),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          next.$2,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
            // Live route to the buyer — expanded while the trip is active.
            if (active && t.destination != null) ...[
              const SizedBox(height: 12),
              _RouteSection(
                destination: t.destination!,
                label: t.orderNumber?.isNotEmpty == true
                    ? 'Order ${t.orderNumber}'
                    : 'Dropoff',
                initiallyExpanded: true,
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _statusPill(BuildContext context, String status) {
    final label = DisplayNames.deliveryStatusLabel(status);
    final color = switch (status) {
      'completed' => AppColors.success,
      'failed' => AppColors.error,
      'in_transit' || 'picked_up' || 'arrived' => AppColors.primary,
      _ => AppColors.warning,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY / ERROR
  // ============================================================
  Widget _buildEmptyOffers(BuildContext context, bool online) {
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
            online
                ? Icons.notifications_none_outlined
                : Icons.cloud_off_outlined,
            size: 32,
            color: context.palette.iconMuted,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              online
                  ? 'No requests right now — new trips pop up here'
                  : 'Go online to start receiving trip requests',
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

  Widget _buildEmptyTrips(BuildContext context) {
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
            Icons.route_outlined,
            size: 32,
            color: context.palette.iconMuted,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No trips yet — accepted trips appear here',
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

  Widget _buildInlineError(
    BuildContext context,
    String message,
    VoidCallback onRetry,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.errorSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(message, style: const TextStyle(fontSize: 13)),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

/// SiteDrop-style incoming request pop-up: countdown ring, payout, one-tap
/// accept/decline. Auto-closes when the offer expires or is taken.
class _OfferAlertSheet extends ConsumerStatefulWidget {
  final DeliveryOfferModel offer;

  const _OfferAlertSheet({required this.offer});

  @override
  ConsumerState<_OfferAlertSheet> createState() => _OfferAlertSheetState();
}

class _OfferAlertSheetState extends ConsumerState<_OfferAlertSheet> {
  Timer? _ticker;
  int _left = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _tick();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _tick() {
    final exp = widget.offer.expiresAt;
    final left = exp == null
        ? 0
        : exp.difference(DateTime.now()).inSeconds;
    if (!mounted) return;
    if (left <= 0) {
      Navigator.pop(context);
      return;
    }
    setState(() => _left = left);
  }

  Future<void> _answer(bool accept) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final (ok, message) = accept
          ? await DeliveryService.acceptOffer(widget.offer.id)
          : await DeliveryService.declineOffer(widget.offer.id);
      if (!mounted) return;
      ref.invalidate(deliveryOffersProvider);
      ref.invalidate(myDeliveriesProvider);
      // Fire-and-forget: buyer sees a live pin instantly on accept.
      if (accept && ok) _pingFreshTrip();
      Navigator.pop(context);
      if (ok) {
        Helpers.showSuccessToast(message);
      } else {
        Helpers.showErrorToast(message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Post current GPS once for the just-accepted trip (buyer live pin).
  Future<void> _pingFreshTrip() async {
    try {
      final trips = await ref.read(myDeliveriesProvider.future);
      final active = trips.where(isDeliveryActive).toList();
      if (active.isEmpty || !mounted) return;
      final pos =
          await ref.read(locationServiceProvider).getCurrentMapPoint();
      await DeliveryService.postLocation(
        active.first.id,
        pos.latitude,
        pos.longitude,
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.offer;
    final earnings = o.effectivePayout;
    final progress = (_left / DeliveryOfferModelX.ttl).clamp(0.0, 1.0);

    return Container(
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
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.palette.borderStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                SizedBox(
                  width: 56,
                  height: 56,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 5,
                        color: AppColors.warning,
                        backgroundColor:
                            context.palette.surfaceMuted,
                      ),
                      Text(
                        '$_left',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          fontFeatures: [
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'New trip request',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: context.palette.textPrimary,
                        ),
                      ),
                      Text(
                        o.orderNumber.isNotEmpty
                            ? 'Order ${o.orderNumber}'
                            : 'First to accept wins',
                        style: TextStyle(
                          fontSize: 13,
                          color: context.palette.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.place_outlined,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    o.deliveryAddress.isNotEmpty
                        ? o.deliveryAddress
                        : 'Dropoff shown after accept',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Trip payout',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.palette.textSecondary,
                    ),
                  ),
                  Text(
                    'GHS ${earnings.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _busy ? null : () => _answer(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(
                        color: AppColors.error
                            .withValues(alpha: 0.5),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed:
                        _busy ? null : () => _answer(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Accept trip',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
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
}

/// Offer window seconds (mirrors backend DeliveryOffer::OFFER_TTL_SECONDS).
extension DeliveryOfferModelX on DeliveryOfferModel {
  static const int ttl = 90;
}

/// Expandable live route to the buyer dropoff (mounted only when open
/// so GPS + tiles stay off until the driver needs them).
class _RouteSection extends StatefulWidget {
  final AppMapPoint destination;
  final String label;
  final bool initiallyExpanded;

  const _RouteSection({
    required this.destination,
    required this.label,
    this.initiallyExpanded = false,
  });

  @override
  State<_RouteSection> createState() => _RouteSectionState();
}

class _RouteSectionState extends State<_RouteSection> {
  late bool _open = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: () => setState(() => _open = !_open),
          icon: Icon(
            _open ? Icons.expand_less : Icons.route_outlined,
            size: 18,
          ),
          label: Text(_open ? 'Hide route' : 'Route & directions'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: BorderSide(
              color: AppColors.primary.withValues(alpha: 0.5),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        if (_open) ...[
          const SizedBox(height: 8),
          TripRouteMap(
            destination: widget.destination,
            tripLabel: widget.label,
          ),
        ],
      ],
    );
  }
}
