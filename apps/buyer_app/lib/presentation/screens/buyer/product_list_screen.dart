// lib/presentation/screens/buyer/product_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sitedrop_core/app/routes/route_names.dart';
import 'package:sitedrop_core/app/theme/colors.dart';
import 'package:sitedrop_core/core/constants/app_constants.dart';
import '../../providers/product_provider.dart';
import '../../widgets/buyer/product_card.dart';
import '../../widgets/common/app_back_button.dart';
import '../../widgets/common/buyer_bottom_nav.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/responsive_scaffold_body.dart';

class ProductListScreen extends ConsumerStatefulWidget {
  final String? initialSearch;
  final String? initialCategory;

  const ProductListScreen({super.key, this.initialSearch, this.initialCategory});

  @override
  ConsumerState<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends ConsumerState<ProductListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    // Query params are passed from go_router (see app_router.dart).
    // Fall back to ModalRoute for legacy/test navigation.
    _searchQuery = widget.initialSearch ?? '';
    _selectedCategory = widget.initialCategory;
    if (_searchQuery.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final uri = Uri.parse(ModalRoute.of(context)?.settings.name ?? '');
        final routeSearch = uri.queryParameters['search'] ?? '';
        final routeCategory = uri.queryParameters['category'];
        if (routeSearch.isNotEmpty || routeCategory != null) {
          setState(() {
            if (routeSearch.isNotEmpty) {
              _searchQuery = routeSearch;
              _searchController.text = routeSearch;
            }
            _selectedCategory = routeCategory;
          });
        }
      });
    } else {
      _searchController.text = _searchQuery;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch() {
    final query = _searchController.text.trim();
    setState(() {
      _searchQuery = query;
    });
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = _searchQuery.isNotEmpty
        ? ref.watch(searchProductsProvider(_searchQuery))
        : _selectedCategory != null
        ? ref.watch(productsByCategoryProvider(_selectedCategory!))
        : ref.watch(productsProvider);

    return Scaffold(
      backgroundColor: context.palette.background,
      bottomNavigationBar: const BuyerBottomNav(),
      appBar: AppBar(
        backgroundColor: context.palette.surface,
        elevation: 0,
        title: appBarTitle(
          context,
          _selectedCategory != null
              ? AppConstants.categoryLabel(_selectedCategory!)
              : 'All Products',
        ),
        leading: const AppBackButton(fallbackRoute: RouteNames.home),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(72),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              style: TextStyle(
                fontSize: 16,
                color: context.palette.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Search products...',
                labelText: 'Search products',
                hintStyle: TextStyle(
                  color: context.palette.textMuted,
                  fontSize: 15,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: context.palette.textMuted,
                ),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        tooltip: 'Clear search',
                        icon: Icon(
                          Icons.clear,
                          color: context.palette.textMuted,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          _performSearch();
                        },
                      ),
                    IconButton(
                      tooltip: 'Filter products',
                      icon: Icon(
                        Icons.filter_list,
                        color: context.palette.textMuted,
                      ),
                      onPressed: () {
                        _showFilterDialog();
                      },
                    ),
                  ],
                ),
                filled: true,
                fillColor: context.palette.inputFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: context.palette.borderStrong,
                    width: 1.5,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: context.palette.borderStrong,
                    width: 1.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppColors.primary, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              onSubmitted: (_) => _performSearch(),
              onChanged: (_) => _performSearch(),
            ),
          ),
        ),
      ),
      body: productsAsync.when(
        data: (products) {
          if (products.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: context.palette.surfaceMuted,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.inventory_2_outlined,
                      size: 60,
                      color: context.palette.iconMuted,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _searchQuery.isNotEmpty
                        ? 'No results found'
                        : 'No Products Available',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: context.palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _searchQuery.isNotEmpty
                        ? 'Try adjusting your search terms'
                        : 'Check back later for new materials',
                    style: TextStyle(
                      color: context.palette.textMuted,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _searchQuery = '';
                        _searchController.clear();
                        _selectedCategory = null;
                      });
                      ref.invalidate(productsProvider);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: Text('Clear Filters'),
                  ),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: responsiveProductGridCount(context),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.7,
            ),
            itemCount: products.length,
            itemBuilder: (context, index) {
              return ProductCard(product: products[index], showAddToCart: true);
            },
          );
        },
        loading: () => const LoadingWidget(message: 'Loading products…'),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.errorSurface,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline,
                  size: 60,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Something went wrong',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: context.palette.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Failed to load products',
                style: TextStyle(
                  color: context.palette.textMuted,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(productsProvider);
                  setState(() {
                    _searchQuery = '';
                    _searchController.clear();
                    _selectedCategory = null;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filter Products',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text('Category', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: Text('All'),
                    selected: _selectedCategory == null,
                    onSelected: (_) {
                      setState(() {
                        _selectedCategory = null;
                        _searchQuery = '';
                        _searchController.clear();
                      });
                      Navigator.pop(context);
                    },
                  ),
                  ...AppConstants.productCategories.map((label) {
                    final slug =
                        AppConstants.productCategorySlugs[label] ?? label;
                    return FilterChip(
                      label: Text(label),
                      selected: _selectedCategory == slug,
                      onSelected: (_) {
                        setState(() {
                          _selectedCategory = slug;
                          _searchQuery = '';
                          _searchController.clear();
                        });
                        Navigator.pop(context);
                      },
                    );
                  }),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedCategory = null;
                      _searchQuery = '';
                      _searchController.clear();
                    });
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: AppColors.white,
                  ),
                  child: Text('Clear All Filters'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
