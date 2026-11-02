// lib/presentation/screens/site/add_document_screen.dart
// Add/Edit site document.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:sitedrop_core/app/routes/route_names.dart';
import 'package:sitedrop_core/app/theme/colors.dart';
import 'package:sitedrop_core/app/theme/input_styles.dart';
import 'package:sitedrop_core/core/utils/helpers.dart';
import 'package:sitedrop_core/core/utils/display_names.dart';
import 'package:sitedrop_core/data/models/site_document.dart';
import 'package:sitedrop_core/data/services/site_service.dart';
import '../../widgets/common/app_back_button.dart';
import '../../widgets/common/loading_widget.dart';

class AddDocumentScreen extends ConsumerStatefulWidget {
  final String siteId;

  const AddDocumentScreen({super.key, required this.siteId});

  @override
  ConsumerState<AddDocumentScreen> createState() => _AddDocumentScreenState();
}

class _AddDocumentScreenState extends ConsumerState<AddDocumentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _versionController = TextEditingController(text: '1.0');
  final _tagsController = TextEditingController();

  DocumentType _documentType = DocumentType.permit;
  DocumentStatus _status = DocumentStatus.draft;
  AccessLevel _accessLevel = AccessLevel.public;
  bool _isConfidential = false;
  DateTime? _expiryDate;
  XFile? _selectedFile;
  bool _loading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _versionController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final picker = ImagePicker();
    final picked = await picker.pickMedia();
    if (picked != null && mounted) {
      setState(() => _selectedFile = picked);
    }
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );
    if (date != null && mounted) setState(() => _expiryDate = date);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final selectedFile = _selectedFile;
    if (selectedFile == null) {
      Helpers.showErrorToast('Please select a file');
      return;
    }

    setState(() => _loading = true);

    try {
      final tags = _tagsController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      final List<int>? fileBytes =
          kIsWeb ? await selectedFile.readAsBytes() : null;

      await SiteService.uploadDocument(
        widget.siteId,
        title: _titleController.text.trim(),
        documentType: _documentType,
        filePath: selectedFile.path,
        fileName: selectedFile.name,
        fileBytes: fileBytes,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        version: _versionController.text.trim().isEmpty
            ? null
            : _versionController.text.trim(),
        status: _status,
        expiryDate: _expiryDate,
        isConfidential: _isConfidential,
        accessLevel: _accessLevel,
        tags: tags.isEmpty ? null : tags,
      );
      if (mounted) {
        Helpers.showSuccessToast('Document uploaded');
      }
      if (mounted) {
        // Replace the form: back goes to the previous screen.
        context.pushReplacement(RouteNames.siteDetailWithId(widget.siteId));
      }
    } catch (e) {
      if (mounted) {
        Helpers.showErrorToast(Helpers.errorMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
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
        title: appBarTitle(context, 'Upload Document'),
        leading: const AppBackButton(fallbackRoute: RouteNames.sitesManagement),
      ),
      body: _loading
          ? const LoadingWidget(message: 'Uploading…')
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _sectionHeader(context, 'Document Information'),
                  _buildTextField(
                    controller: _titleController,
                    label: 'Title *',
                    hint: 'e.g., Building Permit #123',
                    validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildDropdown(
                    label: 'Document Type *',
                    value: _documentType,
                    items: DocumentType.values,
                    onChanged: (v) => setState(() => _documentType = v!),
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _descriptionController,
                    label: 'Description',
                    hint: 'Brief description of the document',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _versionController,
                    label: 'Version',
                    hint: '1.0',
                  ),
                  const SizedBox(height: 24),

                  _sectionHeader(context, 'File'),
                  _buildFilePicker(),
                  const SizedBox(height: 24),

                  _sectionHeader(context, 'Status & Access'),
                  _buildDropdown(
                    label: 'Status',
                    value: _status,
                    items: DocumentStatus.values,
                    onChanged: (v) => setState(() => _status = v!),
                  ),
                  const SizedBox(height: 16),
                  _buildDropdown(
                    label: 'Access Level',
                    value: _accessLevel,
                    items: AccessLevel.values,
                    onChanged: (v) => setState(() => _accessLevel = v!),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: Text('Confidential', style: TextStyle(fontWeight: FontWeight.w600, color: p.textPrimary)),
                    subtitle: Text('Restrict access to authorized personnel', style: TextStyle(fontSize: 12, color: p.textMuted)),
                    value: _isConfidential,
                    onChanged: (v) => setState(() => _isConfidential = v),
                    activeThumbColor: AppColors.error,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: TextEditingController(text: _expiryDate != null ? '${_expiryDate!.day}/${_expiryDate!.month}/${_expiryDate!.year}' : ''),
                    label: 'Expiry Date (optional)',
                    hint: 'Select date',
                    readOnly: true,
                    onTap: _pickDate,
                    suffixIcon: const Icon(Icons.calendar_today),
                  ),
                  const SizedBox(height: 24),

                  _sectionHeader(context, 'Tags (comma-separated)'),
                  _buildTextField(
                    controller: _tagsController,
                    label: 'Tags',
                    hint: 'permit, construction, phase-1',
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
                          : const Text('Upload Document', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
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

  Widget _buildFilePicker() {
    final p = context.palette;
    return GestureDetector(
      onTap: _pickFile,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: p.divider, style: BorderStyle.solid),
        ),
        child: _selectedFile != null
            ? Row(
                children: [
                  Icon(Icons.insert_drive_file, color: AppColors.primary, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_selectedFile!.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w600, color: p.textPrimary)),
                          FutureBuilder<int>(
                            future: _selectedFile!.length(),
                            builder: (context, snapshot) {
                              if (snapshot.hasData) {
                                return Text('${(snapshot.data! / 1024).toStringAsFixed(1)} KB', style: TextStyle(fontSize: 12, color: p.textMuted));
                              }
                              return Text('...', style: TextStyle(fontSize: 12, color: p.textMuted));
                            },
                          ),
                        ],
                      ),
                    ),
                  IconButton(onPressed: () => setState(() => _selectedFile = null), icon: Icon(Icons.close, color: p.iconMuted)),
                ],
              )
            : Column(
                children: [
                  Icon(Icons.cloud_upload_outlined, size: 48, color: p.iconMuted),
                  const SizedBox(height: 8),
                  Text('Tap to select document', style: TextStyle(color: p.textMuted, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text('PDF, DOC, JPG, PNG up to 10MB', style: TextStyle(color: p.textMuted, fontSize: 11)),
                ],
              ),
      ),
    );
  }
}