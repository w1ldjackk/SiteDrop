// lib/presentation/widgets/cart/cart_card.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:sitedrop_core/app/routes/route_names.dart';
import 'package:sitedrop_core/app/theme/colors.dart';
import 'package:sitedrop_core/core/utils/helpers.dart';
import 'package:sitedrop_core/data/models/cart_item.dart';
import '../../providers/cart_provider.dart';
import '../common/loading_widget.dart';

class CartCard extends ConsumerStatefulWidget {
  final CartItemModel item;
  final bool showRemoveButton;
  final VoidCallback? onRemove;
  final void Function(int)? onQuantityChanged;

  const CartCard({
    super.key,
    required this.item,
    this.showRemoveButton = true,
    this.onRemove,
    this.onQuantityChanged,
  });

  @override
  ConsumerState<CartCard> createState() => _CartCardState();
}

class _CartCardState extends ConsumerState<CartCard> {
  late final TextEditingController _qtyController;
  late final FocusNode _qtyFocus;

  CartItemModel get item => widget.item;

  @override
  void initState() {
    super.initState();
    _qtyController = TextEditingController(text: '${item.quantity}');
    _qtyFocus = FocusNode();
    _qtyFocus.addListener(_onQtyFocusChange);
  }

  @override
  void didUpdateWidget(covariant CartCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keep field in sync when quantity changes from +/- or external update,
    // but don't clobber while the user is typing.
    if (oldWidget.item.quantity != item.quantity && !_qtyFocus.hasFocus) {
      _qtyController.text = '${item.quantity}';
    }
  }

  @override
  void dispose() {
    _qtyFocus.removeListener(_onQtyFocusChange);
    _qtyFocus.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  void _onQtyFocusChange() {
    if (!_qtyFocus.hasFocus) {
      _commitTypedQuantity();
    }
  }

  void _commitTypedQuantity() {
    final raw = _qtyController.text.trim();
    final parsed = int.tryParse(raw);
    if (parsed == null || parsed < 1) {
      _qtyController.text = '${item.quantity}';
      return;
    }
    final maxQty = (item.maxQuantity != null && item.maxQuantity! > 0)
        ? item.maxQuantity!
        : 999;
    final next = parsed.clamp(1, maxQty);
    _qtyController.text = '$next';
    if (next != item.quantity) {
      _setQuantity(next);
    }
  }

  void _remove() {
    if (widget.onRemove != null) {
      widget.onRemove!();
    } else {
      ref.read(cartProvider.notifier).removeProduct(item.product.id);
      Helpers.showSuccessToast('Removed from cart');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMinQuantity = item.quantity <= 1;
    final p = context.palette;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      child: Slidable(
        key: ValueKey('cart-${item.id ?? item.product.id}'),
        endActionPane: widget.showRemoveButton
            ? ActionPane(
                motion: const DrawerMotion(),
                extentRatio: 0.28,
                children: [
                  SlidableAction(
                    onPressed: (_) => _remove(),
                    backgroundColor: AppColors.error,
                    foregroundColor: AppColors.white,
                    icon: Icons.delete_outline,
                    label: 'Remove',
                    borderRadius: BorderRadius.circular(12),
                  ),
                ],
              )
            : null,
        child: Card(
          elevation: 0,
          color: p.surface,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: p.border, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _buildProductImage(context),
                const SizedBox(width: 12),
                Expanded(child: _buildProductDetails(context, isMinQuantity)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductImage(BuildContext context) {
    return GestureDetector(
      onTap: () {
        context.go(RouteNames.productDetail.replaceAll(':id', item.product.id));
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 80,
          height: 80,
          color: context.palette.surfaceMuted,
          child: item.product.imageUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: item.product.imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const LoadingWidget.compact(),
                  errorWidget: (context, url, error) => Icon(
                    Icons.image_not_supported,
                    color: context.palette.iconMuted,
                  ),
                )
              : Icon(
                  Icons.image_not_supported,
                  color: context.palette.iconMuted,
                ),
        ),
      ),
    );
  }

  Widget _buildProductDetails(BuildContext context, bool isMinQuantity) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            context.go(
              RouteNames.productDetail.replaceAll(':id', item.product.id),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.product.name,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: context.palette.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'Unit: ${item.product.unit}',
                style: TextStyle(
                  fontSize: 12,
                  color: context.palette.textMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _buildQuantityControls(context, isMinQuantity),
        const SizedBox(height: 4),
        Text(
          Helpers.formatPrice(item.product.price),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildQuantityControls(BuildContext context, bool isMinQuantity) {
    final p = context.palette;
    return Row(
      children: [
        isMinQuantity
            ? Tooltip(
                message: 'Minimum quantity reached',
                child: _buildDecreaseButton(context, isMinQuantity),
              )
            : _buildDecreaseButton(context, isMinQuantity),
        const SizedBox(width: 4),
        SizedBox(
          width: 40,
          height: 28,
          child: TextField(
            controller: _qtyController,
            focusNode: _qtyFocus,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: p.textPrimary,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: p.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: p.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.5,
                ),
              ),
              filled: true,
              fillColor: p.inputFill,
            ),
            onSubmitted: (_) => _commitTypedQuantity(),
          ),
        ),
        const SizedBox(width: 4),
        InkWell(
          onTap: () => _setQuantity(item.quantity + 1),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.add, size: 16, color: Colors.white),
          ),
        ),
        const Spacer(),
        if (widget.showRemoveButton)
          InkWell(
            onTap: _handleRemove,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.errorSurface,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.delete_outline,
                size: 16,
                color: AppColors.error,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDecreaseButton(BuildContext context, bool isMinQuantity) {
    final p = context.palette;
    return InkWell(
      onTap: isMinQuantity ? null : () => _setQuantity(item.quantity - 1),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: isMinQuantity ? p.surfaceMuted : p.surfaceElevated,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isMinQuantity
                ? p.border.withValues(alpha: 0.5)
                : p.borderStrong,
            width: 1,
          ),
        ),
        child: Icon(
          Icons.remove,
          size: 16,
          color: isMinQuantity ? p.textDisabled : p.icon,
        ),
      ),
    );
  }

  void _setQuantity(int quantity) {
    if (widget.onQuantityChanged != null) {
      widget.onQuantityChanged!(quantity);
      return;
    }
    ref.read(cartProvider.notifier).updateQuantity(item.product.id, quantity);
  }

  void _handleRemove() {
    if (widget.onRemove != null) {
      widget.onRemove!();
      return;
    }
    ref.read(cartProvider.notifier).removeProduct(item.product.id);
    Helpers.showSuccessToast('Item removed from cart');
  }
}
