// lib/presentation/screens/buyer/categories_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sitedrop_core/app/routes/route_names.dart';
import 'package:sitedrop_core/app/theme/colors.dart';
import 'package:sitedrop_core/core/constants/app_constants.dart';
import '../../providers/product_provider.dart';
import '../../widgets/buyer/product_search_bar.dart';
import '../../widgets/common/responsive_scaffold_body.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  String _selectedCategory = 'All';

  /// Display label → products screen. Labels with a backend slug filter by
  /// `?category=`; the rest fall back to `?search=` so no tile is a dead end.
  void _openCategory(String label) {
    setState(() => _selectedCategory = label);
    if (label == 'All') {
      context.go(RouteNames.products);
      return;
    }
    final slug = AppConstants.productCategorySlugs[label];
    if (slug != null) {
      context.go(
        '${RouteNames.products}?category=${Uri.encodeComponent(slug)}',
      );
    } else {
      context.go(
        '${RouteNames.products}?search=${Uri.encodeComponent(label)}',
      );
    }
  }

  /// Icons per category (static); counts come from live listings below.
  static const _filterIcons = <String, IconData>{
    'All': Icons.dashboard,
    'Sand': Icons.send,
    'Gravel': Icons.landscape,
    'Stones': Icons.terrain,
    'Cement Blocks': Icons.dining,
    'Cement': Icons.grid_on,
    'Steel': Icons.construction,
    'Lumber': Icons.build,
    'Paints': Icons.palette,
    'Plumbing': Icons.plumbing,
    'Electrical': Icons.electrical_services,
    'Tools': Icons.handyman,
    'Other': Icons.more_horiz,
  };

  /// Live counts from the product catalog (no mock numbers), keyed by
  /// lowercase backend slug so display labels resolve to real counts.
  Map<String, int> _counts(List<dynamic> products) {
    final counts = <String, int>{'All': products.length};
    for (final p in products) {
      final cat = (p.category ?? '').toString().toLowerCase();
      if (cat.isEmpty) continue;
      counts[cat] = (counts[cat] ?? 0) + 1;
    }
    return counts;
  }

  int _countFor(String label, Map<String, int> counts) {
    final slug = AppConstants.productCategorySlugs[label];
    if (slug != null) return counts[slug] ?? 0;
    if (label == 'All') return counts['All'] ?? 0;
    return counts[label.toLowerCase()] ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.background,
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
        children: [
          // Custom AppBar with Search Bar - No Back Button
          Container(
            color: context.palette.surface,
            padding: const EdgeInsets.only(
              top: 8,
              left: 16,
              right: 16,
              bottom: 12,
            ),
            child: const ProductSearchBar(),
          ),
          // Main Content with Sticky Filter Bar
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Vertical Sticky Filter Bar
                Container(
                  width: 100,
                  color: context.palette.surface,
                  child: Column(
                    children: [
                      // Filter Header
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: context.palette.divider,
                              width: 1,
                            ),
                          ),
                        ),
                        child: Icon(
                          Icons.filter_list,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      // Filter Items - Scrollable (live catalog counts)
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            final products =
                                ref.watch(productsProvider).asData?.value ??
                                    const [];
                            final counts = _counts(products);
                            // 'All' + known categories + any new ones from data.
                            final labels = [
                              'All',
                              ...AppConstants.productCategories,
                              ...counts.keys.where((c) =>
                                  c != 'All' &&
                                  !AppConstants.productCategories
                                      .contains(c)),
                            ];
                            return ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                vertical: 8,
                              ),
                              itemCount: labels.length,
                              itemBuilder: (context, index) {
                                final label = labels[index];
                                final icon = _filterIcons[label] ??
                                    Icons.more_horiz;
                                final count = _countFor(label, counts);
                                final isSelected =
                                    _selectedCategory == label;
                            return Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? context.palette.primarySoft
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: InkWell(
                                onTap: () => _openCategory(label),
                                borderRadius: BorderRadius.circular(8),
                                child: Semantics(
                                  selected: isSelected,
                                  button: true,
                                  label: '$label category filter',
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 4,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        icon,
                                        color: isSelected
                                            ? AppColors.primary
                                            : context.palette.textMuted,
                                        size: 22,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        label,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                          color: isSelected
                                              ? AppColors.primary
                                              : context.palette.textMuted,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (count > 0) ...[
                                        const SizedBox(height: 2),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? AppColors.primary
                                                : context.palette.surfaceMuted,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            '$count',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: isSelected
                                                  ? Colors.white
                                                  : context.palette.textMuted,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                      // Reset Filter Button
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: context.palette.divider, width: 1),
                          ),
                        ),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedCategory = 'All';
                            });
                            context.go(RouteNames.products);
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Semantics(
                            button: true,
                            label: 'Reset category filter',
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 16,
                            ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.refresh,
                                color: context.palette.textMuted,
                                size: 22,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Reset',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.palette.textMuted,
                                ),
                              ),
                            ],
                          ),
                          ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Category Grid
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: responsiveCategoryGridCount(context),
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: AppConstants.productCategories.length,
                      itemBuilder: (context, index) {
                        final category = AppConstants.productCategories[index];
                        return Container(
                          decoration: BoxDecoration(
                            color: context.palette.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: context.palette.divider,
                              width: 1,
                            ),
                          ),
                          child: InkWell(
                            onTap: () => _openCategory(category),
                            borderRadius: BorderRadius.circular(12),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: context.palette.primarySoft,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    _getCategoryIcon(index),
                                    size: 22,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  category,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: context.palette.textPrimary,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(int index) {
    final icons = [
      Icons.send,
      Icons.landscape,
      Icons.terrain,
      Icons.dining,
      Icons.grid_on,
      Icons.construction,
      Icons.build,
      Icons.square_foot,
      Icons.palette,
      Icons.plumbing,
      Icons.electrical_services,
      Icons.handyman,
      Icons.more_horiz,
    ];
    return icons[index % icons.length];
  }
}
