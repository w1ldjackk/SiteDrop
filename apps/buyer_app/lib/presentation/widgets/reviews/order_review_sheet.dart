// lib/presentation/widgets/reviews/order_review_sheet.dart
// SiteDrop-style trip rating: seller stars + optional driver stars in one sheet.
// Used by My Reviews, order tracking, and order history detail entry points.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sitedrop_core/app/theme/colors.dart';
import 'package:sitedrop_core/core/utils/helpers.dart';
import 'package:sitedrop_core/data/models/order.dart';
import 'package:sitedrop_core/data/services/review_service.dart';
import '../../providers/order_provider.dart';
import '../../providers/reviews_provider.dart';

/// Opens the sheet. Returns true when a review was submitted.
Future<bool> showOrderReviewSheet(
  BuildContext context,
  WidgetRef ref,
  OrderModel order,
) async {
  final submitted = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _OrderReviewSheet(order: order),
  );
  if (submitted == true) {
    ref.invalidate(ordersProvider);
    ref.invalidate(myReviewsProvider);
    ref.invalidate(pendingReviewOrdersProvider);
    ref.invalidate(orderDetailsProvider(order.id));
  }
  return submitted == true;
}

class _OrderReviewSheet extends ConsumerStatefulWidget {
  const _OrderReviewSheet({required this.order});

  final OrderModel order;

  @override
  ConsumerState<_OrderReviewSheet> createState() => _OrderReviewSheetState();
}

class _OrderReviewSheetState extends ConsumerState<_OrderReviewSheet> {
  int _sellerRating = 5;
  int _driverRating = 5;
  bool _rateDriver = true;
  final _sellerComment = TextEditingController();
  final _driverComment = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _sellerComment.dispose();
    _driverComment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final (ok, message) = await ReviewService.submitOrderReview(
        widget.order.id,
        rating: _sellerRating,
        comment: _sellerComment.text,
        driverRating: _rateDriver ? _driverRating : null,
        driverComment: _rateDriver ? _driverComment.text : null,
      );
      if (!mounted) return;
      if (ok) {
        Navigator.pop(context, true);
        Helpers.showSuccessToast(message);
      } else {
        Helpers.showErrorToast(message);
      }
    } catch (e) {
      if (mounted) Helpers.showErrorToast(e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: p.borderStrong,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Rate order ${widget.order.orderNumber}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: p.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'How was your order?',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: p.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                _StarRow(
                  value: _sellerRating,
                  semanticLabel: 'Order rating',
                  onChanged: (v) =>
                      setState(() => _sellerRating = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _sellerComment,
                  maxLines: 3,
                  minLines: 2,
                  maxLength: 2000,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    hintText:
                        'Tell the seller what went well (optional)',
                    filled: true,
                    fillColor: p.inputFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: p.borderStrong),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Rate your trip',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: p.textSecondary,
                        ),
                      ),
                    ),
                    Text(
                      'Optional',
                      style: TextStyle(
                        fontSize: 12,
                        color: p.textMuted,
                      ),
                    ),
                    Switch(
                      value: _rateDriver,
                      activeThumbColor: AppColors.primary,
                      onChanged: (v) =>
                          setState(() => _rateDriver = v),
                    ),
                  ],
                ),
                if (_rateDriver) ...[
                  _StarRow(
                    value: _driverRating,
                    semanticLabel: 'Trip rating',
                    onChanged: (v) =>
                        setState(() => _driverRating = v),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _driverComment,
                    maxLines: 2,
                    minLines: 1,
                    maxLength: 2000,
                    decoration: InputDecoration(
                      hintText:
                          'How was the delivery? (optional)',
                      filled: true,
                      fillColor: p.inputFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: p.borderStrong),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Submit review',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  const _StarRow({
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$semanticLabel: $value of 5 stars',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (i) {
          final star = i + 1;
          return Semantics(
            button: true,
            label: '$star star${star == 1 ? '' : 's'}',
            child: GestureDetector(
              onTap: () => onChanged(star),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  star <= value
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  size: 40,
                  color: star <= value
                      ? AppColors.warning
                      : context.palette.iconMuted,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
