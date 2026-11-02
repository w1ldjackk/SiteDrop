// lib/presentation/widgets/common/loading_widget.dart
// Global modern loading (Jumia / AliExpress style):
// shimmer app-layout skeleton + floating brand indicator.
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import 'package:sitedrop_core/app/theme/colors.dart';

/// How [LoadingWidget] renders.
enum LoadingStyle {
  /// Full-screen skeleton layout + brand badge (default for pages).
  page,

  /// Compact spinner for inline / small slots (image placeholders, etc.).
  compact,

  /// Dimmed glass overlay — use with [LoadingOverlay] over existing UI.
  overlay,
}

/// Global app loading indicator.
///
/// Default (`LoadingStyle.page`) shows a shimmering marketplace layout with a
/// centered SiteDrop badge — similar to Jumia / AliExpress first paint.
class LoadingWidget extends StatelessWidget {
  final String? message;
  final Color? color;
  final LoadingStyle style;

  const LoadingWidget({
    super.key,
    this.message,
    this.color,
    this.style = LoadingStyle.page,
  });

  /// Small spinner for image cells / list tiles.
  const LoadingWidget.compact({super.key, this.color})
    : message = null,
      style = LoadingStyle.compact;

  /// Floating badge only (no skeleton bones).
  const LoadingWidget.overlay({super.key, this.message, this.color})
    : style = LoadingStyle.overlay;

  @override
  Widget build(BuildContext context) {
    switch (style) {
      case LoadingStyle.compact:
        return _CompactLoader(color: color);
      case LoadingStyle.overlay:
        return _BrandBadge(message: message, color: color);
      case LoadingStyle.page:
        return _PageSkeletonLoader(message: message, accent: color);
    }
  }
}

// =============================================================================
// COMPACT
// =============================================================================

class _CompactLoader extends StatelessWidget {
  final Color? color;
  const _CompactLoader({this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: color ?? AppColors.primary,
        ),
      ),
    );
  }
}

// =============================================================================
// PAGE SKELETON (blurred layout + brand)
// =============================================================================

class _PageSkeletonLoader extends StatelessWidget {
  final String? message;
  final Color? accent;

  const _PageSkeletonLoader({this.message, this.accent});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? p.surfaceMuted : const Color(0xFFE8E8E8);
    final highlight = isDark ? p.surfaceElevated : const Color(0xFFF5F5F5);
    final mq = MediaQuery.sizeOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : mq.width;
        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : mq.height;

        return SizedBox(
          width: width,
          height: height,
          child: ColoredBox(
            color: p.background,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Shimmering “app layout” bones
                Shimmer.fromColors(
                  baseColor: base,
                  highlightColor: highlight,
                  period: const Duration(milliseconds: 1400),
                  child: const SafeArea(child: _MarketplaceSkeletonLayout()),
                ),

                // Soft frosted veil so bones feel “blurry”
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 1.2, sigmaY: 1.2),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: p.background.withValues(alpha: isDark ? 0.25 : 0.18),
                      ),
                    ),
                  ),
                ),

                // Center brand loading badge
                Center(
                  child: _BrandBadge(message: message, color: accent),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Placeholder layout that mirrors a typical SiteDrop marketplace screen.
class _MarketplaceSkeletonLayout extends StatelessWidget {
  const _MarketplaceSkeletonLayout();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // App bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              const _Bone(width: 36, height: 36, radius: 18),
              const SizedBox(width: 12),
              const Expanded(child: _Bone(height: 18, radius: 8)),
              const SizedBox(width: 12),
              const _Bone(width: 36, height: 36, radius: 18),
              const SizedBox(width: 8),
              const _Bone(width: 36, height: 36, radius: 18),
            ],
          ),
        ),
        // Search bar
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: _Bone(height: 44, radius: 14),
        ),
        // Category chips
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 5,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, _) =>
                const _Bone(width: 72, height: 32, radius: 16),
          ),
        ),
        const SizedBox(height: 16),
        // Banner
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: _Bone(height: 120, radius: 16),
        ),
        const SizedBox(height: 16),
        // Section title
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: _Bone(width: 140, height: 16, radius: 6),
        ),
        const SizedBox(height: 12),
        // Product grid
        Expanded(
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.72,
            ),
            itemCount: 4,
            itemBuilder: (_, _) => const _ProductCardBone(),
          ),
        ),
        // Bottom nav
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(
              5,
              (_) => const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Bone(width: 24, height: 24, radius: 6),
                  SizedBox(height: 6),
                  _Bone(width: 36, height: 8, radius: 4),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProductCardBone extends StatelessWidget {
  const _ProductCardBone();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _Bone(radius: 14)),
        SizedBox(height: 8),
        _Bone(height: 12, radius: 4),
        SizedBox(height: 6),
        _Bone(width: 80, height: 12, radius: 4),
        SizedBox(height: 6),
        _Bone(width: 56, height: 14, radius: 4),
      ],
    );
  }
}

class _Bone extends StatelessWidget {
  final double? width;
  final double? height;
  final double radius;

  const _Bone({this.width, this.height, this.radius = 8});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

// =============================================================================
// BRAND BADGE (pulsing logo + optional message)
// =============================================================================

class _BrandBadge extends StatefulWidget {
  final String? message;
  final Color? color;

  const _BrandBadge({this.message, this.color});

  @override
  State<_BrandBadge> createState() => _BrandBadgeState();
}

class _BrandBadgeState extends State<_BrandBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _scale = Tween<double>(
      begin: 0.94,
      end: 1.06,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _opacity = Tween<double>(
      begin: 0.55,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final accent = widget.color ?? AppColors.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FadeTransition(
          opacity: _opacity,
          child: ScaleTransition(
            scale: _scale,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: p.surface.withValues(alpha: 0.95),
                shape: BoxShape.circle,
                border: Border.all(color: p.border),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.22),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: p.shadow,
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: accent.withValues(alpha: 0.85),
                    ),
                  ),
                  Icon(Icons.construction_rounded, color: accent, size: 28),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'SiteDrop',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: p.textPrimary,
            letterSpacing: 0.4,
          ),
        ),
        if (widget.message != null && widget.message!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              widget.message!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: p.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// =============================================================================
// OVERLAY (for blocking actions on existing content)
// =============================================================================

class LoadingOverlay extends ConsumerWidget {
  final Widget child;
  final bool isLoading;
  final String? message;

  const LoadingOverlay({
    super.key,
    required this.child,
    required this.isLoading,
    this.message,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;

    return Stack(
      children: [
        child,
        if (isLoading)
          Positioned.fill(
            child: AbsorbPointer(
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                  child: ColoredBox(
                    color: p.scrim.withValues(alpha: 0.35),
                    child: Center(
                      child: LoadingWidget.overlay(message: message),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Wraps content with a shimmer while [isLoading] is true.
class ShimmerLoading extends StatelessWidget {
  final Widget child;
  final bool isLoading;

  const ShimmerLoading({super.key, required this.child, this.isLoading = true});

  @override
  Widget build(BuildContext context) {
    if (!isLoading) return child;

    final p = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Shimmer.fromColors(
      baseColor: isDark ? p.surfaceMuted : const Color(0xFFE0E0E0),
      highlightColor: isDark ? p.surfaceElevated : const Color(0xFFF5F5F5),
      child: child,
    );
  }
}

/// Convenience full-screen route body while a FutureProvider loads.
class AppPageLoader extends StatelessWidget {
  final String? message;

  const AppPageLoader({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return LoadingWidget(message: message);
  }
}
