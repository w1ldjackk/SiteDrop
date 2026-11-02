// lib/presentation/screens/site/add_staff_screen.dart
// Add/Edit staff for a site.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sitedrop_core/app/routes/route_names.dart';
import 'package:sitedrop_core/app/theme/colors.dart';
import 'package:sitedrop_core/app/theme/input_styles.dart';
import 'package:sitedrop_core/core/utils/helpers.dart';
import 'package:sitedrop_core/core/utils/display_names.dart';
import 'package:sitedrop_core/data/models/site_staff.dart';
import 'package:sitedrop_core/data/services/site_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/app_back_button.dart';
import '../../widgets/common/loading_widget.dart';

class AddStaffScreen extends ConsumerStatefulWidget {
  final String siteId;
  final SiteStaffModel? staff;

  const AddStaffScreen({super.key, required this.siteId, this.staff});

  @override
  ConsumerState<AddStaffScreen> createState() => _AddStaffScreenState();
}

class _AddStaffScreenState extends ConsumerState<AddStaffScreen> {
  final _formKey = GlobalKey<FormState>();
  final _positionController = TextEditingController();
  final _departmentController = TextEditingController();
  final _notesController = TextEditingController();
  final _certificationsController = TextEditingController();
  final _skillsController = TextEditingController();
  final _performanceController = TextEditingController();

  StaffRole _selectedRole = StaffRole.laborer;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  bool _isActive = true;
  bool _loading = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.staff != null;
    if (_isEditing) {
      final s = widget.staff!;
      _positionController.text = s.position;
      _departmentController.text = s.department ?? '';
      _notesController.text = s.notes ?? '';
      _certificationsController.text = s.certifications.join(', ');
      _skillsController.text = s.skills.join(', ');
      _performanceController.text = s.performanceRating?.toString() ?? '';
      _selectedRole = s.role;
      _startDate = s.startDate;
      _endDate = s.endDate;
      _isActive = s.isActive;
    }
  }

  @override
  void dispose() {
    _positionController.dispose();
    _departmentController.dispose();
    _notesController.dispose();
    _certificationsController.dispose();
    _skillsController.dispose();
    _performanceController.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final date = await showDatePicker(context: context, initialDate: _startDate, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365)));
    if (date != null && mounted) setState(() => _startDate = date);
  }

  Future<void> _pickEndDate() async {
    final date = await showDatePicker(context: context, initialDate: _endDate ?? DateTime.now().add(const Duration(days: 30)), firstDate: _startDate, lastDate: DateTime.now().add(const Duration(days: 365 * 5)));
    if (date != null && mounted) setState(() => _endDate = date);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      if (_isEditing) {
        await SiteService.updateStaff(
          widget.siteId,
          widget.staff!.id,
          role: _selectedRole,
          position: _positionController.text.trim(),
          startDate: _startDate,
          endDate: _endDate,
          department: _departmentController.text.trim().isEmpty ? null : _departmentController.text.trim(),
          isActive: _isActive,
          certifications: _certificationsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
          skills: _skillsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
          performanceRating: _performanceController.text.isEmpty ? null : double.tryParse(_performanceController.text),
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        );
      } else {
        final authState = ref.read(authProvider).value;
        final currentUserId = authState is AuthAuthenticated
            ? authState.user.id
            : null;
        if (currentUserId == null || currentUserId.isEmpty) {
          if (mounted) {
            Helpers.showErrorToast('Please sign in to add staff');
          }
          return;
        }
        await SiteService.addStaff(
          widget.siteId,
          userId: currentUserId,
          role: _selectedRole,
          position: _positionController.text.trim(),
          startDate: _startDate,
          endDate: _endDate,
          department: _departmentController.text.trim().isEmpty ? null : _departmentController.text.trim(),
          certifications: _certificationsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
          skills: _skillsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        );
      }

      if (mounted) {
        Helpers.showSuccessToast(_isEditing ? 'Staff updated' : 'Staff added');
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
        title: appBarTitle(context, _isEditing ? 'Edit Staff' : 'Add Staff'),
        leading: const AppBackButton(fallbackRoute: RouteNames.sitesManagement),
      ),
      body: _loading
          ? const LoadingWidget(message: 'Saving…')
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _sectionHeader(context, 'Staff Information'),
                  _buildDropdown(
                    label: 'Role *',
                    value: _selectedRole,
                    items: StaffRole.values,
                    onChanged: (v) => setState(() => _selectedRole = v!),
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _positionController,
                    label: 'Position *',
                    hint: 'e.g., Senior Foreman',
                    validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _departmentController,
                    label: 'Department',
                    hint: 'e.g., Earthworks',
                  ),
                  const SizedBox(height: 24),

                  _sectionHeader(context, 'Schedule'),
                  _buildTextField(
                    controller: TextEditingController(text: '${_startDate.day}/${_startDate.month}/${_startDate.year}'),
                    label: 'Start Date *',
                    hint: 'Select date',
                    readOnly: true,
                    onTap: _pickStartDate,
                    suffixIcon: const Icon(Icons.calendar_today),
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: TextEditingController(text: _endDate != null ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}' : ''),
                    label: 'End Date (optional)',
                    hint: 'Select date',
                    readOnly: true,
                    onTap: _pickEndDate,
                    suffixIcon: const Icon(Icons.calendar_today),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: Text('Active', style: TextStyle(fontWeight: FontWeight.w600, color: p.textPrimary)),
                    subtitle: Text('Staff is currently working on this site', style: TextStyle(fontSize: 12, color: p.textMuted)),
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v),
                    activeThumbColor: AppColors.success,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 24),

                  _sectionHeader(context, 'Qualifications'),
                  _buildTextField(
                    controller: _certificationsController,
                    label: 'Certifications (comma-separated)',
                    hint: 'OSHA 30, First Aid, Crane Operator',
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _skillsController,
                    label: 'Skills (comma-separated)',
                    hint: 'Excavation, Concrete, Surveying',
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _performanceController,
                    label: 'Performance Rating (1-5)',
                    hint: '4.5',
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
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
                          : Text(_isEditing ? 'Update Staff' : 'Add Staff', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
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