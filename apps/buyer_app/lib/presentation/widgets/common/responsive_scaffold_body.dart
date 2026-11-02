// lib/presentation/widgets/common/responsive_scaffold_body.dart
// Centers content and applies horizontal padding that scales with screen width.
import 'package:flutter/material.dart';

import '../../../core/extensions/context_extensions.dart';

/// Product-card style grids: 2 (phone) / 3 (tablet) / 4 (desktop width).
int responsiveProductGridCount(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  if (w >= 900) return 4;
  if (w >= 600) return 3;
  return 2;
}

/// Category chips/tiles: 3 (phone) / 4 (tablet) / 5 (wide).
int responsiveCategoryGridCount(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  if (w >= 900) return 5;
  if (w >= 600) return 4;
  return 3;
}

/// Wrap a screen body so content stays usable from narrow phones to tablets:
/// - horizontal padding from [ContextExtensions.pagePaddingH]
/// - optional max width ([ContextExtensions.contentMaxWidth]) centered on large screens
class ResponsiveScaffoldBody extends StatelessWidget {
  final Widget child;
  final bool scrollable;
  final EdgeInsetsGeometry? padding;
  final bool applyMaxWidth;
  final ScrollPhysics? physics;

  const ResponsiveScaffoldBody({
    super.key,
    required this.child,
    this.scrollable = false,
    this.padding,
    this.applyMaxWidth = true,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    final hPad = context.pagePaddingH;
    final pad = padding ?? EdgeInsets.symmetric(horizontal: hPad);

    Widget content = Padding(padding: pad, child: child);

    if (applyMaxWidth && context.contentMaxWidth.isFinite) {
      content = Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: context.contentMaxWidth),
          child: content,
        ),
      );
    }

    if (scrollable) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: physics ?? const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: content,
            ),
          );
        },
      );
    }

    return content;
  }
}

/// Centers empty/error states and makes them scrollable on short screens.
class ResponsiveCenteredState extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const ResponsiveCenteredState({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final minH =
            (constraints.maxHeight - padding.vertical).clamp(0.0, double.infinity);
        return SingleChildScrollView(
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: minH,
              maxWidth: context.contentMaxWidth.isFinite
                  ? context.contentMaxWidth
                  : constraints.maxWidth,
            ),
            child: Center(child: child),
          ),
        );
      },
    );
  }
}
