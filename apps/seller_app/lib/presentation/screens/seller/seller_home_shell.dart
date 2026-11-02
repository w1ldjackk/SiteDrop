// Seller shell: Dashboard | Products | Orders | Earnings | Profile
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sitedrop_core/app/theme/colors.dart';

import '../../providers/main_tab_provider.dart';
import 'earnings_screen.dart';
import 'order_management_screen.dart';
import 'product_management_screen.dart';
import 'seller_dashboard_tab.dart';
import '../profile/role_profile_screen.dart';

class SellerHomeShell extends ConsumerStatefulWidget {
  const SellerHomeShell({super.key});

  @override
  ConsumerState<SellerHomeShell> createState() => _SellerHomeShellState();
}

class _SellerHomeShellState extends ConsumerState<SellerHomeShell> {
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = const [
      SellerDashboardTab(),
      ProductManagementScreen(),
      OrderManagementScreen(),
      EarningsScreen(),
      ProfileScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final index = ref.watch(mainTabIndexProvider).clamp(0, 4);

    return PopScope(
      canPop: index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (index != 0) {
          ref.read(mainTabIndexProvider.notifier).setIndex(0);
          return;
        }
        SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: p.background,
        body: IndexedStack(index: index, children: _pages),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (i) =>
              ref.read(mainTabIndexProvider.notifier).setIndex(i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2),
              label: 'Products',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Orders',
            ),
            NavigationDestination(
              icon: Icon(Icons.payments_outlined),
              selectedIcon: Icon(Icons.payments),
              label: 'Earnings',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
