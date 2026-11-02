// lib/presentation/screens/profile/shared/profile_ui.dart
// Shared profile chrome used by UserProfile + SellerProfile screens.
// Theme-aware for light + dark.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sitedrop_core/app/routes/route_names.dart';
import 'package:sitedrop_core/app/theme/colors.dart';
import 'package:sitedrop_core/core/utils/helpers.dart';
import 'package:sitedrop_core/data/models/user.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/common/notification_bell_button.dart';

class ProfileMenuItem {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final String? badge;
  final String? subtitle;

  const ProfileMenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.badge,
    this.subtitle,
  });
}

class ProfileStat {
  final String label;
  final String value;
  final IconData icon;

  const ProfileStat({
    required this.label,
    required this.value,
    required this.icon,
  });
}

/// Common app bar with avatar, name, notifications, settings.
PreferredSizeWidget buildProfileAppBar({
  required BuildContext context,
  required User? user,
  String? subtitle,
}) {
  final p = context.palette;

  return AppBar(
    backgroundColor: Colors.transparent,
    elevation: 0,
    titleSpacing: 0,
    toolbarHeight: 80,
    title: Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 2),
            ),
            child: CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.primary,
              backgroundImage: user?.avatar != null && user!.avatar!.isNotEmpty
                  ? NetworkImage(user.avatar!)
                  : null,
              child: user?.avatar == null || user!.avatar!.isEmpty
                  ? Text(
                      user != null && user.name.isNotEmpty
                          ? user.name[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontSize: 24,
                        color: p.textOnPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  user != null ? user.name : 'Guest',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: p.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (user != null)
                  Text(
                    subtitle ?? user.phone,
                    style: TextStyle(fontSize: 13, color: p.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
    actions: [
      NotificationBellButton(iconSize: 26, color: p.icon),
      IconButton(
        onPressed: () => context.push(RouteNames.settings),
        icon: Icon(Icons.settings_outlined, color: p.icon, size: 26),
      ),
      const SizedBox(width: 4),
    ],
  );
}

Widget buildProfileStatsRow(BuildContext context, List<ProfileStat> stats) {
  return Row(children: stats.map((s) => _statCard(context, s)).toList());
}

Widget _statCard(BuildContext context, ProfileStat stat) {
  final p = context.palette;
  return Expanded(
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.border, width: 1),
      ),
      child: Column(
        children: [
          Icon(stat.icon, color: AppColors.primary, size: 24),
          const SizedBox(height: 4),
          Text(
            stat.value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: p.textPrimary,
            ),
          ),
          Text(stat.label, style: TextStyle(fontSize: 11, color: p.textMuted)),
        ],
      ),
    ),
  );
}

Widget buildProfileMenuSection({
  required BuildContext context,
  required String title,
  required List<ProfileMenuItem> items,
}) {
  final p = context.palette;

  return Material(
    color: p.surface,
    borderRadius: BorderRadius.circular(16),
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: p.textMuted,
                letterSpacing: 0.5,
              ),
            ),
          ),
          ...items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return Column(
              children: [
                ListTile(
                  tileColor: Colors.transparent,
                  leading: Icon(item.icon, color: p.icon, size: 22),
                  title: Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: p.textPrimary,
                    ),
                  ),
                  subtitle: item.subtitle != null
                      ? Text(
                          item.subtitle!,
                          style: TextStyle(fontSize: 12, color: p.textMuted),
                        )
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (item.badge != null)
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            item.badge!,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: p.textOnPrimary,
                            ),
                          ),
                        ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: p.iconMuted,
                      ),
                    ],
                  ),
                  onTap: item.onTap,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 2,
                  ),
                ),
                if (index < items.length - 1)
                  Divider(
                    height: 1,
                    color: p.divider,
                    indent: 16,
                    endIndent: 16,
                  ),
              ],
            );
          }),
        ],
      ),
    ),
  );
}

Widget buildProfileLogoutButton(WidgetRef ref, BuildContext context) {
  return SizedBox(
    width: double.infinity,
    child: ElevatedButton.icon(
      onPressed: () async {
        await ref.read(authProvider.notifier).logout();
        if (context.mounted) {
          Helpers.showSuccessToast('Logged out successfully');
          context.go(RouteNames.login);
        }
      },
      icon: Icon(Icons.logout, color: Colors.white, size: 20),
      label: Text(
        'Logout',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.error,
        foregroundColor: AppColors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );
}

Widget buildProfileGuestView(BuildContext context) {
  final p = context.palette;

  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: p.surfaceMuted,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.person_outline, size: 60, color: p.iconMuted),
        ),
        const SizedBox(height: 24),
        Text(
          'Not Logged In',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: p.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Log in or create an account to access your profile,\ncart, wishlist, and orders.',
          textAlign: TextAlign.center,
          style: TextStyle(color: p.textMuted, fontSize: 15, height: 1.4),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: 220,
          child: ElevatedButton(
            onPressed: () => context.push(RouteNames.login),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            child: Text('Log in'),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: 220,
          child: OutlinedButton(
            onPressed: () => context.push(RouteNames.register),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text('Sign up'),
          ),
        ),
      ],
    ),
  );
}

Widget buildSupportMenuSection(BuildContext context) {
  return buildProfileMenuSection(
    context: context,
    title: 'Support',
    items: [
      ProfileMenuItem(
        icon: Icons.help_outline,
        title: 'Help & Support',
        onTap: () => context.push(RouteNames.helpSupport),
      ),
      ProfileMenuItem(
        icon: Icons.description_outlined,
        title: 'Terms of Service',
        onTap: () => context.push(RouteNames.termsOfService),
      ),
      ProfileMenuItem(
        icon: Icons.lock_outline,
        title: 'Privacy Policy',
        onTap: () => context.push(RouteNames.privacyPolicy),
      ),
    ],
  );
}
