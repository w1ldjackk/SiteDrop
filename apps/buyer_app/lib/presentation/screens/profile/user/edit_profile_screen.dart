// lib/presentation/screens/profile/user/edit_profile_screen.dart
// Modern edit profile: avatar header + completion ring, grouped sections,
// prefill from GET /profile, working PUT save, discard-changes guard.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:sitedrop_core/app/routes/route_names.dart';
import 'package:sitedrop_core/app/theme/colors.dart';
import 'package:sitedrop_core/app/theme/input_styles.dart';
import 'package:sitedrop_core/core/utils/helpers.dart';
import 'package:sitedrop_core/core/utils/image_picker_helper.dart';
import 'package:sitedrop_core/core/utils/validators.dart';
import 'package:sitedrop_core/data/services/auth_service.dart';
import 'package:sitedrop_core/data/services/profile_service.dart';
import '../../../../core/i18n/app_strings.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/locale_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../widgets/common/app_back_button.dart';
import '../../../widgets/common/loading_widget.dart';

const _profileFields = [
  'first_name',
  'last_name',
  'date_of_birth',
  'gender',
  'bio',
  'nationality',
  'occupation',
  'company',
  'alternate_phone',
  'address',
  'emergency_contact_name',
  'emergency_contact_phone',
];

const _genders = ['male', 'female', 'other', 'prefer_not_to_say'];

class UserEditProfileScreen extends ConsumerStatefulWidget {
  const UserEditProfileScreen({super.key});

  @override
  ConsumerState<UserEditProfileScreen> createState() =>
      _UserEditProfileScreenState();
}

class _UserEditProfileScreenState
    extends ConsumerState<UserEditProfileScreen> {
  final _formKey = GlobalKey<FormBuilderState>();
  File? _avatarFile;
  bool _uploadingAvatar = false;
  bool _saving = false;
  bool _loaded = false;
  bool _exitAllowed = false;
  Map<String, dynamic> _initial = const {};

  Future<void> _pickAvatar(ImageSource source) async {
    final file = await ImagePickerHelper.pickAndCropAvatar(source: source);
    if (file == null || !mounted) return;
    setState(() {
      _avatarFile = file;
      _uploadingAvatar = true;
    });
    try {
      await AuthService.uploadAvatar(file.path);
      String t(String k) => tr(ref.read(localeProvider), k);
      if (!mounted) return;
      Helpers.showSuccessToast(t('profile.saved'));
      ref.invalidate(userProfileProvider);
      await ref.read(authProvider.notifier).checkAuth();
    } catch (e) {
      if (mounted) Helpers.showErrorToast(e);
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  void _showAvatarSourceSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: context.palette.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.palette.borderStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAvatar(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take a photo'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAvatar(ImageSource.camera);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _snapshot(
    Map<String, dynamic> user,
    Map<String, dynamic> profile,
  ) {
    String str(dynamic v) => (v ?? '').toString();
    // Dropdowns assert when the value isn't null AND isn't in items —
    // so empty gender MUST be null, not ''.
    final gender = str(profile['gender']);
    // FormBuilderDateTimePicker expects DateTime? — never a String.
    // A String here throws: type 'String' is not a subtype of 'DateTime?'.
    DateTime? dob;
    final rawDob = profile['date_of_birth'];
    if (rawDob is DateTime) {
      dob = rawDob;
    } else if (rawDob != null &&
        rawDob.toString().trim().isNotEmpty) {
      dob = DateTime.tryParse(rawDob.toString().trim());
    }
    return {
      'name': str(user['name']),
      'first_name': str(profile['first_name']),
      'last_name': str(profile['last_name']),
      'date_of_birth': dob,
      'gender': _genders.contains(gender) ? gender : null,
      'bio': str(profile['bio']),
      'nationality': str(profile['nationality']),
      'occupation': str(profile['occupation']),
      'company': str(profile['company']),
      'alternate_phone': str(profile['alternate_phone']),
      'address': str(profile['address']),
      'emergency_contact_name':
          str(profile['emergency_contact_name']),
      'emergency_contact_phone':
          str(profile['emergency_contact_phone']),
      'emergency_contact_relationship':
          str(profile['emergency_contact_relationship']),
    };
  }

  double _completion(Map<String, dynamic> values) {
    var filled = 0;
    for (final k in _profileFields) {
      if ((values[k] ?? '').toString().trim().isNotEmpty) filled++;
    }
    return filled / _profileFields.length;
  }

  String _norm(dynamic v) {
    if (v is DateTime) return DateFormat('yyyy-MM-dd').format(v);
    return (v ?? '').toString().trim();
  }

  bool _isDirty() {
    final current = _formKey.currentState?.instantValue ?? {};
    for (final k in _initial.keys) {
      if (_norm(current[k]) != _norm(_initial[k])) {
        return true;
      }
    }
    return false;
  }

  Future<bool> _requestExit() async {
    if (!_isDirty()) return true;
    String t(String k) => tr(ref.read(localeProvider), k);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('profile.discard_title')),
        content: Text(t('profile.discard_msg')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t('profile.discard_keep')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: Text(t('profile.discard_yes')),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _exit() async {
    if (!await _requestExit()) return;
    if (!mounted) return;
    setState(() => _exitAllowed = true);
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      context.go(RouteNames.home);
    }
  }

  Future<void> _save() async {
    final form = _formKey.currentState;
    if (form == null || !form.saveAndValidate()) return;
    String t(String k) => tr(ref.read(localeProvider), k);
    setState(() => _saving = true);
    try {
      final v = Map<String, dynamic>.from(form.value);
      // Normalize: dob DateTime → yyyy-MM-dd, gender empty → omit.
      final dob = v['date_of_birth'];
      if (dob is DateTime) {
        v['date_of_birth'] = DateFormat('yyyy-MM-dd').format(dob);
      }
      if ((v['gender'] ?? '').toString().isEmpty) {
        v.remove('gender');
      }
      await ProfileService.updateDetails(v);
      if (!mounted) return;
      Helpers.showSuccessToast(t('profile.saved'));
      ref.invalidate(userProfileProvider);
      await ref.read(authProvider.notifier).checkAuth();
      if (mounted) {
        setState(() {
          final next = Map<String, dynamic>.from(v.map(
            (k, val) => MapEntry(k, val?.toString() ?? ''),
          ));
          // Keep dob as DateTime? so FormBuilderDateTimePicker never
          // receives a String on rebuild.
          final savedDobStr = v['date_of_birth']?.toString() ?? '';
          next['date_of_birth'] = savedDobStr.trim().isEmpty
              ? null
              : DateTime.tryParse(savedDobStr.trim());
          _initial = next;
          _loaded = true;
        });
      }
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
    final profileAsync = ref.watch(userProfileProvider);
    final authState = ref.watch(authProvider);
    final authUser =
        authState is AsyncData && authState.value is AuthAuthenticated
            ? (authState.value as AuthAuthenticated).user
            : null;

    return PopScope(
      canPop: _exitAllowed || !_isDirty(),
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _exitAllowed) return;
        await _exit();
      },
      child: Scaffold(
        backgroundColor: p.background,
        appBar: AppBar(
          backgroundColor: p.surface,
          elevation: 0,
          title: appBarTitle(context, t('profile.title')),
          leading: AppBackButton(
            fallbackRoute: RouteNames.home,
            fallbackTabIndex: 4,
            onPressed: _exit,
          ),
        ),
        body: profileAsync.when(
          data: (data) {
            final user = data.user.isNotEmpty
                ? data.user
                : {
                    'name': authUser?.name ?? '',
                    'email': authUser?.email ?? '',
                    'phone': authUser?.phone ?? '',
                  };
            if (!_loaded) {
              _initial = _snapshot(user, data.profile);
              // Seed after first frame so FormBuilder picks it up.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _loaded = true);
              });
            }
            if (!_loaded) {
              return const LoadingWidget(
                message: 'Loading profile…',
              );
            }
            final pct = _completion({
              ..._initial,
              ...(_formKey.currentState?.instantValue ?? {}),
            });
            return Column(
              children: [
                Expanded(
                  child: FormBuilder(
                    key: _formKey,
                    initialValue: _initial,
                    onChanged: () => setState(() {
                      _exitAllowed = false;
                    }),
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _headerCard(
                          context,
                          user,
                          pct,
                          authUser?.avatar,
                        ),
                        const SizedBox(height: 16),
                        _sectionCard(context, t('profile.personal'), [
                          _field(context,
                              name: 'name',
                              label: t('profile.f_display'),
                              validators: [
                                FormBuilderValidators.required(
                                  errorText: 'Name is required',
                                ),
                              ]),
                          _row2(context, 'first_name',
                              t('profile.f_first'), 'last_name',
                              t('profile.f_last')),
                          _dobField(context, t),
                          _genderField(context, t),
                          _field(context,
                              name: 'bio',
                              label: t('profile.f_bio'),
                              maxLines: 3),
                          _row2(context, 'nationality',
                              t('profile.f_nationality'), 'occupation',
                              t('profile.f_occupation')),
                          _field(context,
                              name: 'company',
                              label: t('profile.f_company')),
                        ]),
                        const SizedBox(height: 16),
                        _sectionCard(context, t('profile.contact'), [
                          _readOnlyTile(
                            context,
                            icon: Icons.phone_outlined,
                            label: (user['phone'] ?? '').toString(),
                            note: t('profile.phone_ro'),
                          ),
                          _readOnlyTile(
                            context,
                            icon: Icons.email_outlined,
                            label: (user['email'] ?? '').toString(),
                            note: t('profile.email_ro'),
                          ),
                          _field(context,
                              name: 'alternate_phone',
                              label: t('profile.f_alt_phone'),
                              keyboard: TextInputType.phone,
                              validators: [Validators.optionalPhone]),
                          _field(context,
                              name: 'address',
                              label: t('profile.f_address'),
                              maxLines: 2),
                        ]),
                        const SizedBox(height: 16),
                        _sectionCard(context, t('profile.emergency'), [
                          _field(context,
                              name: 'emergency_contact_name',
                              label: t('profile.f_first')),
                          _field(context,
                              name: 'emergency_contact_phone',
                              label: t('profile.f_alt_phone'),
                              keyboard: TextInputType.phone,
                              validators: [Validators.optionalPhone]),
                          _field(context,
                              name: 'emergency_contact_relationship',
                              label: t('profile.f_em_rel')),
                        ]),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
                _saveBar(context, pct),
              ],
            );
          },
          loading: () =>
              const LoadingWidget(message: 'Loading profile…'),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    Helpers.errorMessage(e),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () =>
                        ref.invalidate(userProfileProvider),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(t('common.retry')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HEADER (avatar + completion ring)
  // ============================================================
  Widget _headerCard(
    BuildContext context,
    Map<String, dynamic> user,
    double pct,
    String? authAvatar,
  ) {
    final locale = ref.watch(localeProvider);
    String t(String k) => tr(locale, k);
    final p = context.palette;
    final name = (user['name'] ?? '').toString();
    final email = (user['email'] ?? '').toString();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: AppColors.primary,
                backgroundImage: _avatarFile != null
                    ? FileImage(_avatarFile!)
                    : (authAvatar != null && authAvatar.isNotEmpty
                        ? NetworkImage(authAvatar) as ImageProvider
                        : null),
                child: _uploadingAvatar
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : ((_avatarFile == null &&
                                (authAvatar == null ||
                                    authAvatar.isEmpty))
                        ? Text(
                            name.isNotEmpty
                                ? name[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              fontSize: 26,
                              color: p.textOnPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Material(
                  color: AppColors.primary,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _uploadingAvatar
                        ? null
                        : _showAvatarSourceSheet,
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(
                        Icons.camera_alt,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isNotEmpty ? name : '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: p.textPrimary,
                  ),
                ),
                if (email.isNotEmpty)
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: p.textMuted,
                    ),
                  ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    SizedBox(
                      width: 110,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 6,
                          backgroundColor: p.surfaceMuted,
                          valueColor:
                              const AlwaysStoppedAnimation(
                            AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(pct * 100).round()}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: p.textSecondary,
                      ),
                    ),
                  ],
                ),
                Text(
                  t('profile.completion'),
                  style: TextStyle(
                    fontSize: 11,
                    color: p.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SECTIONS / FIELDS
  // ============================================================
  Widget _sectionCard(
    BuildContext context,
    String title,
    List<Widget> children,
  ) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: p.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _field(
    BuildContext context, {
    required String name,
    required String label,
    TextInputType? keyboard,
    int maxLines = 1,
    List<FormFieldValidator<String>> validators = const [],
  }) {
    return FormBuilderTextField(
      name: name,
      style: InputStyles.text(context),
      keyboardType: keyboard,
      maxLines: maxLines,
      decoration: InputStyles.decoration(context, labelText: label),
      validator: validators.isEmpty
          ? null
          : FormBuilderValidators.compose(validators),
    );
  }

  Widget _row2(
    BuildContext context,
    String nameA,
    String labelA,
    String nameB,
    String labelB,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _field(context, name: nameA, label: labelA),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _field(context, name: nameB, label: labelB),
        ),
      ],
    );
  }

  Widget _dobField(
    BuildContext context,
    String Function(String) t,
  ) {
    final raw = _initial['date_of_birth'];
    DateTime? initial;
    if (raw is DateTime) {
      initial = raw;
    } else if (raw != null && raw.toString().trim().isNotEmpty) {
      initial = DateTime.tryParse(raw.toString().trim());
    }
    return FormBuilderDateTimePicker(
      name: 'date_of_birth',
      initialValue: initial,
      style: InputStyles.text(context),
      decoration: InputStyles.decoration(
        context,
        labelText: t('profile.f_dob'),
      ),
      inputType: InputType.date,
      format: DateFormat('yyyy-MM-dd'),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
  }

  Widget _genderField(
    BuildContext context,
    String Function(String) t,
  ) {
    final labels = {
      'male': t('profile.g_male'),
      'female': t('profile.g_female'),
      'other': t('profile.g_other'),
      'prefer_not_to_say': t('profile.g_prefer'),
    };
    return FormBuilderDropdown<String>(
      name: 'gender',
      style: InputStyles.text(context),
      decoration: InputStyles.decoration(
        context,
        labelText: t('profile.f_gender'),
      ),
      items: [
        for (final g in _genders)
          DropdownMenuItem(value: g, child: Text(labels[g]!)),
      ],
    );
  }

  Widget _readOnlyTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String note,
  }) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: p.iconMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.isNotEmpty ? label : '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: p.textSecondary,
                  ),
                ),
                Text(
                  note,
                  style: TextStyle(fontSize: 11, color: p.textMuted),
                ),
              ],
            ),
          ),
          Icon(Icons.lock_outline, size: 14, color: p.iconMuted),
        ],
      ),
    );
  }

  Widget _saveBar(BuildContext context, double pct) {
    final locale = ref.watch(localeProvider);
    String t(String k) => tr(locale, k);
    final p = context.palette;
    final dirty = _isDirty();
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        decoration: BoxDecoration(
          color: p.surface,
          border: Border(top: BorderSide(color: p.divider)),
        ),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (!dirty || _saving) ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor:
                  p.surfaceMuted,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _saving
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    t('profile.save'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
