// lib/presentation/screens/seller/add_product_screen.dart
import 'dart:convert';
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
import 'package:sitedrop_core/data/models/product.dart';
import 'package:sitedrop_core/data/models/site.dart';
import 'package:sitedrop_core/data/services/api_service.dart';
import 'package:sitedrop_core/data/services/product_service.dart';
import 'package:sitedrop_core/data/services/site_service.dart';
import '../../widgets/common/app_back_button.dart';
import '../../widgets/common/loading_widget.dart';
import '../../providers/auth_provider.dart';

class AddProductScreen extends ConsumerStatefulWidget {
  final String? productId;

  const AddProductScreen({super.key, this.productId});

  @override
  ConsumerState<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends ConsumerState<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  final _minQuantityController = TextEditingController();
  final _maxQuantityController = TextEditingController();
  final _skuController = TextEditingController();
  final _unitController = TextEditingController(text: 'trip');
  final _deliveryFeeController = TextEditingController();
  final _prepTimeController = TextEditingController();
  final _weightController = TextEditingController();

  String _selectedCategory = 'aggregates';
  String _selectedSubCategory = 'sand';
  bool _inStock = true;
  bool _isFeatured = false;
  bool _isCodAvailable = true;
  bool _isDeliveryAvailable = true;
  bool _loading = false;
  bool _isEditing = false;
  ProductModel? _existingProduct;
  final List<XFile> _imageFiles = [];
  List<String> _existingImageUrls = [];
  int _featuredIndex = 0;

  List<SiteModel> _sites = [];
  String? _selectedSiteId;
  bool _sitesLoading = false;

  static const _categories = {
    'aggregates': [
      'sand',
      'gravel',
      'crushed_stone',
      'm_sand',
      'laterite',
      'quarry_dust',
    ],
    'cement': [
      'opc_43',
      'opc_53',
      'ppc',
      'white_cement',
      'rapid_hardening',
      'sulphate_resistant',
    ],
    'blocks_bricks': [
      'hollow_blocks',
      'solid_blocks',
      'interlocking_bricks',
      'clay_bricks',
      'concrete_bricks',
      'aac_blocks',
    ],
    'steel': [
      'tmt_bars',
      'binding_wire',
      'wire_mesh',
      'steel_plates',
      'structural_steel',
    ],
    'tools': [
      'hand_tools',
      'power_tools',
      'measuring_tools',
      'safety_gear',
      'masonry_tools',
    ],
    'paints': [
      'emulsion',
      'enamel',
      'primer',
      'weather_proof',
      'textured',
      'wood_metal',
    ],
    'plumbing': [
      'pvc_pipes',
      'cpvc_pipes',
      'gi_pipes',
      'fittings',
      'valves',
      'sanitary_ware',
    ],
    'electrical': [
      'wires_cables',
      'switches_sockets',
      'mcb_db',
      'conduits',
      'lighting',
      'fans',
    ],
    'waterproofing': ['membranes', 'coatings', 'sealants', 'admixtures'],
    'other': ['admixtures', 'tiles', 'roofing', 'insulation', 'chemicals'],
  };
  static const _units = [
    'ton',
    'bag',
    'cubic_meter',
    'truck',
    'trip',
    'piece',
    'block',
    'sheet',
    'meter',
    'bucket',
  ];

  @override
  void initState() {
    super.initState();
    _isEditing = widget.productId != null;
    if (_isEditing) {
      _loadProduct();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSites();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _minQuantityController.dispose();
    _maxQuantityController.dispose();
    _skuController.dispose();
    _unitController.dispose();
    _deliveryFeeController.dispose();
    _prepTimeController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _loadProduct() async {
    try {
      final product = await ProductService.fetchProduct(widget.productId!);
      if (product != null && mounted) {
        setState(() {
          _existingProduct = product;
          _nameController.text = product.name;
          _descriptionController.text = product.description;
          _priceController.text = product.price.toStringAsFixed(2);
          _stockController.text = product.stockQuantity.toString();
          _minQuantityController.text = product.minQuantity.toString();
          _maxQuantityController.text = product.maxQuantity.toString();
          _skuController.text = product.sku;
            _unitController.text = product.unit;
          _deliveryFeeController.text = product.deliveryFeePerKm
              .toStringAsFixed(2);
          _prepTimeController.text = product.preparationTimeMinutes.toString();
          _weightController.text = product.weightKg.toStringAsFixed(2);
          _selectedCategory = _categories.containsKey(product.category)
              ? product.category
              : 'aggregates';
          _selectedSubCategory =
              _categories[_selectedCategory]!.contains(product.subCategory)
              ? product.subCategory
              : _categories[_selectedCategory]!.first;
          _inStock = product.inStock;
          _isFeatured = product.isFeatured;
          _isCodAvailable = product.isCodAvailable;
          _isDeliveryAvailable = product.isDeliveryAvailable;
          // Load every stored image (images[0] is the featured/cover one).
          if (product.images.isNotEmpty) {
            _existingImageUrls = List<String>.from(product.images);
          } else if (product.imageUrl.isNotEmpty) {
            _existingImageUrls = [product.imageUrl];
          }
          _featuredIndex = 0;
          _selectedSiteId = product.siteId.isNotEmpty ? product.siteId : null;
        });
      }
    } catch (e) {
      if (mounted) {
        Helpers.showErrorToast(Helpers.errorMessage(e));
      }
    }
  }

  Future<void> _loadSites() async {
    String? userId;
    ref.read(authProvider).when(
      data: (state) {
        if (state is AuthAuthenticated) {
          userId = state.user.id;
        }
      },
      loading: () {},
      error: (_, _) {},
    );
    if (userId == null) return;
    setState(() => _sitesLoading = true);
    try {
      final sites = await SiteService.fetchSites();
      final filtered = sites
          .where((s) => s.userId == userId && s.siteType != SiteType.construction && s.status == SiteStatus.active)
          .toList();
      final seen = <String>{};
      final deduped = filtered.where((s) => seen.add(s.id)).toList();
      if (mounted) {
        setState(() {
          _sites = deduped;
        });
      }
    } catch (e) {
      debugPrint('Failed to load sites: $e');
    } finally {
      if (mounted) setState(() => _sitesLoading = false);
    }
  }

  static const int _maxImages = 10;

  Future<void> _pickImage() async {
    final remaining = _maxImages - _existingImageUrls.length - _imageFiles.length;
    if (remaining <= 0) {
      Helpers.showErrorToast('Maximum $_maxImages photos per product');
      return;
    }
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 80,
    );
    if (picked.isNotEmpty && mounted) {
      if (picked.length > remaining) {
        Helpers.showErrorToast('Only $remaining more photo(s) allowed');
      }
      setState(() {
        // Only auto-feature when there were no images at all before.
        final hadAny =
            _existingImageUrls.isNotEmpty || _imageFiles.isNotEmpty;
        _imageFiles.addAll(picked.take(remaining));
        if (!hadAny) {
          _featuredIndex = 0;
        }
      });
    }
  }

  void _setFeatured(int index) {
    final total = _existingImageUrls.length + _imageFiles.length;
    if (index < 0 || index >= total) {
      return;
    }
    setState(() => _featuredIndex = index);
  }

  void _removeExistingImage(String url) {
    setState(() {
      _existingImageUrls.remove(url);
      if (_featuredIndex >=
          _existingImageUrls.length + _imageFiles.length) {
        _featuredIndex = 0;
      }
    });
  }

  void _removeNewImage(int index) {
    setState(() {
      if (index < 0 || index >= _imageFiles.length) {
        return;
      }
      _imageFiles.removeAt(index);
      if (_featuredIndex >=
          _existingImageUrls.length + _imageFiles.length) {
        _featuredIndex = 0;
      }
    });
  }

  String _normalizeUnit(String unit) {
    final u = unit.toLowerCase().trim();
    if (u.isEmpty) return 'piece';
    if (u == 'truck' || u == 'trucks') return 'truck';
    if (u == 'cubic_meter' || u == 'cubic meter' || u == 'm3' || u == 'cubicmeter') return 'cubic_meter';
    if (u == 'meter' || u == 'meters' || u == 'm') return 'meter';
    // Keep as is if already valid
    return unit;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      // Clamp the featured index (images may have been removed).
      final combinedCount = _existingImageUrls.length + _imageFiles.length;
      final featuredIndex = combinedCount == 0
          ? 0
          : _featuredIndex.clamp(0, combinedCount - 1);

      final fields = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'price_per_unit': double.parse(_priceController.text),
        'category': _selectedCategory,
        'sub_category': _selectedSubCategory,
        'unit': _normalizeUnit(_unitController.text),
        'minimum_order_quantity':
            int.tryParse(_minQuantityController.text) ?? 1,
        'maximum_order_quantity':
            int.tryParse(_maxQuantityController.text) ?? 1000,
        'stock_quantity': int.parse(_stockController.text),
        'weight_kg': double.tryParse(_weightController.text) ?? 0,
        'delivery_fee_per_km':
            double.tryParse(_deliveryFeeController.text) ?? 0,
        'preparation_time_minutes': int.tryParse(_prepTimeController.text) ?? 0,
        'is_available': _inStock ? 1 : 0,
        'is_featured': _isFeatured ? 1 : 0,
        'is_cod_available': _isCodAvailable ? 1 : 0,
        'is_delivery_available': _isDeliveryAvailable ? 1 : 0,
        if (_selectedSiteId != null && _selectedSiteId!.isNotEmpty) 'site_id': _selectedSiteId,
      };

      final formData = FormData.fromMap(fields);

      if (_isEditing) {
        // Kept images in display order so removals persist server-side.
        // Strip back to stored paths: the backend diffs these against DB
        // values, which are relative `/assets/...` paths.
        final keptPaths = _existingImageUrls
            .map(ApiConstants.toStoragePath)
            .toList();
        formData.fields.add(
          MapEntry('existing_images', jsonEncode(keptPaths)),
        );
      }

      // Tell the backend which image is the cover: a kept URL, or
      // "new:{index}" pointing at one of the uploaded files below.
      if (combinedCount > 0) {
        final featuredValue = featuredIndex < _existingImageUrls.length
            ? ApiConstants.toStoragePath(
                _existingImageUrls[featuredIndex],
              )
            : 'new:${featuredIndex - _existingImageUrls.length}';
        formData.fields.add(MapEntry('featured_image', featuredValue));
      }

      // Attach new images as multipart files.
      // NOTE: the brackets are required — PHP discards repeated `images`
      // parts and keeps only the last one, so `images` (no brackets) arrives
      // as a single file and fails the `array` validation rule.
      for (final file in _imageFiles) {
        if (kIsWeb) {
          final bytes = await file.readAsBytes();
          formData.files.add(
            MapEntry(
              'images[]',
              MultipartFile.fromBytes(
                bytes,
                filename: file.name.isNotEmpty ? file.name : 'image.jpg',
              ),
            ),
          );
        } else {
          formData.files.add(
            MapEntry(
              'images[]',
              await MultipartFile.fromFile(
                file.path,
                filename: file.name.isNotEmpty ? file.name : 'image.jpg',
              ),
            ),
          );
        }
      }

      if (_isEditing) {
        // NOTE: PHP never parses multipart bodies on PUT, so a real PUT
        // would silently update nothing. Spoof via POST + _method instead.
        formData.fields.add(const MapEntry('_method', 'PUT'));
        await ApiService.post<Map<String, dynamic>>(
          ApiConstants.productDetail(_existingProduct!.id),
          data: formData,
          options: Options(contentType: 'multipart/form-data'),
        );
        if (mounted) Helpers.showSuccessToast('Product updated');
      } else {
        await ApiService.post<Map<String, dynamic>>(
          ApiConstants.products,
          data: formData,
          options: Options(contentType: 'multipart/form-data'),
        );
        if (mounted) Helpers.showSuccessToast('Product created');
      }

      if (mounted) {
        // Replace the form in place: back goes to the previous screen,
        // never back into this stale form.
        context.pushReplacement(RouteNames.productManagement);
      }
    } catch (e) {
      if (mounted) {
        Helpers.showErrorToast(Helpers.errorMessage(e));
      }
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
        title: appBarTitle(
          context,
          _isEditing ? 'Edit Product' : 'Add Product',
        ),
        leading: const AppBackButton(
          fallbackRoute: RouteNames.productManagement,
        ),
      ),
      body: _loading
          ? const LoadingWidget(message: 'Savingâ€¦')
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Image picker
                  _buildImagePicker(context),
                  const SizedBox(height: 24),

                  // Basic info section
                  _sectionHeader(context, 'Basic Information'),
                  _buildTextField(
                    controller: _nameController,
                    label: 'Product Name *',
                    hint: 'e.g., River Sand',
                    validator: (v) =>
                        v?.trim().isEmpty == true ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _descriptionController,
                    label: 'Description',
                    hint: 'Describe your product...',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  _buildSiteDropdown(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdown(
                          label: 'Category *',
                          value: _selectedCategory,
                          items: _categories.keys.toList(),
                          onChanged: (v) {
                            setState(() {
                              _selectedCategory = v!;
                              _selectedSubCategory = _categories[v]!.first;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDropdown(
                          label: 'Sub-category *',
                          value: _selectedSubCategory,
                          items: _categories[_selectedCategory]!,
                          onChanged: (v) =>
                              setState(() => _selectedSubCategory = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Pricing & Inventory
                  _sectionHeader(context, 'Pricing & Inventory'),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _priceController,
                          label: 'Price (GHS) *',
                          hint: '0.00',
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (v) {
                            if (v?.trim().isEmpty == true) return 'Required';
                            if (double.tryParse(v!) == null) {
                              return 'Invalid number';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
  child: _buildDropdown(
    label: 'Unit *',
    value: _unitController.text,
    items: _units,
    onChanged: (v) => setState(() => _unitController.text = v!),
  ),
),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _stockController,
                          label: 'Stock Quantity *',
                          hint: '100',
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v?.trim().isEmpty == true) return 'Required';
                            if (int.tryParse(v!) == null) {
                              return 'Invalid number';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _minQuantityController,
                          label: 'Min Order',
                          hint: '1',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _maxQuantityController,
                          label: 'Max Order',
                          hint: '1000',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _skuController,
                          label: 'SKU (optional)',
                          hint: 'SAND-001',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Delivery & Logistics
                  _sectionHeader(context, 'Delivery & Logistics'),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _deliveryFeeController,
                          label: 'Delivery Fee/Km (GHS)',
                          hint: '5.00',
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _prepTimeController,
                          label: 'Prep Time (min)',
                          hint: '30',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _weightController,
                    label: 'Weight per Unit (kg)',
                    hint: '1000',
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Toggle options — each subtitle states exactly what the
                  // buyer app does with the flag, so both sides stay in sync.
                  _sectionHeader(context, 'Options'),
                  _buildSwitchTile(
                    'Published',
                    _inStock
                        ? 'Live in buyer shop & search with an In Stock tag'
                        : 'Hidden from buyer shop & search',
                    _inStock,
                    (v) => setState(() => _inStock = v),
                  ),
                  _buildSwitchTile(
                    'Featured',
                    _isFeatured
                        ? 'Shows in the Featured carousel on buyer home'
                        : 'Excluded from the buyer Featured carousel',
                    _isFeatured,
                    (v) => setState(() => _isFeatured = v),
                  ),
                  _buildSwitchTile(
                    'Cash on Delivery',
                    _isCodAvailable
                        ? 'Buyers see a COD tag and can pay cash at checkout'
                        : 'COD hidden at checkout for this product',
                    _isCodAvailable,
                    (v) => setState(() => _isCodAvailable = v),
                  ),
                  _buildSwitchTile(
                    'Delivery Available',
                    _isDeliveryAvailable
                        ? 'Shows “Delivery Available” on buyer details'
                        : 'Shows “Delivery Unavailable” on buyer details',
                    _isDeliveryAvailable,
                    (v) => setState(() => _isDeliveryAvailable = v),
                  ),
                  const SizedBox(height: 32),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _loading ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _isEditing ? 'Update Product' : 'Create Product',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ], // closes ListView children list
              ), // closes ListView
            ), // closes Form
    ); // closes Scaffold return
  }

  Widget _buildImagePicker(BuildContext context) {
    final p = context.palette;
    final total = _existingImageUrls.length + _imageFiles.length;
    final tiles = <Widget>[];

    // Existing network images. `idx` is copied per iteration so each
    // tile's callbacks capture its own index (not the loop variable).
    for (int i = 0; i < _existingImageUrls.length; i++) {
      final idx = i;
      tiles.add(
        _buildPhotoTile(
          context,
          isCover: idx == _featuredIndex,
          onSetCover: () => _setFeatured(idx),
          onRemove: () => _removeExistingImage(_existingImageUrls[idx]),
          image: Image.network(
            _existingImageUrls[idx],
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _buildTileError(p),
          ),
        ),
      );
    }

    // Newly picked images.
    for (int i = 0; i < _imageFiles.length; i++) {
      final idx = _existingImageUrls.length + i;
      final file = _imageFiles[i];
      final fileIndex = i;
      tiles.add(
        _buildPhotoTile(
          context,
          isCover: idx == _featuredIndex,
          onSetCover: () => _setFeatured(idx),
          onRemove: () => _removeNewImage(fileIndex),
          image: kIsWeb
              ? FutureBuilder<Uint8List>(
                  future: file.readAsBytes(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      return Image.memory(
                        snapshot.data!,
                        fit: BoxFit.cover,
                      );
                    }
                    return _buildTileError(p);
                  },
                )
              : Image.file(File(file.path), fit: BoxFit.cover),
        ),
      );
    }

    tiles.add(_buildAddTile(context, p));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Product Images',
                style: TextStyle(
                  fontSize: 16,
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
                '$total/$_maxImages',
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
          total == 0
              ? 'Add up to $_maxImages photos. The first photo becomes the cover buyers see.'
              : 'Tap the star on any photo to make it the cover buyers see.',
          style: TextStyle(fontSize: 12, color: p.textMuted),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children: tiles,
        ),
      ],
    );
  }

  /// One photo tile: cover gets a primary border + "Cover" chip, others get
  /// a star button to promote them to cover. Mirrors the buyer thumbnail:
  /// images[0] after save is the product thumbnail.
  Widget _buildPhotoTile(
    BuildContext context, {
    required bool isCover,
    required VoidCallback onSetCover,
    required VoidCallback onRemove,
    required Widget image,
  }) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: isCover
                  ? Border.all(color: AppColors.primary, width: 2.5)
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(isCover ? 13 : 16),
              child: SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: image,
              ),
            ),
          ),
        ),
        // Remove button.
        Positioned(
          top: 6,
          right: 6,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(5),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
        if (isCover)
          Positioned(
            top: 6,
            left: 6,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star, size: 12, color: Colors.white),
                  SizedBox(width: 2),
                  Text(
                    'Cover',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Positioned(
            bottom: 6,
            right: 6,
            child: GestureDetector(
              onTap: onSetCover,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.star_outline,
                      size: 12,
                      color: Colors.white,
                    ),
                    SizedBox(width: 2),
                    Text(
                      'Cover',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAddTile(BuildContext context, AppPalette p) {
    return GestureDetector(
      onTap: _pickImage,
      child: CustomPaint(
        painter: _DashedBorderPainter(color: p.divider),
        child: Container(
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add_photo_alternate_outlined,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Add photos',
                style: TextStyle(
                  color: p.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTileError(AppPalette p) {
    return Container(
      color: p.surfaceMuted,
      child: Center(
        child: Icon(
          Icons.broken_image_outlined,
          size: 28,
          color: p.iconMuted,
        ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: context.palette.textPrimary,
        ),
      ),
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
      decoration: InputStyles.decoration(
        context,
        labelText: label,
        hintText: hint,
      ),
      validator: validator,
    );
  }

  String _formatLabel(String s) {
    return s
        .split('_')
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  Widget _buildSiteDropdown() {
    final siteIds = _sites.map((s) => s.id).toSet();
    final safeValue = (_selectedSiteId?.isEmpty ?? true) ? null : (siteIds.contains(_selectedSiteId) ? _selectedSiteId : null);
    return DropdownButtonFormField<String>(
      initialValue: safeValue,
      decoration: InputStyles.decoration(context, labelText: 'Stocked at site'),
      items: [
        const DropdownMenuItem<String>(value: '', child: Text('None / No site')),
        ..._sites.map((s) => DropdownMenuItem<String>(
              value: s.id,
              child: Text('${s.name} • ${s.siteType.value}'),
            )),
      ],
      onChanged: (v) => setState(() => _selectedSiteId = v ?? ''),
      disabledHint: _sitesLoading ? const Text('Loading sites…') : const Text('No sites'),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    final uniqueItems = items.toSet().toList();
    final safeValue = uniqueItems.contains(value) ? value : null;
    return DropdownButtonFormField<String>(
      initialValue: safeValue,
      style: InputStyles.text(context),
      decoration: InputStyles.decoration(context, labelText: label),
      items: uniqueItems
          .map((e) => DropdownMenuItem(value: e, child: Text(_formatLabel(e))))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    void Function(bool) onChanged,
  ) {
    final p = context.palette;
    return SwitchListTile(
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w600, color: p.textPrimary),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: p.textMuted),
      ),
      value: value,
      onChanged: onChanged,
      activeThumbColor: AppColors.primary,
      contentPadding: EdgeInsets.zero,
    );
  }
}

/// Dashed rounded-rectangle border for the "Add photos" tile.
class _DashedBorderPainter extends CustomPainter {
  final Color color;

  const _DashedBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const dash = 7.0;
    const gap = 5.0;
    const radius = 16.0;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final rect = Offset.zero & size;
    final path = Path()..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(radius)));

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) =>
      old.color != color;
}



