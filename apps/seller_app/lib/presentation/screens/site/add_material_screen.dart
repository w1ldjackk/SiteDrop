// lib/presentation/screens/site/add_material_screen.dart
// Add/Edit material for a site.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sitedrop_core/app/routes/route_names.dart';
import 'package:sitedrop_core/app/theme/colors.dart';
import 'package:sitedrop_core/app/theme/input_styles.dart';
import 'package:sitedrop_core/core/utils/helpers.dart';
import 'package:sitedrop_core/core/utils/display_names.dart';
import 'package:sitedrop_core/data/models/site_material.dart';
import 'package:sitedrop_core/data/services/site_service.dart';
import '../../widgets/common/app_back_button.dart';
import '../../widgets/common/loading_widget.dart';

class AddMaterialScreen extends ConsumerStatefulWidget {
  final String siteId;
  final SiteMaterialModel? material;

  const AddMaterialScreen({super.key, required this.siteId, this.material});

  @override
  ConsumerState<AddMaterialScreen> createState() => _AddMaterialScreenState();
}

class _AddMaterialScreenState extends ConsumerState<AddMaterialScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityNeededController = TextEditingController();
  final _quantityDeliveredController = TextEditingController();
  final _unitController = TextEditingController();
  final _estimatedCostController = TextEditingController();
  final _actualCostController = TextEditingController();
  final _notesController = TextEditingController();

  DeliveryStatus _deliveryStatus = DeliveryStatus.pending;
  DateTime? _expectedDeliveryDate;
  bool _loading = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.material != null;
    if (_isEditing) {
      final m = widget.material!;
      _nameController.text = m.materialName;
      _quantityNeededController.text = m.quantityNeeded.toString();
      _quantityDeliveredController.text = m.quantityDelivered.toString();
      _unitController.text = m.unit;
      _estimatedCostController.text = m.estimatedCost?.toString() ?? '';
      _actualCostController.text = m.actualCost?.toString() ?? '';
      _notesController.text = m.notes ?? '';
      _deliveryStatus = m.deliveryStatus;
      _expectedDeliveryDate = m.expectedDeliveryDate;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityNeededController.dispose();
    _quantityDeliveredController.dispose();
    _unitController.dispose();
    _estimatedCostController.dispose();
    _actualCostController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _expectedDeliveryDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null && mounted) setState(() => _expectedDeliveryDate = date);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      if (_isEditing) {
        await SiteService.updateMaterial(
          widget.siteId,
          widget.material!.id,
          materialName: _nameController.text.trim(),
          quantityNeeded: double.tryParse(_quantityNeededController.text) ?? 0,
          quantityDelivered: double.tryParse(_quantityDeliveredController.text) ?? 0,
          unit: _unitController.text.trim(),
          estimatedCost: _estimatedCostController.text.isEmpty ? null : double.tryParse(_estimatedCostController.text),
          actualCost: _actualCostController.text.isEmpty ? null : double.tryParse(_actualCostController.text),
          deliveryStatus: _deliveryStatus,
          expectedDeliveryDate: _expectedDeliveryDate,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        );
      } else {
        await SiteService.createMaterial(
          widget.siteId,
          materialName: _nameController.text.trim(),
          quantityNeeded: double.tryParse(_quantityNeededController.text) ?? 0,
          unit: _unitController.text.trim(),
          estimatedCost: _estimatedCostController.text.isEmpty ? null : double.tryParse(_estimatedCostController.text),
          expectedDeliveryDate: _expectedDeliveryDate,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        );
      }

      if (mounted) {
        Helpers.showSuccessToast(_isEditing ? 'Material updated' : 'Material added');
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
        title: appBarTitle(context, _isEditing ? 'Edit Material' : 'Add Material'),
        leading: const AppBackButton(fallbackRoute: RouteNames.sitesManagement),
      ),
      body: _loading
          ? const LoadingWidget(message: 'Saving…')
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _sectionHeader(context, 'Material Information'),
                  _buildTextField(
                    controller: _nameController,
                    label: 'Material Name *',
                    hint: 'e.g., River Sand',
                    validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _quantityNeededController,
                          label: 'Quantity Needed *',
                          hint: '100',
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          validator: (v) {
                            if (v?.trim().isEmpty == true) return 'Required';
                            if (double.tryParse(v!) == null) return 'Invalid number';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDropdown(
                          label: 'Unit *',
                          value: _unitController.text,
                          items: ['ton', 'bag', 'cubic_meter', 'truck', 'trip', 'piece', 'block', 'sheet', 'meter', 'bucket'],
                          onChanged: (v) => setState(() => _unitController.text = v!),
                          validator: (v) => v == null ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _quantityDeliveredController,
                    label: 'Quantity Delivered',
                    hint: '0',
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 16),
                  _buildDropdown(
                    label: 'Delivery Status',
                    value: _deliveryStatus,
                    items: DeliveryStatus.values,
                    onChanged: (v) => setState(() => _deliveryStatus = v!),
                  ),
                  const SizedBox(height: 24),

                  _sectionHeader(context, 'Costs & Schedule'),
                  _buildTextField(
                    controller: _estimatedCostController,
                    label: 'Estimated Cost (GHS)',
                    hint: '5000',
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _actualCostController,
                    label: 'Actual Cost (GHS)',
                    hint: '5200',
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: TextEditingController(
                      text: _expectedDeliveryDate != null
                          ? '${_expectedDeliveryDate!.day}/${_expectedDeliveryDate!.month}/${_expectedDeliveryDate!.year}'
                          : '',
                    ),
                    label: 'Expected Delivery Date',
                    hint: 'Select date',
                    readOnly: true,
                    onTap: _pickDate,
                    suffixIcon: const Icon(Icons.calendar_today),
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
                          : Text(_isEditing ? 'Update Material' : 'Add Material', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
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
      decoration: InputStyles.decoration(
        context,
        labelText: label,
        hintText: hint,
        suffixIcon: suffixIcon,
      ),
      validator: validator,
    );
  }

  Widget _buildDropdown({
    required String label,
    required dynamic value,
    required List<dynamic> items,
    required void Function(dynamic) onChanged,
    String? Function(dynamic)? validator,
  }) {
    // Guard: a value with no matching item (e.g. '' before first pick, or a
    // stored unit outside the hardcoded list) must fall back to null —
    // DropdownButton asserts exactly one match otherwise.
    final safeValue = items.contains(value) ? value : null;
    return DropdownButtonFormField<dynamic>(
      initialValue: safeValue,
      style: InputStyles.text(context),
      decoration: InputStyles.decoration(context, labelText: label),
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(DisplayNames.dropdownLabel(e)))).toList(),
      onChanged: onChanged,
      validator: validator,
    );
  }
}