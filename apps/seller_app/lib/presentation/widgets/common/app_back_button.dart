// lib/presentation/widgets/common/app_back_button.dart
// Shared Cupertino-style back control — theme-aware (light + dark).
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sitedrop_core/app/routes/route_names.dart';
import 'package:sitedrop_core/app/theme/app_palette.dart';
import '../../providers/main_tab_provider.dart';

/// Circular Cupertino back button used as [AppBar.leading] (and overlays).
///
/// When [fallbackTabIndex] is set, falling back navigates to [fallbackRoute]
/// (usually home) and selects that bottom-nav tab so the shell bar stays visible.
class AppBackButton extends ConsumerWidget {
  final VoidCallback? onPressed;
  final String fallbackRoute;
  /// Buyer shell tab: 0 Home · 1 Categories · 2 Cart · 3 Wishlist · 4 Account
  final int? fallbackTabIndex;
  final Color? iconColor;
  final Color? backgroundColor;
  final bool showShadow;
  final EdgeInsetsGeometry margin;
  final bool plain;

  const AppBackButton({
    super.key,
    this.onPressed,
    this.fallbackRoute = RouteNames.home,
    this.fallbackTabIndex,
    this.iconColor,
    this.backgroundColor,
    this.showShadow = true,
    this.margin = const EdgeInsets.only(left: 8),
  }) : plain = false;

  /// Flat Cupertino chevron without circle.
  const AppBackButton.plain({
    super.key,
    this.onPressed,
    this.fallbackRoute = RouteNames.home,
    this.fallbackTabIndex,
    this.iconColor,
  })  : backgroundColor = Colors.transparent,
        showShadow = false,
        margin = EdgeInsets.zero,
        plain = true;

  void _handlePress(BuildContext context, WidgetRef ref) {
    if (onPressed != null) {
      onPressed!();
      return;
    }
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
      return;
    }
    if (fallbackTabIndex != null) {
      ref.read(mainTabIndexProvider.notifier).setIndex(fallbackTabIndex!);
    }
    router.go(fallbackRoute);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final resolvedIcon = iconColor ?? p.textPrimary;
    final resolvedBg = plain
        ? Colors.transparent
        : (backgroundColor ?? p.surface);

    final button = IconButton(
      icon: Icon(CupertinoIcons.back, color: resolvedIcon),
      onPressed: () => _handlePress(context, ref),
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      tooltip: 'Back',
    );

    if (plain) return button;

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: resolvedBg.withValues(alpha: 0.95),
        shape: BoxShape.circle,
        border: Border.all(color: p.border),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: p.shadow,
                  blurRadius: 8,
                ),
              ]
            : null,
      ),
      child: button,
    );
  }
}

/// Standard app [AppBar] title — theme-aware.
Text appBarTitle(BuildContext context, String title) {
  return Text(
    title,
    style: TextStyle(
      color: context.palette.textPrimary,
      fontWeight: FontWeight.w600,
      fontSize: 18,
    ),
  );
}
