// lib/presentation/screens/profile/seller/edit_profile_screen.dart
// Edit business details mapped to Laravel SellerProfile fields, including
// verification documents. Saves via POST /api/v1/seller/onboarding
// (create-or-update). Verification *status* lives on the Seller Status
// screen — this screen never shows or edits status.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:sitedrop_core/app/routes/route_names.dart';
import 'package:sitedrop_core/app/theme/colors.dart';
import 'package:sitedrop_core/app/theme/input_styles.dart';
import 'package:sitedrop_core/core/utils/formatters.dart';
import 'package:sitedrop_core/core/utils/helpers.dart';
import 'package:sitedrop_core/data/models/seller_profile.dart';
import 'package:sitedrop_core/data/models/service_area.dart';
import 'package:sitedrop_core/maps/app_map_point.dart';
import '../../../providers/seller_profile_provider.dart';
import '../../../widgets/common/app_back_button.dart';
import '../../../widgets/common/loading_widget.dart';
import '../../../widgets/maps/app_osm_map.dart';

/// Edits `App\Models\SellerProfile` fields:
/// business_name, business_type, registration, tax_id, phones, website,
/// description, service_areas, delivery radius, bank details, business_hours.
class SellerEditProfileScreen extends ConsumerStatefulWidget {
  const SellerEditProfileScreen({super.key});

  @override
  ConsumerState<SellerEditProfileScreen> createState() =>
      _SellerEditProfileScreenState();
}

class _SellerEditProfileScreenState
    extends ConsumerState<SellerEditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _registrationController = TextEditingController();
  final _taxIdController = TextEditingController();
  final _businessPhoneController = TextEditingController();
  final _businessEmailController = TextEditingController();
  final _websiteController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _deliveryRadiusController = TextEditingController();
  final _minimumOrderController = TextEditingController();
  final _businessHoursController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _bankBranchController = TextEditingController();
  final _bankAccountNameController = TextEditingController();
  final _bankAccountNumberController = TextEditingController();
  final _facebookController = TextEditingController();
  final _instagramController = TextEditingController();

  SellerBusinessType _businessType = SellerBusinessType.supplier;
  List<ServiceArea> _areas = [];
  bool _initialized = false;
  bool _saving = false;
  bool _uploadingDoc = false;

  static const _verificationDocTypes = [
    'registration',
    'license',
    'insurance',
    'identification',
    'other',
  ];

  @override
  void dispose() {
    _businessNameController.dispose();
    _registrationController.dispose();
    _taxIdController.dispose();
    _businessPhoneController.dispose();
    _businessEmailController.dispose();
    _websiteController.dispose();
    _descriptionController.dispose();
    _deliveryRadiusController.dispose();
    _minimumOrderController.dispose();
    _businessHoursController.dispose();
    _bankNameController.dispose();
    _bankBranchController.dispose();
    _bankAccountNameController.dispose();
    _bankAccountNumberController.dispose();
    _facebookController.dispose();
    _instagramController.dispose();
    super.dispose();
  }

  void _prefill(SellerProfileModel profile) {
    if (_initialized) {
      return;
    }
    _initialized = true;
    _businessNameController.text = profile.businessName;
    _businessType = profile.businessType;
    _registrationController.text = profile.businessRegistrationNumber ?? '';
    _taxIdController.text = profile.taxId ?? '';
    _businessPhoneController.text = profile.businessPhone ?? '';
    _businessEmailController.text = profile.businessEmail ?? '';
    _websiteController.text = profile.website ?? '';
    _descriptionController.text = profile.description ?? '';
    _areas = List<ServiceArea>.from(profile.serviceAreas);
    _deliveryRadiusController.text = profile.deliveryRadiusKm > 0
        ? profile.deliveryRadiusKm.toString()
        : '';
    _minimumOrderController.text = profile.minimumOrderAmount > 0
        ? profile.minimumOrderAmount.toString()
        : '';
    _businessHoursController.text =
        profile.businessHours?['notes']?.toString() ?? '';
    _bankNameController.text = profile.bankName ?? '';
    _bankBranchController.text = profile.bankBranch ?? '';
    _bankAccountNameController.text = profile.bankAccountName ?? '';
    _bankAccountNumberController.text = profile.bankAccountNumber ?? '';
    _facebookController.text = profile.socialLinks['facebook'] ?? '';
    _instagramController.text = profile.socialLinks['instagram'] ?? '';
  }

  Future<void> _uploadVerificationDoc() async {
    final picker = ImagePicker();
    final picked = await picker.pickMedia();
    if (picked == null || !mounted) {
      return;
    }
    final docType = await _pickDocType();
    if (docType == null || !mounted) {
      return;
    }
    setState(() => _uploadingDoc = true);
    try {
      final bytes = kIsWeb ? await picked.readAsBytes() : null;
      await ref
          .read(sellerProfileProvider.notifier)
          .uploadVerificationDocument(
            filePath: picked.path,
            documentType: docType,
            fileName: picked.name,
            fileBytes: bytes,
          );
      if (mounted) {
        final count =
            ref.read(sellerProfileProvider).value?.profile?.verificationEntries.length ??
            0;
        debugPrint('[SellerEditProfile] after upload: $count doc(s)');
        Helpers.showSuccessToast('Document uploaded');
      }
    } catch (e) {
      if (mounted) {
        Helpers.showErrorToast(Helpers.errorMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() => _uploadingDoc = false);
      }
    }
  }

  Future<String?> _pickDocType() {
    String selected = _verificationDocTypes.first;
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Document Type'),
        content: StatefulBuilder(
          builder: (ctx, setDialogState) => DropdownButtonFormField<String>(
            initialValue: selected,
            decoration: InputStyles.decoration(ctx, labelText: 'Type'),
            items: _verificationDocTypes
                .map(
                  (t) => DropdownMenuItem(
                    value: t,
                    child: Text(_docTypeLabel(t)),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v != null) {
                setDialogState(() => selected = v);
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, selected),
            child: const Text('Upload'),
          ),
        ],
      ),
    );
  }

  String _docTypeLabel(String type) {
    switch (type) {
      case 'registration':
        return 'Registration';
      case 'license':
        return 'License';
      case 'insurance':
        return 'Insurance';
      case 'identification':
        return 'Identification';
      default:
        return 'Other';
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    try {
      final socialLinks = <String, String>{};
      if (_facebookController.text.trim().isNotEmpty) {
        socialLinks['facebook'] = _facebookController.text.trim();
      }
      if (_instagramController.text.trim().isNotEmpty) {
        socialLinks['instagram'] = _instagramController.text.trim();
      }

      await ref
          .read(sellerProfileProvider.notifier)
          .save(
            businessName: _businessNameController.text.trim(),
            businessType: _businessType,
            businessRegistrationNumber:
                _registrationController.text.trim().isEmpty
                ? null
                : _registrationController.text.trim(),
            taxId: _taxIdController.text.trim().isEmpty
                ? null
                : _taxIdController.text.trim(),
            businessPhone: _businessPhoneController.text.trim(),
            businessEmail: _businessEmailController.text.trim(),
            website: _websiteController.text.trim().isEmpty
                ? null
                : _websiteController.text.trim(),
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            serviceAreas: List<ServiceArea>.from(_areas),
            deliveryRadiusKm:
                _deliveryRadiusController.text.trim().isEmpty
                ? null
                : double.tryParse(_deliveryRadiusController.text.trim()),
            minimumOrderAmount:
                _minimumOrderController.text.trim().isEmpty
                ? null
                : double.tryParse(_minimumOrderController.text.trim()),
            bankAccountName: _bankAccountNameController.text.trim(),
            bankAccountNumber: _bankAccountNumberController.text.trim(),
            bankName: _bankNameController.text.trim(),
            bankBranch: _bankBranchController.text.trim().isEmpty
                ? null
                : _bankBranchController.text.trim(),
            socialLinks: socialLinks.isEmpty ? null : socialLinks,
            businessHours: _businessHoursController.text.trim().isEmpty
                ? null
                : {'notes': _businessHoursController.text.trim()},
          );
      if (mounted) {
        Helpers.showSuccessToast('Business profile saved');
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        Helpers.showErrorToast(Helpers.errorMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final onboardingAsync = ref.watch(sellerProfileProvider);

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.surface,
        elevation: 0,
        title: appBarTitle(context, 'Edit Business Profile'),
        leading: const AppBackButton(
          fallbackRoute: RouteNames.home,
          fallbackTabIndex: 4,
        ),
      ),
      body: onboardingAsync.when(
        loading: () => const LoadingWidget(message: 'Loading profile…'),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Could not load profile: ${Helpers.errorMessage(e)}',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () =>
                      ref.read(sellerProfileProvider.notifier).refresh(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (onboarding) {
          if (onboarding.profile != null) {
            _prefill(onboarding.profile!);
          }
          final docsCount =
              onboarding.profile?.verificationEntries.length ?? 0;
          debugPrint('[SellerEditProfile] fetched: $docsCount doc(s)');
          return _saving
              ? const LoadingWidget(message: 'Saving…')
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _sectionHeader(context, 'Business'),
                      _buildTextField(
                        controller: _businessNameController,
                        label: 'Business Name *',
                        hint: 'e.g., Accra Building Supplies',
                        validator: (v) =>
                            v?.trim().isEmpty == true ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      _buildBusinessTypeDropdown(),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _registrationController,
                        label: 'Registration Number',
                        hint: 'CAC / Registrar General number',
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _taxIdController,
                        label: 'Tax ID',
                        hint: 'TIN / VAT number',
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _businessPhoneController,
                        label: 'Business Phone *',
                        hint: '024 123 4567',
                        keyboardType: TextInputType.phone,
                        validator: (v) =>
                            v?.trim().isEmpty == true ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _businessEmailController,
                        label: 'Business Email *',
                        hint: 'info@business.com',
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v?.trim().isEmpty == true) {
                            return 'Required';
                          }
                          final email = v!.trim();
                          if (!email.contains('@') ||
                              !email.contains('.')) {
                            return 'Enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _websiteController,
                        label: 'Website',
                        hint: 'https://example.com',
                        keyboardType: TextInputType.url,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _descriptionController,
                        label: 'Description',
                        hint: 'What does your business supply?',
                        maxLines: 3,
                      ),
                      const SizedBox(height: 24),
                      _sectionHeader(context, 'Operations'),
                      _buildCoverageAreas(),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _deliveryRadiusController,
                              label: 'Delivery Radius (km)',
                              hint: '50',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: _minimumOrderController,
                              label: 'Min Order (GHS)',
                              hint: '0',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _businessHoursController,
                        label: 'Business Hours',
                        hint: 'Mon–Fri 8:00–17:00',
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _facebookController,
                        label: 'Facebook URL',
                        hint: 'https://facebook.com/…',
                        keyboardType: TextInputType.url,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _instagramController,
                        label: 'Instagram URL',
                        hint: 'https://instagram.com/…',
                        keyboardType: TextInputType.url,
                      ),
                      const SizedBox(height: 24),
                      _sectionHeader(context, 'Banking'),
                      _buildTextField(
                        controller: _bankNameController,
                        label: 'Bank Name *',
                        hint: 'e.g., GCB Bank',
                        validator: (v) =>
                            v?.trim().isEmpty == true ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _bankBranchController,
                        label: 'Branch',
                        hint: 'e.g., Accra High Street',
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _bankAccountNameController,
                        label: 'Account Name *',
                        hint: 'Account holder name',
                        validator: (v) =>
                            v?.trim().isEmpty == true ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _bankAccountNumberController,
                        label: 'Account Number *',
                        hint: '0123456789',
                        keyboardType: TextInputType.number,
                        validator: (v) =>
                            v?.trim().isEmpty == true ? 'Required' : null,
                      ),
                      const SizedBox(height: 24),
                      _sectionHeader(
                        context,
                        'Verification Documents ($docsCount)',
                      ),
                      Text(
                        'Upload registration, license, insurance or ID '
                        '(PDF, JPG, PNG up to 5MB). Required for approval — '
                        'your review status lives under Seller Status.',
                        style: TextStyle(fontSize: 12, color: p.textMuted),
                      ),
                      const SizedBox(height: 12),
                      _buildDocsList(onboarding.profile),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed:
                              _uploadingDoc ? null : _uploadVerificationDoc,
                          icon: _uploadingDoc
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.upload_file_outlined),
                          label: Text(
                            _uploadingDoc
                                ? 'Uploading…'
                                : 'Upload Document',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _saving ? null : _save,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
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
                              : const Text(
                                  'Save Business Profile',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                );
        },
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Text(title, style: InputStyles.section(context)),
    );
  }

  Widget _buildBusinessTypeDropdown() {
    return DropdownButtonFormField<SellerBusinessType>(
      initialValue: _businessType,
      style: InputStyles.text(context),
      decoration: InputStyles.decoration(context, labelText: 'Business Type *'),
      items: SellerBusinessType.values
          .map(
            (t) => DropdownMenuItem(value: t, child: Text(t.displayName)),
          )
          .toList(),
      onChanged: (v) {
        if (v != null) {
          setState(() => _businessType = v);
        }
      },
    );
  }

  Widget _buildDocsList(SellerProfileModel? profile) {
    final p = context.palette;
    final docs = profile?.verificationEntries ?? [];
    if (docs.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: p.divider),
        ),
        child: Text(
          'No documents uploaded yet.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: p.textMuted),
        ),
      );
    }
    return Column(
      children: [
        for (final doc in docs)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: p.divider),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.insert_drive_file_outlined,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc.fileName.isEmpty ? 'Document' : doc.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        [
                          doc.displayType,
                          if (doc.uploadedAt != null)
                            Formatters.formatDate(doc.uploadedAt!),
                        ].join(' · '),
                        style: TextStyle(fontSize: 11, color: p.textMuted),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.verified_outlined,
                  size: 18,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCoverageAreas() {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Coverage Areas',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: p.textPrimary,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_areas.length} pinned',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Pin the towns and zones your trucks deliver to. Nearby delivery '
          'matching uses these pins — e.g. Kumasi buyers match Kumasi '
          'suppliers instead of Accra ones.',
          style: TextStyle(fontSize: 12, color: p.textMuted),
        ),
        const SizedBox(height: 12),
        if (_areas.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: p.divider),
            ),
            child: Text(
              'No coverage areas yet. Pin your first area below.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: p.textMuted),
            ),
          )
        else
          for (int i = 0; i < _areas.length; i++)
            _buildAreaCard(_areas[i], i),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _openAreaPicker(),
            icon: const Icon(Icons.add_location_alt_outlined),
            label: const Text('Pin coverage area'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAreaCard(ServiceArea area, int index) {
    final p = context.palette;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.location_pin,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  area.displayLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '± ${area.radiusKm.toStringAsFixed(area.radiusKm.truncateToDouble() == area.radiusKm ? 0 : 1)} km delivery zone',
                  style: TextStyle(fontSize: 11, color: p.textMuted),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Edit area',
            onPressed: () => _openAreaPicker(initial: area, index: index),
            icon: Icon(Icons.edit_outlined, size: 18, color: p.iconMuted),
          ),
          IconButton(
            tooltip: 'Remove area',
            onPressed: () => setState(() => _areas.removeAt(index)),
            icon: Icon(Icons.close, size: 18, color: p.iconMuted),
          ),
        ],
      ),
    );
  }

  Future<void> _openAreaPicker({ServiceArea? initial, int? index}) async {
    final result = await showModalBottomSheet<ServiceArea>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AreaPickerSheet(
        initial: initial,
        existing: List<ServiceArea>.from(_areas),
      ),
    );
    if (result == null || !mounted) {
      return;
    }
    setState(() {
      if (index != null && index >= 0 && index < _areas.length) {
        _areas[index] = result;
      } else {
        _areas.add(result);
      }
    });
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: InputStyles.text(context),
      decoration: InputStyles.decoration(
        context,
        labelText: label,
        hintText: hint,
      ),
      validator: validator,
    );
  }
}

/// Bottom-sheet map picker for one coverage area: tap the OSM map to drop a
/// pin, name it, set the delivery radius, and confirm. Returns the picked
/// [ServiceArea] (null when dismissed).
class _AreaPickerSheet extends StatefulWidget {
  final ServiceArea? initial;
  final List<ServiceArea> existing;

  const _AreaPickerSheet({this.initial, this.existing = const []});

  @override
  State<_AreaPickerSheet> createState() => _AreaPickerSheetState();
}

class _AreaPickerSheetState extends State<_AreaPickerSheet> {
  final _labelController = TextEditingController();
  final _mapController = AppMapController();
  AppMapPoint? _pin;
  double _radiusKm = 25;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _pin = widget.initial?.point;
    _labelController.text = widget.initial?.label ?? '';
    _radiusKm = widget.initial?.radiusKm ?? 25;
  }

  @override
  void dispose() {
    _labelController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  AppMapPoint get _focus {
    if (_pin != null) {
      return _pin!;
    }
    if (widget.existing.isNotEmpty) {
      return widget.existing.first.point;
    }
    return AppMapPoint.accra;
  }

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          Helpers.showErrorToast('Location permission denied');
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      final point = AppMapPoint(pos.latitude, pos.longitude);
      if (!mounted) {
        return;
      }
      setState(() => _pin = point);
      _mapController.moveTo(point, 13);
    } catch (e) {
      if (mounted) {
        Helpers.showErrorToast('Could not get location');
      }
    } finally {
      if (mounted) {
        setState(() => _locating = false);
      }
    }
  }

  void _confirm() {
    final pin = _pin;
    if (pin == null) {
      Helpers.showErrorToast('Tap the map to drop a pin first');
      return;
    }
    Navigator.of(context).pop(
      ServiceArea(
        point: pin,
        label: _labelController.text.trim(),
        radiusKm: _radiusKm,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final markers = <AppMapMarker>{
      for (final area in widget.existing)
        AppMapMarker(
          id: 'area-${area.point.latitude},${area.point.longitude}',
          point: area.point,
        ),
      if (_pin != null)
        AppMapMarker(id: 'draft-pin', point: _pin!, kind: AppMarkerKind.driver),
    };
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.88,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: p.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.initial == null
                        ? 'Pin coverage area'
                        : 'Edit coverage area',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: p.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Tap the map to drop a pin where your trucks deliver.',
              style: TextStyle(fontSize: 12, color: p.textMuted),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AppOsmMap(
                  controller: _mapController,
                  initialCameraPosition: AppCameraPosition(
                    target: _focus,
                    zoom: 10,
                  ),
                  markers: markers,
                  onTap: (point) => setState(() => _pin = point),
                ),
              ),
            ),
          ),
          if (_pin != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                'Pinned: ${_pin!.label}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextFormField(
              controller: _labelController,
              style: InputStyles.text(context),
              decoration: InputStyles.decoration(
                context,
                labelText: 'Area name (e.g. Kumasi)',
                hintText: 'Town or zone name',
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Delivery radius: ${_radiusKm.toStringAsFixed(_radiusKm.truncateToDouble() == _radiusKm ? 0 : 1)} km',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: p.textPrimary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Slider(
                    value: _radiusKm,
                    min: 5,
                    max: 200,
                    divisions: 39,
                    label: '${_radiusKm.toStringAsFixed(0)} km',
                    activeColor: AppColors.primary,
                    onChanged: (v) => setState(() => _radiusKm = v),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _locating ? null : _useMyLocation,
                    icon: _locating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location, size: 18),
                    label: const Text('My location'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _confirm,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Save area',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

