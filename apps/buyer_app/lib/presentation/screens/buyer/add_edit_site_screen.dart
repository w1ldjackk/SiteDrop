// lib/presentation/screens/buyer/add_edit_site_screen.dart
// Add/Edit construction site screen for buyers.

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:sitedrop_core/app/routes/route_names.dart';
import 'package:sitedrop_core/app/theme/colors.dart';
import 'package:sitedrop_core/app/theme/input_styles.dart';
import 'package:sitedrop_core/core/constants/api_constants.dart';
import 'package:sitedrop_core/core/utils/helpers.dart';
import 'package:sitedrop_core/core/utils/display_names.dart';
import 'package:sitedrop_core/data/models/site.dart';
import 'package:sitedrop_core/maps/app_map_point.dart';
import 'package:sitedrop_core/data/services/site_service.dart';
import '../../widgets/common/app_back_button.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/maps/app_osm_map.dart';

class BuyerAddEditSiteScreen extends ConsumerStatefulWidget {
  final String? siteId;

  const BuyerAddEditSiteScreen({super.key, this.siteId});

  @override
  ConsumerState<BuyerAddEditSiteScreen> createState() =>
      _BuyerAddEditSiteScreenState();
}

class _BuyerAddEditSiteScreenState extends ConsumerState<BuyerAddEditSiteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _sizeController = TextEditingController();
  final _budgetController = TextEditingController();
  final _accessNotesController = TextEditingController();
  final _securityController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();

  SiteStatus _selectedStatus = SiteStatus.planning;
  PriorityLevel _selectedPriority = PriorityLevel.medium;
  bool _loading = false;
  bool _loadingSite = false;
  bool _isEditing = false;
  final List<XFile> _imageFiles = [];
  List<String> _existingImageUrls = [];

  static const _statuses = SiteStatus.values;
  static const _priorities = PriorityLevel.values;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.siteId != null;
    if (_isEditing) {
      _loadSite();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _contactPersonController.dispose();
    _contactPhoneController.dispose();
    _descriptionController.dispose();
    _sizeController.dispose();
    _budgetController.dispose();
    _accessNotesController.dispose();
    _securityController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  Future<void> _loadSite() async {
    setState(() => _loadingSite = true);
    try {
      final site = await SiteService.fetchSite(widget.siteId!);
      if (site != null && mounted) {
        setState(() {
          _nameController.text = site.name;
          _addressController.text = site.address;
          _contactPersonController.text = site.contactPerson ?? '';
          _contactPhoneController.text = site.contactPhone ?? '';
          _descriptionController.text = site.description ?? '';
          _sizeController.text = site.sizeSqMeters?.toString() ?? '';
          _budgetController.text = site.budget?.toString() ?? '';
          _accessNotesController.text = site.accessNotes ?? '';
          _securityController.text = site.securityRequirements ?? '';
          _selectedStatus = site.status;
          _selectedPriority = site.priorityLevel;
          if (site.coordinates != null) {
            _latitudeController.text = site.coordinates!.latitude.toString();
            _longitudeController.text = site.coordinates!.longitude.toString();
          }
          if (site.sitePhotos.isNotEmpty) {
            _existingImageUrls = site.sitePhotos;
          }
        });
      }
    } catch (e) {
      if (mounted) Helpers.showErrorToast(Helpers.errorMessage(e));
    } finally {
      if (mounted) setState(() => _loadingSite = false);
    }
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(maxWidth: 1200, maxHeight: 1200, imageQuality: 80);
    if (picked.isNotEmpty && mounted) {
      setState(() => _imageFiles.addAll(picked));
    }
  }

  Future<void> _pickOnMap() async {
    double? lat = double.tryParse(_latitudeController.text);
    double? lng = double.tryParse(_longitudeController.text);
    final initialPoint = AppMapPoint(lat ?? 5.6037, lng ?? -0.187);

    AppMapPoint? picked;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final p = Theme.of(ctx).extension<AppPalette>()!;
        return StatefulBuilder(
          builder: (ctx, setState) {
            return Container(
              height: MediaQuery.of(ctx).size.height * 0.78,
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                            'Pick site location',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: p.textPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Tap the map to drop a pin for the site.',
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
                          initialCameraPosition: AppCameraPosition(target: initialPoint, zoom: 14),
                          markers: picked != null
                              ? {AppMapMarker(id: 'picked', point: picked!)}
                              : const {},
                          onTap: (point) {
                            setState(() {
                              picked = point;
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                  if (picked != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Text(
                        'Pinned: ${picked!.label}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: picked == null
                                ? null
                                : () {
                                    Navigator.pop(ctx);
                                    if (mounted) {
                                      setState(() {
                                        _latitudeController.text = picked!.latitude.toString();
                                        _longitudeController.text = picked!.longitude.toString();
                                      });
                                    }
                                  },
                            child: const Text('Use location'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      AppMapPoint? coordinates;
      final lat = double.tryParse(_latitudeController.text.trim());
      final lng = double.tryParse(_longitudeController.text.trim());
      if (lat != null && lng != null) {
        coordinates = AppMapPoint(lat, lng);
      }

      final photoFiles = <MultipartFile>[];
      for (final file in _imageFiles) {
        if (kIsWeb) {
          final bytes = await file.readAsBytes();
          photoFiles.add(
            MultipartFile.fromBytes(
              bytes,
              filename: file.name.isNotEmpty ? file.name : 'photo.jpg',
            ),
          );
        } else {
          photoFiles.add(
            await MultipartFile.fromFile(file.path, filename: file.name),
          );
        }
      }

      final existingPaths = _existingImageUrls
          .map(ApiConstants.toStoragePath)
          .where((p) => p.isNotEmpty)
          .toList();

      SiteModel site;
      if (_isEditing) {
        site = await SiteService.updateSite(
          widget.siteId!,
          name: _nameController.text.trim(),
          address: _addressController.text.trim(),
          siteType: SiteType.construction,
          contactPerson: _contactPersonController.text.trim().isEmpty
              ? null
              : _contactPersonController.text.trim(),
          contactPhone: _contactPhoneController.text.trim().isEmpty
              ? null
              : _contactPhoneController.text.trim(),
          coordinates: coordinates,
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          status: _selectedStatus,
          sizeSqMeters: _sizeController.text.isEmpty
              ? null
              : double.tryParse(_sizeController.text),
          budget: _budgetController.text.isEmpty
              ? null
              : double.tryParse(_budgetController.text),
          priorityLevel: _selectedPriority,
          accessNotes: _accessNotesController.text.trim().isEmpty
              ? null
              : _accessNotesController.text.trim(),
          securityRequirements: _securityController.text.trim().isEmpty
              ? null
              : _securityController.text.trim(),
          statusUpdateReason: 'Updated via app',
          sitePhotoFiles: photoFiles,
          existingPhotoPaths:
              photoFiles.isNotEmpty && existingPaths.isNotEmpty ? existingPaths : null,
        );
      } else {
        site = await SiteService.createSite(
          name: _nameController.text.trim(),
          address: _addressController.text.trim(),
          siteType: SiteType.construction,
          contactPerson: _contactPersonController.text.trim().isEmpty
              ? null
              : _contactPersonController.text.trim(),
          contactPhone: _contactPhoneController.text.trim().isEmpty
              ? null
              : _contactPhoneController.text.trim(),
          coordinates: coordinates,
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          status: _selectedStatus,
          sizeSqMeters: _sizeController.text.isEmpty
              ? null
              : double.tryParse(_sizeController.text),
          budget: _budgetController.text.isEmpty
              ? null
              : double.tryParse(_budgetController.text),
          priorityLevel: _selectedPriority,
          accessNotes: _accessNotesController.text.trim().isEmpty
              ? null
              : _accessNotesController.text.trim(),
          securityRequirements: _securityController.text.trim().isEmpty
              ? null
              : _securityController.text.trim(),
          sitePhotoFiles: photoFiles,
        );
      }

      if (mounted) {
        if (site.id.isEmpty) {
          Helpers.showErrorToast(
              'Site saved but the server response was unreadable. Please check My Sites.');
          return;
        }
        Helpers.showSuccessToast(_isEditing ? 'Site updated' : 'Site created');
        context.pushReplacement(RouteNames.buyerSites);
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
        title: Text(
          _isEditing ? 'Edit Site' : 'Add Construction Site',
          style: TextStyle(fontWeight: FontWeight.w700, color: p.textPrimary),
        ),
        leading: const AppBackButton(fallbackRoute: RouteNames.buyerSites),
      ),
      body: _loadingSite
          ? const LoadingWidget(message: 'Loading site…')
          : _loading
              ? const LoadingWidget(message: 'Saving…')
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildImagePicker(context),
                      const SizedBox(height: 24),
                      _sectionHeader(context, 'Basic Information'),
                      _buildTextField(
                        controller: _nameController,
                        label: 'Site Name *',
                        hint: 'e.g., Kumasi Housing Project',
                        validator: (v) =>
                            v?.trim().isEmpty == true ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _addressController,
                        label: 'Address *',
                        hint: 'Full address',
                        maxLines: 2,
                        validator: (v) =>
                            v?.trim().isEmpty == true ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _latitudeController,
                              label: 'Latitude',
                              hint: 'e.g., 5.6037',
                              keyboardType: TextInputType.numberWithOptions(
                                  signed: true, decimal: true),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: _longitudeController,
                              label: 'Longitude',
                              hint: 'e.g., -0.187',
                              keyboardType: TextInputType.numberWithOptions(
                                  signed: true, decimal: true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => _pickOnMap(),
                          icon: const Icon(Icons.map_outlined),
                          label: const Text('Pick on map'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDropdown(
                              label: 'Status *',
                              value: _selectedStatus,
                              items: _statuses,
                              onChanged: (v) =>
                                  setState(() => _selectedStatus = v!),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDropdown(
                              label: 'Priority *',
                              value: _selectedPriority,
                              items: _priorities,
                              onChanged: (v) =>
                                  setState(() => _selectedPriority = v!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _sectionHeader(context, 'Contact Information'),
                      _buildTextField(
                        controller: _contactPersonController,
                        label: 'Contact Person',
                        hint: 'Site manager name',
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _contactPhoneController,
                        label: 'Contact Phone',
                        hint: '024 123 4567',
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 24),
                      _sectionHeader(context, 'Site Details'),
                      _buildTextField(
                        controller: _descriptionController,
                        label: 'Description',
                        hint: 'Brief description of the site',
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _sizeController,
                              label: 'Size (m²)',
                              hint: '1000',
                              keyboardType: TextInputType.numberWithOptions(
                                  decimal: true),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: _budgetController,
                              label: 'Budget (GHS)',
                              hint: '500000',
                              keyboardType: TextInputType.numberWithOptions(
                                  decimal: true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _sectionHeader(context, 'Additional Notes'),
                      _buildTextField(
                        controller: _accessNotesController,
                        label: 'Access Notes',
                        hint: 'Entry requirements, gate codes, etc.',
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _securityController,
                        label: 'Security Requirements',
                        hint: 'PPE, safety briefings, etc.',
                        maxLines: 2,
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
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: _loading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.5, color: Colors.white))
                              : Text(
                                  _isEditing ? 'Update Site' : 'Create Site',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16)),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  Widget _buildImagePicker(BuildContext context) {
    final p = context.palette;
    final images = <Widget>[];

    for (final url in _existingImageUrls) {
      images.add(_buildGalleryItem(url: url, isNetwork: true));
    }

    for (final file in _imageFiles) {
      images.add(_buildGalleryItem(file: file));
    }

    images.add(_buildAddButton(p));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Site Photos',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: p.textPrimary)),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          children: images,
        ),
      ],
    );
  }

  Widget _buildGalleryItem(
      {String? url, XFile? file, bool isNetwork = false}) {
    final p = context.palette;
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: isNetwork && url != null
                ? Image.network(url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _buildPlaceholder(p))
                : file != null
                    ? kIsWeb
                        ? FutureBuilder<Uint8List>(
                            future: file.readAsBytes(),
                            builder: (context, snapshot) {
                              if (snapshot.hasData) {
                                return Image.memory(snapshot.data!,
                                    fit: BoxFit.cover);
                              }
                              if (snapshot.hasError) {
                                return _buildPlaceholder(p);
                              }
                              return const Center(
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2));
                            },
                          )
                        : Image.file(File(file.path), fit: BoxFit.cover)
                    : _buildPlaceholder(p),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () {
              setState(() {
                if (url != null) {
                  _existingImageUrls.remove(url);
                } else if (file != null) {
                  _imageFiles.remove(file);
                }
              });
            },
            child: Container(
              decoration: const BoxDecoration(
                  color: Colors.black54, shape: BoxShape.circle),
              padding: const EdgeInsets.all(4),
              child: const Icon(Icons.close, size: 16, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddButton(AppPalette p) {
    return GestureDetector(
      onTap: _pickImages,
      child: Container(
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: p.divider),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined, color: p.iconMuted),
            const SizedBox(height: 4),
            Text('Add', style: TextStyle(color: p.textMuted, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(AppPalette p) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_photo_alternate_outlined,
            size: 48, color: p.iconMuted),
        const SizedBox(height: 8),
        Text('Tap to add',
            style: TextStyle(color: p.textMuted, fontSize: 12)),
      ],
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title,
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: context.palette.textPrimary)),
    );
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
      decoration: InputStyles.decoration(context, labelText: label, hintText: hint),
      validator: validator,
    );
  }

  Widget _buildDropdown({
    required String label,
    required dynamic value,
    required List<dynamic> items,
    required void Function(dynamic) onChanged,
  }) {
    final uniqueItems = items.toSet().toList();
    final safeValue = uniqueItems.contains(value) ? value : null;
    return DropdownButtonFormField<dynamic>(
      initialValue: safeValue,
      style: InputStyles.text(context),
      decoration: InputStyles.decoration(context, labelText: label),
      items: uniqueItems
          .map((e) => DropdownMenuItem(
              value: e, child: Text(DisplayNames.dropdownLabel(e))))
          .toList(),
      onChanged: onChanged,
    );
  }
}