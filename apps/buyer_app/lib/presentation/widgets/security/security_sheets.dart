// lib/presentation/widgets/security/security_sheets.dart
// Account Security bottom sheets: password change, two-step (TOTP)
// setup/confirm/disable, and the passkey waitlist. All strings via tr().

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sitedrop_core/app/theme/colors.dart';
import 'package:sitedrop_core/core/utils/helpers.dart';
import 'package:sitedrop_core/data/services/preferences_service.dart';
import 'package:sitedrop_core/data/services/settings_service.dart';
import '../../../core/i18n/app_strings.dart';
import '../../providers/locale_provider.dart';
import '../../providers/preferences_provider.dart';

void _showSheet(BuildContext context, Widget child) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => child,
  );
}

Widget _handle(BuildContext context) {
  return Center(
    child: Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.palette.borderStrong,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}

BoxDecoration _sheetBox(BuildContext context) {
  return BoxDecoration(
    color: context.palette.surface,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
  );
}

// ============================================================
// PASSWORD
// ============================================================
void showPasswordSheet(BuildContext context) =>
    _showSheet(context, const _PasswordSheet());

class _PasswordSheet extends ConsumerStatefulWidget {
  const _PasswordSheet();

  @override
  ConsumerState<_PasswordSheet> createState() => _PasswordSheetState();
}

class _PasswordSheetState extends ConsumerState<_PasswordSheet> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  bool _obscure = true;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    String t(String k) => tr(ref.read(localeProvider), k);
    if (_next.text.length < 8) {
      Helpers.showErrorToast(t('sec.pwd_short'));
      return;
    }
    if (_next.text != _confirm.text) {
      Helpers.showErrorToast(t('sec.pwd_mismatch'));
      return;
    }
    setState(() => _saving = true);
    try {
      await SecurityService.changePassword(
        currentPassword: _current.text,
        newPassword: _next.text,
        confirmPassword: _confirm.text,
      );
      if (!mounted) return;
      Navigator.pop(context);
      Helpers.showSuccessToast(t('sec.pwd_changed'));
    } catch (e) {
      if (mounted) Helpers.showErrorToast(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    String t(String k) => tr(locale, k);
    final p = context.palette;
    final inset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: Container(
        decoration: _sheetBox(context),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _handle(context),
              Text(
                t('sec.pwd_title'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: p.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              _pwdField(
                context,
                controller: _current,
                hint: t('sec.pwd_current'),
                obscure: _obscure,
              ),
              const SizedBox(height: 12),
              _pwdField(
                context,
                controller: _next,
                hint: t('sec.pwd_new'),
                obscure: _obscure,
              ),
              const SizedBox(height: 12),
              _pwdField(
                context,
                controller: _confirm,
                hint: t('sec.pwd_confirm'),
                obscure: _obscure,
                onSubmitted: _save,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Checkbox(
                    value: !_obscure,
                    activeColor: AppColors.primary,
                    onChanged: (v) =>
                        setState(() => _obscure = !(v ?? false)),
                  ),
                  Text(
                    'Show',
                    style:
                        TextStyle(fontSize: 13, color: p.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(t('sec.pwd_save')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pwdField(
    BuildContext context, {
    required TextEditingController controller,
    required String hint,
    required bool obscure,
    VoidCallback? onSubmitted,
  }) {
    final p = context.palette;
    return TextField(
      controller: controller,
      obscureText: obscure,
      textInputAction: TextInputAction.next,
      onSubmitted: onSubmitted == null ? null : (_) => onSubmitted(),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: p.inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: p.borderStrong),
        ),
      ),
    );
  }
}

// ============================================================
// TWO-FACTOR (TOTP)
// ============================================================
void showTwoFactorSheet(BuildContext context) =>
    _showSheet(context, const _TwoFactorSheet());

class _TwoFactorSheet extends ConsumerStatefulWidget {
  const _TwoFactorSheet();

  @override
  ConsumerState<_TwoFactorSheet> createState() => _TwoFactorSheetState();
}

class _TwoFactorSheetState extends ConsumerState<_TwoFactorSheet> {
  String? _secret;
  List<String> _recovery = [];
  final _code = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _enable() async {
    setState(() => _busy = true);
    try {
      final data = await SecurityService.enableTwoFactor();
      if (!mounted) return;
      setState(() {
        _secret = data['secret']?.toString();
        final codes = data['recovery_codes'];
        _recovery = codes is List
            ? codes.map((e) => e.toString()).toList()
            : const [];
      });
    } catch (e) {
      if (mounted) Helpers.showErrorToast(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    String t(String k) => tr(ref.read(localeProvider), k);
    if (_code.text.trim().length < 6) return;
    setState(() => _busy = true);
    try {
      await SecurityService.confirmTwoFactor(_code.text);
      if (!mounted) return;
      ref.invalidate(twoFactorProvider);
      Navigator.pop(context);
      Helpers.showSuccessToast(t('sec.t2fa_confirmed'));
    } catch (e) {
      if (mounted) Helpers.showErrorToast(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disable() async {
    String t(String k) => tr(ref.read(localeProvider), k);
    setState(() => _busy = true);
    try {
      await SecurityService.disableTwoFactor();
      if (!mounted) return;
      ref.invalidate(twoFactorProvider);
      Navigator.pop(context);
      Helpers.showSuccessToast(t('sec.t2fa_disabled'));
    } catch (e) {
      if (mounted) Helpers.showErrorToast(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    String t(String k) => tr(locale, k);
    final p = context.palette;
    final statusAsync = ref.watch(twoFactorProvider);
    final inset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: Container(
        decoration: _sheetBox(context),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _handle(context),
                Text(
                  t('sec.t2fa_title'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: p.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                statusAsync.when(
                  data: (s) {
                    if (s.enabled) return _enabledView(t, p);
                    if (_secret == null) return _startView(t, p);
                    return _confirmView(t, p);
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (e, _) => Text(
                    Helpers.errorMessage(e),
                    style: TextStyle(color: AppColors.error),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _startView(String Function(String) t, AppPalette p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t('sec.t2fa_scan_body'),
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: p.textSecondary,
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _busy ? null : _enable,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Text(t('sec.two_step')),
          ),
        ),
      ],
    );
  }

  Widget _confirmView(String Function(String) t, AppPalette p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_secret != null) ...[
          Text(
            t('sec.t2fa_secret'),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: p.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: _secret!));
              Helpers.showSuccessToast(t('sec.t2fa_copied'));
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: p.inputFill,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: p.borderStrong),
              ),
              child: SelectableText(
                _secret!,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: p.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (_recovery.isNotEmpty) ...[
          Text(
            t('sec.t2fa_recovery'),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: p.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.warning.withValues(alpha: 0.35),
              ),
            ),
            child: SelectableText(
              _recovery.join('\n'),
              style: TextStyle(fontSize: 13, color: p.textPrimary),
            ),
          ),
          const SizedBox(height: 16),
        ],
        TextField(
          controller: _code,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: 8,
          ),
          decoration: InputDecoration(
            hintText: t('sec.t2fa_code_hint'),
            filled: true,
            fillColor: p.inputFill,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: p.borderStrong),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _busy ? null : _confirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(t('sec.t2fa_confirm')),
          ),
        ),
      ],
    );
  }

  Widget _enabledView(String Function(String) t, AppPalette p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.check_circle,
                color: AppColors.success, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                t('sec.t2fa_enabled'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: p.textSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _busy ? null : _disable,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: BorderSide(
                color: AppColors.error.withValues(alpha: 0.5),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(t('sec.t2fa_disable')),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// PASSKEY WAITLIST (device passkeys rolling out)
// ============================================================
void showPasskeySheet(BuildContext context) =>
    _showSheet(context, const _PasskeySheet());

class _PasskeySheet extends ConsumerStatefulWidget {
  const _PasskeySheet();

  @override
  ConsumerState<_PasskeySheet> createState() => _PasskeySheetState();
}

class _PasskeySheetState extends ConsumerState<_PasskeySheet> {
  bool? _waitlist;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final all = await SettingsService.getAll();
      if (!mounted) return;
      final v = all['passkey_waitlist'];
      setState(() => _waitlist = v == true || v == 1 || v == '1');
    } catch (_) {
      if (mounted) setState(() => _waitlist = false);
    }
  }

  Future<void> _toggle(bool value) async {
    setState(() {
      _waitlist = value;
      _saving = true;
    });
    try {
      await SettingsService.setKey('passkey_waitlist', value);
    } catch (_) {
      if (mounted) {
        setState(() => _waitlist = !value);
        Helpers.showErrorToast(tr(
            ref.read(localeProvider), 'settings.save_failed'));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    String t(String k) => tr(locale, k);
    final p = context.palette;

    return Container(
      decoration: _sheetBox(context),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _handle(context),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: p.primarySoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.key_outlined,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    t('sec.pk_title'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: p.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              t('sec.pk_body'),
              style: TextStyle(
                fontSize: 14,
                height: 1.55,
                color: p.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _waitlist == true
                        ? t('sec.pk_on')
                        : t('sec.pk_notify'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: p.textPrimary,
                    ),
                  ),
                ),
                if (_waitlist == null)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child:
                        CircularProgressIndicator(strokeWidth: 2.5),
                  )
                else
                  Switch(
                    value: _waitlist!,
                    activeThumbColor: AppColors.primary,
                    onChanged: _saving ? null : _toggle,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
