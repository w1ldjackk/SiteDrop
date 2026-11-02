// lib/presentation/screens/profile/shared/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sitedrop_core/app/routes/route_names.dart';
import 'package:sitedrop_core/app/theme/colors.dart';
import 'package:sitedrop_core/data/services/app_info_service.dart';
import '../../../providers/theme_provider.dart';
import '../../../widgets/common/app_back_button.dart';
import '../../../widgets/common/loading_widget.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _saving = false;
  String? _statusMessage;
  String _versionLabel = '…';
  String _packageName = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(themeModeProvider.notifier).syncFromServer();
      _loadAppInfo();
    });
  }

  Future<void> _loadAppInfo() async {
    final version = await AppInfoService.versionLabel;
    final package = await AppInfoService.packageName;
    if (!mounted) return;
    setState(() {
      _versionLabel = version;
      _packageName = package;
    });
  }

  Future<void> _onSelectTheme(ThemeMode mode) async {
    setState(() {
      _saving = true;
      _statusMessage = null;
    });
    try {
      await ref.read(themeModeProvider.notifier).setThemeMode(mode);
      if (mounted) {
        setState(() => _statusMessage = 'Appearance saved');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _statusMessage = 'Saved on device (server sync failed)');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final themeMode = ref.watch(themeModeProvider);
    final themeNotifier = ref.read(themeModeProvider.notifier);

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.surface,
        elevation: 0,
        title: appBarTitle(context, 'Settings'),
        leading: const AppBackButton(
          fallbackRoute: RouteNames.home,
          fallbackTabIndex: 4,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Appearance',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: p.textMuted,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          // Material (not Container) so ListTile ink/splash is valid
          Material(
            color: p.surface,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: p.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _ThemeOption(
                  title: 'System',
                  subtitle: 'Follow device light / dark setting',
                  icon: Icons.brightness_auto,
                  selected: themeMode == ThemeMode.system,
                  enabled: !_saving,
                  onTap: () => _onSelectTheme(ThemeMode.system),
                ),
                Divider(height: 1, color: p.divider, indent: 16, endIndent: 16),
                _ThemeOption(
                  title: 'Light',
                  subtitle: 'Always use light mode',
                  icon: Icons.light_mode_outlined,
                  selected: themeMode == ThemeMode.light,
                  enabled: !_saving,
                  onTap: () => _onSelectTheme(ThemeMode.light),
                ),
                Divider(height: 1, color: p.divider, indent: 16, endIndent: 16),
                _ThemeOption(
                  title: 'Dark',
                  subtitle: 'Always use dark mode',
                  icon: Icons.dark_mode_outlined,
                  selected: themeMode == ThemeMode.dark,
                  enabled: !_saving,
                  onTap: () => _onSelectTheme(ThemeMode.dark),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_saving)
            const SizedBox(height: 48, child: LoadingWidget.compact()),
          if (_statusMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _statusMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: p.textMuted),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Current: ${themeNotifier.label}',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: p.textMuted),
          ),
          const SizedBox(height: 8),
          Text(
            'Synced to your account when signed in.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: p.textDisabled),
          ),
          const SizedBox(height: 32),
          Text(
            'About',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: p.textMuted,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          Material(
            color: p.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: p.border),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.info_outline, color: p.icon),
                  title: Text(
                    'Version',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: p.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    _versionLabel,
                    style: TextStyle(fontSize: 13, color: p.textMuted),
                  ),
                ),
                if (_packageName.isNotEmpty) ...[
                  Divider(
                    height: 1,
                    color: p.divider,
                    indent: 16,
                    endIndent: 16,
                  ),
                  ListTile(
                    leading: Icon(Icons.apps_outlined, color: p.icon),
                    title: Text(
                      'Package',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: p.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      _packageName,
                      style: TextStyle(fontSize: 13, color: p.textMuted),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final scheme = Theme.of(context).colorScheme;

    return ListTile(
      enabled: enabled,
      // Keep transparent so parent Material.color is the surface;
      // avoids "ink splashes may be invisible" assertions.
      tileColor: Colors.transparent,
      selectedTileColor: p.primarySoft.withValues(alpha: 0.45),
      selected: selected,
      splashColor: scheme.primary.withValues(alpha: 0.12),
      hoverColor: scheme.primary.withValues(alpha: 0.06),
      leading: Icon(icon, color: selected ? AppColors.primary : p.icon),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w600, color: p.textPrimary),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 13, color: p.textMuted),
      ),
      trailing: selected
          ? Icon(Icons.check_circle, color: AppColors.primary)
          : Icon(Icons.circle_outlined, color: p.borderStrong),
      onTap: enabled ? onTap : null,
    );
  }
}
