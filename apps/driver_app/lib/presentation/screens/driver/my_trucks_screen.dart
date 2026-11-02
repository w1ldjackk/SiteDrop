// lib/presentation/screens/driver/my_trucks_screen.dart
// Manage fleet: eligibility for TruckMatcher at a glance.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sitedrop_core/app/routes/route_names.dart';
import 'package:sitedrop_core/app/theme/colors.dart';
import 'package:sitedrop_core/data/models/truck.dart';
import '../../providers/truck_provider.dart';
import '../../widgets/common/app_back_button.dart';
import '../../widgets/common/loading_widget.dart';

class _EmptyTrucks extends StatelessWidget {
  const _EmptyTrucks();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.local_shipping_outlined, size: 64),
          SizedBox(height: 16),
          Text(
            'No truck yet',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          SizedBox(height: 8),
          Text(
            'Add your truck with capacity and insurance to get matched to trips.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class MyTrucksScreen extends ConsumerWidget {
  const MyTrucksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trucksAsync = ref.watch(myTrucksProvider);

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        backgroundColor: context.palette.surface,
        elevation: 0,
        title: appBarTitle(context, 'My trucks'),
        leading: const AppBackButton(
          fallbackRoute: RouteNames.profile,
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(RouteNames.driverTruckSetup),
        icon: const Icon(Icons.add),
        label: const Text('Add truck'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(myTrucksProvider),
          child: trucksAsync.when(
            data: (trucks) {
              if (trucks.isEmpty) {
                return ListView(
                  children: const [_EmptyTrucks()],
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: trucks.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) =>
                    _TruckCard(truck: trucks[i]),
              );
            },
            loading: () => const Center(child: LoadingWidget()),
            error: (e, _) => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: AppColors.errorSurface,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.error_outline,
                          size: 48,
                          color: AppColors.error,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Something went wrong',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Could not load trucks',
                        style: TextStyle(
                          color: context.palette.textMuted,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () =>
                            ref.invalidate(myTrucksProvider),
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
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TruckCard extends StatelessWidget {
  final TruckModel truck;

  const _TruckCard({required this.truck});

  void _openDetail(BuildContext context) {
    context.push(RouteNames.driverTruckDetail, extra: truck);
  }

  void _edit(BuildContext context) {
    context.push(RouteNames.driverTruckSetup, extra: truck);
  }

  @override
  Widget build(BuildContext context) {
    final ready = truck.matcherReady;
    return InkWell(
      onTap: () => _openDetail(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
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
                const Icon(Icons.local_shipping, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        truck.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '${truck.vehicleType.replaceAll('_', ' ')} · ${truck.capacityTons} tons',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.palette.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: (ready ? Colors.green : Colors.orange)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    ready ? 'Match-ready' : 'Action needed',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: ready ? Colors.green : Colors.orange,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Edit truck',
                  onPressed: () => _edit(context),
                  icon: Icon(
                    Icons.edit_outlined,
                    size: 20,
                    color: context.palette.textMuted,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                ),
              ],
            ),
            if (truck.blockerReason != null) ...[
              const SizedBox(height: 8),
              Text(
                truck.blockerReason!,
                style: const TextStyle(fontSize: 12, color: Colors.orange),
              ),
              const SizedBox(height: 4),
              Text(
                'Tap to view documents, insurance & history',
                style: TextStyle(
                  fontSize: 12,
                  color: context.palette.textMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
