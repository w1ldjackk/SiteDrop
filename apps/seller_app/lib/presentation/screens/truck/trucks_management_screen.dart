// lib/presentation/screens/truck/trucks_management_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sitedrop_core/app/routes/route_names.dart';
import 'package:sitedrop_core/app/theme/colors.dart';
import 'package:sitedrop_core/data/models/truck.dart';
import 'package:sitedrop_core/data/services/truck_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/app_back_button.dart';

class TrucksManagementScreen extends ConsumerStatefulWidget {
  const TrucksManagementScreen({super.key});

  @override
  ConsumerState<TrucksManagementScreen> createState() => _TrucksManagementScreenState();
}

class _TrucksManagementScreenState extends ConsumerState<TrucksManagementScreen> {
  final List<TruckModel> _trucks = [];
  bool _isLoading = true;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadTrucks();
  }

  Future<void> _loadTrucks({bool refresh = false}) async {
    if (refresh) {
      _trucks.clear();
      _hasMore = true;
    }
    if (!_hasMore) return;

    String? userId;
    ref.read(authProvider).when(
      data: (state) {
        if (state is AuthAuthenticated) userId = state.user.id;
      },
      loading: () {},
      error: (_, _) {},
    );
    if (userId == null) return;

    setState(() => _isLoading = true);
    try {
      final trucks = await TruckService.myTrucks(userId: userId);
      if (mounted) {
        setState(() {
          _trucks.addAll(trucks);
          _isLoading = false;
          _hasMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load trucks: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.surface,
        elevation: 0,
        title: Text('My Trucks', style: TextStyle(color: p.textPrimary)),
        leading: const AppBackButton(fallbackRoute: RouteNames.sellerDashboard),
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadTrucks(refresh: true),
        color: AppColors.primary,
        child: _isLoading && _trucks.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _trucks.isEmpty
                ? _buildEmpty()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _trucks.length,
                    itemBuilder: (context, index) {
                      final truck = _trucks[index];
                      return Card(
                        color: p.surface,
                        child: ListTile(
                          leading: const Icon(Icons.local_shipping, color: AppColors.primary),
                          title: Text('${truck.make} ${truck.model}'),
                          subtitle: Text('${truck.registrationNumber} • ${truck.capacityTons}t'),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {},
                        ),
                      );
                    },
                  ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(RouteNames.addTruck),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmpty() {
    final p = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_shipping_outlined, size: 64),
            const SizedBox(height: 12),
            Text('No trucks yet', style: TextStyle(color: p.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Add your first truck to start deliveries.', style: TextStyle(color: p.textMuted)),
          ],
        ),
      ),
    );
  }
}
