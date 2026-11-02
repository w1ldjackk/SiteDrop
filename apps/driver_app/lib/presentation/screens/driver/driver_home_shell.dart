// Driver shell: Available | My Trips | Earnings | Profile
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sitedrop_core/app/theme/colors.dart';

import '../../providers/main_tab_provider.dart';
import '../profile/role_profile_screen.dart';
import 'delivery_assignment_screen.dart';
import 'driver_earnings_screen.dart';
import 'driver_trips_tab.dart';

class DriverHomeShell extends ConsumerStatefulWidget {
  const DriverHomeShell({super.key});

  @override
  ConsumerState<DriverHomeShell> createState() => _DriverHomeShellState();
}

class _DriverHomeShellState extends ConsumerState<DriverHomeShell> {
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    // mainTabIndex is 0..4 in provider; driver uses 0..3
    _pages = const [
      DeliveryAssignmentScreen(),
      DriverTripsTab(),
      DriverEarningsScreen(),
      ProfileScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final raw = ref.watch(mainTabIndexProvider);
    final index = raw.clamp(0, 3);

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
              icon: Icon(Icons.local_shipping_outlined),
              selectedIcon: Icon(Icons.local_shipping),
              label: 'Available',
            ),
            NavigationDestination(
              icon: Icon(Icons.route_outlined),
              selectedIcon: Icon(Icons.route),
              label: 'My Trips',
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
