// lib/presentation/screens/profile/shared/settings_screen.dart
// Account Settings: Appearance, Language, Notifications matrix
// (Products / Promos & tips / Partner offers × Email / Push / SMS),
// Security (two-step, password, biometric, passkeys), About.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sitedrop_core/app/routes/route_names.dart';
import 'package:sitedrop_core/app/theme/colors.dart';
import 'package:sitedrop_core/core/utils/helpers.dart';
import 'package:sitedrop_core/data/services/app_info_service.dart';
import 'package:sitedrop_core/data/services/preferences_service.dart';
import 'package:sitedrop_core/data/services/settings_service.dart';
import '../../../../core/i18n/app_strings.dart';
import '../../../../core/utils/biometric_helper.dart';
import '../../../providers/locale_provider.dart';
import '../../../providers/preferences_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../widgets/common/app_back_button.dart';
import '../../../widgets/common/loading_widget.dart';
import '../../../widgets/security/security_sheets.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _savingTheme = false;
  bool _biometricOn = false;
  bool _biometricAvailable = false;
  final Set<String> _busyKeys = {};
  String _versionLabel = '…';
  String _packageName = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(themeModeProvider.notifier).syncFromServer();
      _loadAppInfo();
      _loadBiometric();
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

  Future<void> _loadBiometric() async {
    final available = await BiometricHelper.isAvailable();
    final enabled = await BiometricHelper.localEnabled();
    if (!mounted) return;
    setState(() {
      _biometricAvailable = available;
      _biometricOn = available && enabled;
    });
  }

  Future<void> _onSelectTheme(ThemeMode mode) async {
    String t(String k) => tr(ref.read(localeProvider), k);
    setState(() => _savingTheme = true);
    try {
      await ref.read(themeModeProvider.notifier).setThemeMode(mode);
      if (mounted) Helpers.showSuccessToast(t('settings.saved'));
    } catch (_) {
      if (mounted) Helpers.showErrorToast(t('settings.save_failed'));
    } finally {
      if (mounted) setState(() => _savingTheme = false);
    }
  }

  Future<void> _togglePref(String key, bool value) async {
    String t(String k) => tr(ref.read(localeProvider), k);
    setState(() => _busyKeys.add(key));
    try {
      await savePreference(ref, key, value);
      if (mounted) Helpers.showSuccessToast(t('settings.saved'));
    } catch (_) {
      if (mounted) Helpers.showErrorToast(t('settings.save_failed'));
    } finally {
      if (mounted) setState(() => _busyKeys.remove(key));
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    String t(String k) => tr(ref.read(localeProvider), k);
    if (value) {
      final ok = await BiometricHelper.authenticate(
        'Enable biometric unlock for SiteDrop',
      );
      if (!ok) {
        if (mounted) Helpers.showErrorToast(t('settings.save_failed'));
        return;
      }
    }
    await BiometricHelper.setLocalEnabled(value);
    try {
      await SettingsService.setKey('biometric_unlock', value);
    } catch (_) {}
    if (!mounted) return;
    setState(() => _biometricOn = value);
    Helpers.showSuccessToast(t('settings.saved'));
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    String t(String k) => tr(locale, k);
    final p = context.palette;
    final themeMode = ref.watch(themeModeProvider);
    final prefsAsync = ref.watch(userPreferencesProvider);
    final twoFaAsync = ref.watch(twoFactorProvider);
    final prefs = prefsAsync.asData?.value ?? {};

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.surface,
        elevation: 0,
        title: appBarTitle(context, t('settings.title')),
        leading: const AppBackButton(
          fallbackRoute: RouteNames.home,
          fallbackTabIndex: 4,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionLabel(context, t('settings.appearance')),
          const SizedBox(height: 8),
          _card(context, [
            _ThemeOption(
              title: t('settings.theme_system'),
              subtitle: t('settings.theme_system_sub'),
              icon: Icons.brightness_auto,
              selected: themeMode == ThemeMode.system,
              enabled: !_savingTheme,
              onTap: () => _onSelectTheme(ThemeMode.system),
            ),
            _divider(context),
            _ThemeOption(
              title: t('settings.theme_light'),
              subtitle: t('settings.theme_light_sub'),
              icon: Icons.light_mode_outlined,
              selected: themeMode == ThemeMode.light,
              enabled: !_savingTheme,
              onTap: () => _onSelectTheme(ThemeMode.light),
            ),
            _divider(context),
            _ThemeOption(
              title: t('settings.theme_dark'),
              subtitle: t('settings.theme_dark_sub'),
              icon: Icons.dark_mode_outlined,
              selected: themeMode == ThemeMode.dark,
              enabled: !_savingTheme,
              onTap: () => _onSelectTheme(ThemeMode.dark),
            ),
          ]),
          const SizedBox(height: 24),
          _sectionLabel(context, t('settings.language')),
          const SizedBox(height: 8),
          _card(context, [
            for (var i = 0;
                i < AppLanguages.supported.length;
                i++) ...[
              if (i > 0) _divider(context),
              _LanguageOption(
                code: AppLanguages.supported[i],
                selected:
                    (prefs['language']?.toString() ?? locale) ==
                        AppLanguages.supported[i],
                busy: _busyKeys.contains('language'),
                onTap: () async {
                  await ref
                      .read(localeProvider.notifier)
                      .setLocale(AppLanguages.supported[i]);
                  ref.invalidate(userPreferencesProvider);
                },
              ),
            ],
          ]),
          const SizedBox(height: 8),
          Text(
            t('settings.synced_note'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: p.textDisabled),
          ),
          const SizedBox(height: 24),
          _sectionLabel(context, t('settings.notifications')),
          const SizedBox(height: 8),
          prefsAsync.when(
            data: (_) =>           _card(context, [
              _NotifCategory(
                locale: locale,
                category: 'products',
                title: t('notif.products'),
                subtitle: t('notif.products_sub'),
                icon: Icons.inventory_2_outlined,
                values: {
                  for (final ch in NotifPrefs.channels)
                    ch: PreferencesService.boolOf(
                      prefs,
                      NotifPrefs.key('products', ch),
                      true,
                    ),
                },
                busyKeys: _busyKeys,
                onChanged: (ch, v) =>
                    _togglePref(NotifPrefs.key('products', ch), v),
              ),
              _divider(context),
              _NotifCategory(
                locale: locale,
                category: 'promos',
                title: t('notif.promos'),
                subtitle: t('notif.promos_sub'),
                icon: Icons.local_offer_outlined,
                values: {
                  for (final ch in NotifPrefs.channels)
                    ch: PreferencesService.boolOf(
                      prefs,
                      NotifPrefs.key('promos', ch),
                      ch != 'sms',
                    ),
                },
                busyKeys: _busyKeys,
                onChanged: (ch, v) =>
                    _togglePref(NotifPrefs.key('promos', ch), v),
              ),
              _divider(context),
              _NotifCategory(
                locale: locale,
                category: 'partner',
                title: t('notif.partner'),
                subtitle: t('notif.partner_sub'),
                icon: Icons.handshake_outlined,
                values: {
                  for (final ch in NotifPrefs.channels)
                    ch: PreferencesService.boolOf(
                      prefs,
                      NotifPrefs.key('partner', ch),
                      false,
                    ),
                },
                busyKeys: _busyKeys,
                onChanged: (ch, v) =>
                    _togglePref(NotifPrefs.key('partner', ch), v),
              ),
            ]),
            loading: () => _card(context, const [
              SizedBox(
                height: 120,
                child: LoadingWidget.compact(),
              ),
            ]),
            error: (e, _) => _card(context, [
              ListTile(
                title: Text(Helpers.errorMessage(e)),
                trailing: TextButton(
                  onPressed: () =>
                      ref.invalidate(userPreferencesProvider),
                  child: Text(t('common.retry')),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 24),
          _sectionLabel(context, t('settings.security')),
          const SizedBox(height: 8),
          _card(context, [
            twoFaAsync.when(
              data: (s) => _SecurityRow(
                icon: Icons.security_outlined,
                title: t('sec.two_step'),
                subtitle: s.enabled
                    ? t('sec.two_step_on')
                    : t('sec.two_step_off'),
                statusColor:
                    s.enabled ? AppColors.success : p.textMuted,
                onTap: () => showTwoFactorSheet(context),
              ),
              loading: () => const ListTile(
                leading: SizedBox(
                  width: 20,
                  height: 20,
                  child:
                      CircularProgressIndicator(strokeWidth: 2),
                ),
                title: Text('…'),
              ),
              error: (_, _) => _SecurityRow(
                icon: Icons.security_outlined,
                title: t('sec.two_step'),
                subtitle: t('sec.two_step_off'),
                onTap: () => showTwoFactorSheet(context),
              ),
            ),
            _divider(context),
            _SecurityRow(
              icon: Icons.lock_outline,
              title: t('sec.change_password'),
              subtitle: t('sec.change_password_sub'),
              onTap: () => showPasswordSheet(context),
            ),
            _divider(context),
            _SecurityRow(
              icon: Icons.fingerprint_outlined,
              title: t('sec.biometric'),
              subtitle: _biometricAvailable
                  ? t('sec.biometric_sub')
                  : t('sec.biometric_unavailable'),
              trailing: _biometricAvailable
                  ? Switch(
                      value: _biometricOn,
                      activeThumbColor: AppColors.primary,
                      onChanged: _toggleBiometric,
                    )
                  : null,
              onTap: _biometricAvailable
                  ? () => _toggleBiometric(!_biometricOn)
                  : null,
            ),
            _divider(context),
            _SecurityRow(
              icon: Icons.key_outlined,
              title: t('sec.passkey'),
              subtitle: t('sec.passkey_sub'),
              onTap: () => showPasskeySheet(context),
            ),
          ]),
          const SizedBox(height: 24),
          _sectionLabel(context, t('settings.about')),
          const SizedBox(height: 8),
          _card(context, [
            ListTile(
              leading: Icon(Icons.info_outline, color: p.icon),
              title: Text(
                t('settings.version'),
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
              _divider(context),
              ListTile(
                leading: Icon(Icons.apps_outlined, color: p.icon),
                title: Text(
                  t('settings.package'),
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
          ]),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: context.palette.textMuted,
        letterSpacing: 0.4,
      ),
    );
  }

  Widget _card(BuildContext context, List<Widget> children) {
    return Material(
      color: context.palette.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: context.palette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  Widget _divider(BuildContext context) {
    return Divider(
      height: 1,
      color: context.palette.divider,
      indent: 16,
      endIndent: 16,
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

class _LanguageOption extends StatelessWidget {
  final String code;
  final bool selected;
  final bool busy;
  final VoidCallback onTap;

  const _LanguageOption({
    required this.code,
    required this.selected,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ListTile(
      enabled: !busy,
      tileColor: Colors.transparent,
      selectedTileColor: p.primarySoft.withValues(alpha: 0.45),
      selected: selected,
      leading: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: p.primarySoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          code.toUpperCase(),
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: AppColors.primary,
          ),
        ),
      ),
      title: Text(
        AppLanguages.nameOf(code),
        style: TextStyle(fontWeight: FontWeight.w600, color: p.textPrimary),
      ),
      trailing: selected
          ? Icon(Icons.check_circle, color: AppColors.primary)
          : Icon(Icons.circle_outlined, color: p.borderStrong),
      onTap: busy ? null : onTap,
    );
  }
}

class _NotifCategory extends StatelessWidget {
  final String locale;
  final String category;
  final String title;
  final String subtitle;
  final IconData icon;
  final Map<String, bool> values;
  final Set<String> busyKeys;
  final void Function(String channel, bool value) onChanged;

  const _NotifCategory({
    required this.locale,
    required this.category,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.values,
    required this.busyKeys,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: p.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: p.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final ch in NotifPrefs.channels)
                Expanded(
                  child: _ChannelToggle(
                    label: tr(locale, 'notif.$ch'),
                    value: values[ch] ?? false,
                    enabled: !busyKeys.contains(
                      NotifPrefs.key(category, ch),
                    ),
                    onChanged: (v) => onChanged(ch, v),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChannelToggle extends StatelessWidget {
  final String label;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _ChannelToggle({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: value
            ? AppColors.primary.withValues(alpha: 0.10)
            : p.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: value
              ? AppColors.primary.withValues(alpha: 0.35)
              : p.border,
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: value ? AppColors.primary : p.textMuted,
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: AppColors.primary,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onChanged: enabled ? onChanged : null,
          ),
        ],
      ),
    );
  }
}

class _SecurityRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? statusColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SecurityRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.statusColor,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ListTile(
      tileColor: Colors.transparent,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: p.primarySoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w600, color: p.textPrimary),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 13,
          color: statusColor ?? p.textMuted,
          fontWeight:
              statusColor != null ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      trailing: trailing ??
          Icon(Icons.chevron_right, color: p.iconMuted),
      onTap: onTap,
    );
  }
}
