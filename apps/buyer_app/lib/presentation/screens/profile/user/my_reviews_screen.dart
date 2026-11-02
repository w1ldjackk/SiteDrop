// lib/presentation/screens/profile/user/my_reviews_screen.dart
// Ratings & Reviews hub: "To review" (delivered orders awaiting a rating —
// seller + trip) and "My reviews" (everything I wrote: products + orders).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sitedrop_core/app/routes/route_names.dart';
import 'package:sitedrop_core/app/theme/colors.dart';
import 'package:sitedrop_core/core/utils/helpers.dart';
import 'package:sitedrop_core/data/models/order.dart';
import 'package:sitedrop_core/data/models/review.dart';
import '../../../providers/reviews_provider.dart';
import '../../../widgets/buyer/order_status_chip.dart';
import '../../../widgets/common/app_back_button.dart';
import '../../../widgets/common/loading_widget.dart';
import '../../../widgets/reviews/order_review_sheet.dart';

class MyReviewsScreen extends ConsumerStatefulWidget {
  const MyReviewsScreen({super.key});

  @override
  ConsumerState<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends ConsumerState<MyReviewsScreen> {
  int _tab = 0; // 0 = To review, 1 = My reviews

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        backgroundColor: context.palette.surface,
        elevation: 0,
        title: appBarTitle(context, 'Ratings & Reviews'),
        leading: const AppBackButton(fallbackRoute: RouteNames.home),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(myReviewsProvider);
              ref.invalidate(pendingReviewOrdersProvider);
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: _SegmentTabs(
                selected: _tab,
                onChanged: (i) => setState(() => _tab = i),
              ),
            ),
            Expanded(
              child: _tab == 0
                  ? _buildToReview(context)
                  : _buildMyReviews(context),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TO REVIEW (orders/trips)
  // ============================================================
  Widget _buildToReview(BuildContext context) {
    final pendingAsync = ref.watch(pendingReviewOrdersProvider);
    return pendingAsync.when(
      data: (orders) {
        if (orders.isEmpty) return _buildNothingToReview(context);
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(pendingReviewOrdersProvider);
            await ref.read(pendingReviewOrdersProvider.future);
          },
          color: AppColors.primary,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) =>
                _buildPendingCard(context, orders[i]),
          ),
        );
      },
      loading: () =>
          const LoadingWidget(message: 'Finding orders to rate…'),
      error: (e, _) => _buildInlineError(context, () {
        ref.invalidate(pendingReviewOrdersProvider);
      }),
    );
  }

  Widget _buildPendingCard(BuildContext context, OrderModel order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.palette.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.orderNumber,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      Helpers.formatDate(order.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: context.palette.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              OrderStatusChip(status: order.status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'How was your order and delivery?',
            style: TextStyle(
              fontSize: 13,
              color: context.palette.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.push(
                    RouteNames.orderTrackingWithId(order.id),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: context.palette.borderStrong,
                    ),
                    padding:
                        const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('View order'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () => showOrderReviewSheet(
                    context,
                    ref,
                    order,
                  ),
                  icon: const Icon(Icons.star_rounded, size: 18),
                  label: const Text('Rate order'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNothingToReview(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: context.palette.surfaceMuted,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.task_alt_outlined,
                size: 54,
                color: AppColors.success,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'All caught up',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: context.palette.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Delivered orders will appear here for rating',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.palette.textMuted,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // MY REVIEWS (products + orders)
  // ============================================================
  Widget _buildMyReviews(BuildContext context) {
    final mineAsync = ref.watch(myReviewsProvider);
    return mineAsync.when(
      data: (reviews) {
        if (reviews.isEmpty) return _buildNoReviews(context);
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(myReviewsProvider);
            await ref.read(myReviewsProvider.future);
          },
          color: AppColors.primary,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: reviews.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) =>
                _buildReviewCard(context, reviews[i]),
          ),
        );
      },
      loading: () =>
          const LoadingWidget(message: 'Loading your reviews…'),
      error: (e, _) => _buildInlineError(context, () {
        ref.invalidate(myReviewsProvider);
      }),
    );
  }

  Widget _buildReviewCard(BuildContext context, MyReviewModel r) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.palette.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: context.palette.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  r.isProductReview
                      ? Icons.inventory_2_outlined
                      : Icons.receipt_long_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.subject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      r.isProductReview
                          ? 'Product review'
                          : 'Order review',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.palette.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              _StarBadge(rating: r.rating),
            ],
          ),
          if (r.comment.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              r.comment,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: context.palette.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              if (r.isVerifiedPurchase)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.successSurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Verified',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.success,
                    ),
                  ),
                ),
              const Spacer(),
              if (r.createdAt != null)
                Flexible(
                  child: Text(
                    Helpers.formatDate(r.createdAt!),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                    color: context.palette.textMuted,
                  ),
                  ),
                ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  if (r.isProductReview && r.productId != null) {
                    context.push(
                      RouteNames.productDetailWithId(r.productId!),
                    );
                  } else if (r.isOrderReview && r.orderId != null) {
                    context.push(
                      RouteNames.orderTrackingWithId(r.orderId!),
                    );
                  }
                },
                child: Text(
                  'View',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoReviews(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: context.palette.surfaceMuted,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.star_outline_rounded,
                size: 54,
                color: context.palette.iconMuted,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No reviews yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: context.palette.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Reviews you write will live here',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.palette.textMuted,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInlineError(BuildContext context, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 44,
              color: AppColors.error,
            ),
            const SizedBox(height: 12),
            Text(
              'Could not load reviews',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: context.palette.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentTabs extends StatelessWidget {
  const _SegmentTabs({required this.selected, required this.onChanged});

  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.palette.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _seg(context, 'To review', 0),
          _seg(context, 'My reviews', 1),
        ],
      ),
    );
  }

  Widget _seg(BuildContext context, String label, int index) {
    final active = selected == index;
    return Expanded(
      child: Semantics(
        button: true,
        selected: active,
        label: label,
        child: GestureDetector(
          onTap: () => onChanged(index),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: active
                  ? context.palette.surface
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 6,
                      ),
                    ]
                  : null,
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight:
                    active ? FontWeight.w700 : FontWeight.w500,
                fontSize: 14,
                color: active
                    ? context.palette.textPrimary
                    : context.palette.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StarBadge extends StatelessWidget {
  const _StarBadge({required this.rating});

  final int rating;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 14, color: AppColors.warning),
          const SizedBox(width: 2),
          Text(
            '$rating',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: context.palette.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
