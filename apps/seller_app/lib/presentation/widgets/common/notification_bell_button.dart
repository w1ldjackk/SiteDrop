// lib/presentation/widgets/common/notification_bell_button.dart
// App-level notifications icon with unread badge.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sitedrop_core/app/routes/route_names.dart';
import 'package:sitedrop_core/app/theme/colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';

/// Bell icon that shows unread count and opens [RouteNames.notifications].
class NotificationBellButton extends ConsumerWidget {
  const NotificationBellButton({
    super.key,
    this.iconSize = 26,
    this.color,
    this.useGo = false,
  });

  final double iconSize;
  final Color? color;
  final bool useGo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final auth = ref.watch(authProvider);
    final isAuthed =
        auth is AsyncData && auth.value is AuthAuthenticated;
    final unread = isAuthed ? ref.watch(notificationUnreadCountProvider) : 0;

    // Kick a lightweight count refresh when authenticated (idempotent).
    ref.watch(notificationBadgeBootstrapProvider);

    return IconButton(
      tooltip: unread > 0 ? 'Notifications ($unread unread)' : 'Notifications',
      onPressed: () {
        if (useGo) {
          context.go(RouteNames.notifications);
        } else {
          context.push(RouteNames.notifications);
        }
      },
      padding: const EdgeInsets.all(4),
      icon: Badge(
        isLabelVisible: unread > 0,
        backgroundColor: AppColors.error,
        smallSize: 8,
        label: Text(
          unread > 99 ? '99+' : '$unread',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: Icon(
          unread > 0
              ? Icons.notifications
              : Icons.notifications_outlined,
          color: color ?? p.icon,
          size: iconSize,
        ),
      ),
    );
  }
}
