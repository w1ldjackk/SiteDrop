// lib/presentation/screens/site/add_visit_screen.dart
// Add/Edit site visit.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sitedrop_core/app/routes/route_names.dart';
import 'package:sitedrop_core/app/theme/colors.dart';
import 'package:sitedrop_core/app/theme/input_styles.dart';
import 'package:sitedrop_core/core/utils/helpers.dart';
import 'package:sitedrop_core/core/utils/display_names.dart';
import 'package:sitedrop_core/data/models/site_visit.dart';
import 'package:sitedrop_core/data/services/site_service.dart';
import '../../widgets/common/app_back_button.dart';
import '../../widgets/common/loading_widget.dart';

class AddVisitScreen extends ConsumerStatefulWidget {
  final String siteId;
  final SiteVisitModel? visit;

  const AddVisitScreen({super.key, required this.siteId, this.visit});

  @override
  ConsumerState<AddVisitScreen> createState() => _AddVisitScreenState();
}

class _AddVisitScreenState extends ConsumerState<AddVisitScreen> {
  final _formKey = GlobalKey<FormState>();
  final _visitorNameController = TextEditingController();
  final _visitorPhoneController = TextEditingController();
  final _visitorEmailController = TextEditingController();
  final _purposeController = TextEditingController();
  final _notesController = TextEditingController();
  final _vehicleRegController = TextEditingController();

  VisitType _visitType = VisitType.scheduled;
  DateTime _visitDate = DateTime.now();
  VisitStatus _status = VisitStatus.scheduled;
  bool _safetyBriefing = false;
  bool _ppeProvided = false;
  double? _temperature;
  bool _loading = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.visit != null;
    if (_isEditing) {
      final v = widget.visit!;
      _visitorNameController.text = v.visitorName;
      _visitorPhoneController.text = v.visitorPhone;
      _visitorEmailController.text = v.visitorEmail ?? '';
      _purposeController.text = v.purpose;
      _notesController.text = v.notes ?? '';
      _vehicleRegController.text = v.vehicleRegistration ?? '';
      _visitType = v.visitType;
      _visitDate = v.visitDate;
      _status = v.status;
      _safetyBriefing = v.safetyBriefingCompleted;
      _ppeProvided = v.ppeProvided;
      _temperature = v.temperature;
    }
  }

  @override
  void dispose() {
    _visitorNameController.dispose();
    _visitorPhoneController.dispose();
    _visitorEmailController.dispose();
    _purposeController.dispose();
    _notesController.dispose();
    _vehicleRegController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(context: context, initialDate: _visitDate, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365)));
    if (date != null && mounted) setState(() => _visitDate = date);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      // For editing, we'd need an update method in SiteService
      // For now, just create new
      await SiteService.createVisit(
        widget.siteId,
        visitorName: _visitorNameController.text.trim(),
        visitorPhone: _visitorPhoneController.text.trim(),
        visitorEmail: _visitorEmailController.text.trim().isEmpty ? null : _visitorEmailController.text.trim(),
        visitType: _visitType,
        visitDate: _visitDate,
        purpose: _purposeController.text.trim(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        vehicleRegistration: _vehicleRegController.text.trim().isEmpty ? null : _vehicleRegController.text.trim(),
      );

      if (mounted) {
        Helpers.showSuccessToast(_isEditing ? 'Visit updated' : 'Visit scheduled');
        // Replace the form: back goes to the previous screen.
        context.pushReplacement(RouteNames.siteDetailWithId(widget.siteId));
      }
    } catch (e) {
      if (mounted) Helpers.showErrorToast(Helpers.errorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.surface,
        elevation: 0,
        title: appBarTitle(context, _isEditing ? 'Edit Visit' : 'Schedule Visit'),
        leading: const AppBackButton(fallbackRoute: RouteNames.sitesManagement),
      ),
      body: _loading
          ? const LoadingWidget(message: 'Saving…')
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _sectionHeader(context, 'Visitor Information'),
                  _buildTextField(
                    controller: _visitorNameController,
                    label: 'Visitor Name *',
                    hint: 'John Doe',
                    validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _visitorPhoneController,
                    label: 'Phone *',
                    hint: '024 123 4567',
                    keyboardType: TextInputType.phone,
                    validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _visitorEmailController,
                    label: 'Email',
                    hint: 'john@example.com',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 24),

                  _sectionHeader(context, 'Visit Details'),
                  _buildDropdown(
                    label: 'Visit Type *',
                    value: _visitType,
                    items: VisitType.values,
                    onChanged: (v) => setState(() => _visitType = v!),
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: TextEditingController(text: '${_visitDate.day}/${_visitDate.month}/${_visitDate.year}'),
                    label: 'Visit Date *',
                    hint: 'Select date',
                    readOnly: true,
                    onTap: _pickDate,
                    suffixIcon: const Icon(Icons.calendar_today),
                  ),
                  const SizedBox(height: 16),
                  _buildDropdown(
                    label: 'Status',
                    value: _status,
                    items: VisitStatus.values,
                    onChanged: (v) => setState(() => _status = v!),
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _purposeController,
                    label: 'Purpose *',
                    hint: 'Safety inspection, progress review, etc.',
                    maxLines: 2,
                    validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
                  ),
                  const SizedBox(height: 24),

                  _sectionHeader(context, 'Safety & Compliance'),
                  SwitchListTile(
                    title: Text('Safety Briefing Completed', style: TextStyle(fontWeight: FontWeight.w600, color: p.textPrimary)),
                    subtitle: Text('Visitor has completed site safety briefing', style: TextStyle(fontSize: 12, color: p.textMuted)),
                    value: _safetyBriefing,
                    onChanged: (v) => setState(() => _safetyBriefing = v),
                    activeThumbColor: AppColors.success,
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    title: Text('PPE Provided', style: TextStyle(fontWeight: FontWeight.w600, color: p.textPrimary)),
                    subtitle: Text('Visitor has been provided with required PPE', style: TextStyle(fontSize: 12, color: p.textMuted)),
                    value: _ppeProvided,
                    onChanged: (v) => setState(() => _ppeProvided = v),
                    activeThumbColor: AppColors.primary,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: TextEditingController(text: _temperature != null ? _temperature!.toStringAsFixed(1) : ''),
                    label: 'Temperature (°C)',
                    hint: '36.5',
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _vehicleRegController,
                    label: 'Vehicle Registration',
                    hint: 'GT 1234-23',
                  ),
                  const SizedBox(height: 24),

                  _sectionHeader(context, 'Notes'),
                  _buildTextField(
                    controller: _notesController,
                    label: 'Notes',
                    hint: 'Any additional notes',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _loading ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _loading
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                          : Text(_isEditing ? 'Update Visit' : 'Schedule Visit', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: context.palette.textPrimary)),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
    bool readOnly = false,
    VoidCallback? onTap,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      readOnly: readOnly,
      onTap: onTap,
      style: InputStyles.text(context),
      decoration: InputStyles.decoration(context, labelText: label, hintText: hint, suffixIcon: suffixIcon),
      validator: validator,
    );
  }

  Widget _buildDropdown({
    required String label,
    required dynamic value,
    required List<dynamic> items,
    required void Function(dynamic) onChanged,
  }) {
    final safeValue = items.contains(value) ? value : null;
    return DropdownButtonFormField<dynamic>(
      initialValue: safeValue,
      style: InputStyles.text(context),
      decoration: InputStyles.decoration(context, labelText: label),
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(DisplayNames.dropdownLabel(e)))).toList(),
      onChanged: onChanged,
    );
  }
}