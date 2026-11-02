// lib/presentation/widgets/buyer/product_search_bar.dart
// Editable product search with a small live preview under the bar
// (top matches + see-all row) and camera photo search. Shared by the
// home and categories screens.
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:sitedrop_core/app/routes/route_names.dart';
import 'package:sitedrop_core/app/theme/colors.dart';
import 'package:sitedrop_core/core/utils/helpers.dart';
import '../../providers/product_provider.dart';

class ProductSearchBar extends ConsumerStatefulWidget {
  final String hintText;
  final Color? fillColor;
  final Color? borderColor;

  const ProductSearchBar({
    super.key,
    this.hintText = 'Search materials...',
    this.fillColor,
    this.borderColor,
  });

  @override
  ConsumerState<ProductSearchBar> createState() => _ProductSearchBarState();
}

class _ProductSearchBarState extends ConsumerState<ProductSearchBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  Timer? _debounce;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() => _query = value.trim());
    });
  }

  void _submit(String value) {
    final query = value.trim();
    if (query.isEmpty) return;
    _focus.unfocus();
    setState(() {
      _controller.text = query;
      _query = '';
    });
    context.go(
      '${RouteNames.products}?search=${Uri.encodeComponent(query)}',
    );
  }

  /// Tapping a suggestion selects it: fill the field and run the search.
  void _selectSuggestion(String name) {
    _focus.unfocus();
    setState(() {
      _controller.text = name;
      _query = '';
    });
    context.go(
      '${RouteNames.products}?search=${Uri.encodeComponent(name.trim())}',
    );
  }

  bool get _showPreview =>
      _focus.hasFocus && _query.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: widget.fillColor ?? palette.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.borderColor ?? palette.borderStrong,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  textInputAction: TextInputAction.search,
                  style: TextStyle(
                    fontSize: 16,
                    color: palette.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    hintStyle: TextStyle(
                      color: palette.textMuted,
                      fontSize: 15,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: palette.textMuted,
                    ),
                    suffixIcon: _controller.text.isNotEmpty
                        ? IconButton(
                            tooltip: 'Clear',
                            icon: Icon(
                              Icons.clear,
                              color: palette.textMuted,
                            ),
                            onPressed: () {
                              _debounce?.cancel();
                              setState(() {
                                _controller.clear();
                                _query = '';
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  onChanged: _onChanged,
                  onSubmitted: _submit,
                ),
              ),
              Container(
                width: 1,
                height: 30,
                color: palette.divider,
              ),
              IconButton(
                onPressed: _onCameraPressed,
                tooltip: 'Search by camera',
                icon: Icon(
                  Icons.camera_alt_outlined,
                  color: AppColors.primary,
                  size: 26,
                ),
                style: IconButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            ],
          ),
        ),
        if (_showPreview) _previewPanel(context),
      ],
    );
  }

  Widget _previewPanel(BuildContext context) {
    final palette = context.palette;
    final resultsAsync = ref.watch(searchProductsProvider(_query));
    final results = resultsAsync.asData?.value ?? const [];

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      constraints: const BoxConstraints(maxHeight: 320),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Material(
          color: Colors.transparent,
          child: resultsAsync.isLoading && results.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  ),
                )
              : results.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'No matches for "$_query" — tap search for full results',
                        style: TextStyle(
                          fontSize: 13,
                          color: palette.textMuted,
                        ),
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: ListView.separated(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: results.take(5).length,
                            separatorBuilder: (_, _) => Divider(
                              height: 1,
                              color: palette.divider,
                            ),
                            itemBuilder: (context, i) {
                              final p = results[i];
                              return ListTile(
                                dense: true,
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 2,
                                ),
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: p.imageUrl.isNotEmpty
                                      ? Image.network(
                                          p.imageUrl,
                                          width: 44,
                                          height: 44,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) =>
                                              _thumbFallback(context),
                                        )
                                      : _thumbFallback(context),
                                ),
                                title: Text(
                                  p.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                subtitle: Text(
                                  '${p.category} · ${Helpers.formatPrice(p.price)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: palette.textMuted,
                                  ),
                                ),
                                trailing: Icon(
                                  Icons.north_west,
                                  size: 18,
                                  color: palette.textMuted,
                                ),
                                onTap: () =>
                                    _selectSuggestion(p.name),
                              );
                            },
                          ),
                        ),
                        InkWell(
                          onTap: () => _submit(_query),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: palette.primarySoft,
                              borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(14),
                              ),
                            ),
                            child: Text(
                              'See all results for "$_query"',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _thumbFallback(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      color: context.palette.surfaceMuted,
      child: Icon(
        Icons.inventory_2_outlined,
        color: context.palette.iconMuted,
      ),
    );
  }

  // ============================================================
  // CAMERA PHOTO SEARCH
  // ============================================================
  Future<void> _onCameraPressed() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(sheet, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(sheet, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      _showPhotoSearchSheet(bytes);
    } catch (_) {
      if (mounted) {
        Helpers.showErrorToast('Could not open the camera');
      }
    }
  }

  void _showPhotoSearchSheet(Uint8List bytes) {
    // NOTE: no TextEditingController — disposing a sheet-owned controller
    // at close races the exit animation rebuild ("used after dispose").
    var queryText = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheet) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(sheet).viewInsets.bottom + 20,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheet).size.height * 0.9,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.memory(
                bytes,
                height: 200,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Describe what you see (e.g. cement, steel rods)',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              textInputAction: TextInputAction.search,
              onChanged: (v) => queryText = v,
              decoration: const InputDecoration(
                hintText: 'Material name or description',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              onSubmitted: (v) {
                Navigator.pop(sheet);
                _submit(v);
              },
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                final q = queryText;
                Navigator.pop(sheet);
                if (q.trim().isEmpty) {
                  Helpers.showInfoToast(
                    'Describe the material to search for it',
                  );
                  return;
                }
                _submit(q);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Search products'),
            ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
