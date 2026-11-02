// lib/presentation/widgets/common/buyer_bottom_nav.dart
// Shared theme-aware buyer bottom navigation (light + dark).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sitedrop_core/app/routes/route_names.dart';
import 'package:sitedrop_core/app/theme/colors.dart';
import '../../../core/utils/auth_gate.dart';
import '../../providers/cart_provider.dart';
import '../../providers/main_tab_provider.dart';
import '../../providers/wishlist_provider.dart';

/// Bottom nav used by [HomeScreen] and other buyer flows that should keep it.
class BuyerBottomNav extends ConsumerWidget {
  /// Override selected index. Defaults to [mainTabIndexProvider].
  final int? currentIndex;

  /// When true, tapping a tab only updates the provider (HomeScreen shell).
  /// When false (default for nested screens), also navigates to [RouteNames.home].
  final bool embeddedInShell;

  const BuyerBottomNav({
    super.key,
    this.currentIndex,
    this.embeddedInShell = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final selected = currentIndex ?? ref.watch(mainTabIndexProvider);
    final cartItems = ref.watch(cartProvider);
    final cartCount = cartItems.fold(0, (sum, item) => sum + item.quantity);
    // Watch wishlist so counts load on cold start (not only when tab opens).
    final wishlistCount = ref.watch(wishlistCountProvider);

    Future<void> select(int index) async {
      // Cart, Wishlist, Account require sign-in for guests.
      if (!AuthGate.isAuthenticated(ref) &&
          (index == 2 || index == 3 || index == 4)) {
        final action = switch (index) {
          2 => 'view your cart',
          3 => 'save items to your wishlist',
          _ => 'access your account',
        };
        await AuthGate.require(context, ref, action: action);
        return;
      }

      ref.read(mainTabIndexProvider.notifier).setIndex(index);
      if (!embeddedInShell) {
        // Return to shell so the tab body is shown
        context.go(RouteNames.home);
      }
    }

    return Material(
      color: p.navBarBg,
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: p.navBarBg,
          border: Border(top: BorderSide(color: p.border)),
          boxShadow: [
            BoxShadow(
              color: p.shadow,
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: selected == 0 ? Icons.home : Icons.home_outlined,
                label: 'Home',
                selected: selected == 0,
                onTap: () => select(0),
              ),
              _NavItem(
                icon: selected == 1
                    ? Icons.grid_view
                    : Icons.grid_view_outlined,
                label: 'Categories',
                selected: selected == 1,
                onTap: () => select(1),
              ),
              _NavItem(
                icon: selected == 2
                    ? Icons.shopping_cart
                    : Icons.shopping_cart_outlined,
                label: 'Cart',
                selected: selected == 2,
                badge: cartCount,
                onTap: () => select(2),
              ),
              _NavItem(
                icon: selected == 3 ? Icons.favorite : Icons.favorite_border,
                label: 'Wishlist',
                selected: selected == 3,
                badge: wishlistCount,
                onTap: () => select(3),
              ),
              _NavItem(
                icon: selected == 4 ? Icons.person : Icons.person_outline,
                label: 'Account',
                selected: selected == 4,
                onTap: () => select(4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final int? badge;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = selected ? p.navSelected : p.navUnselected;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      splashColor: p.primarySoft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: color, size: 26),
                if (badge != null && badge! > 0)
                  Positioned(
                    right: -6,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Center(
                        child: Text(
                          badge! > 9 ? '9+' : '$badge',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
