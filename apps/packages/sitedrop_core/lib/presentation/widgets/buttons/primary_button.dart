// lib/presentation/widgets/buttons/primary_button.dart
import 'package:flutter/material.dart';

import 'package:sitedrop_core/app/theme/colors.dart';

class PrimaryButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String text;
  final bool isLoading;
  final bool isFullWidth;
  final double? width;
  final double? height;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? disabledColor;
  final IconData? icon;
  final double? fontSize;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;

  const PrimaryButton({
    super.key,
    required this.onPressed,
    required this.text,
    this.isLoading = false,
    this.isFullWidth = true,
    this.width,
    this.height,
    this.backgroundColor,
    this.foregroundColor,
    this.disabledColor,
    this.icon,
    this.fontSize,
    this.padding,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final button = FilledButton(
      onPressed: isLoading ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: backgroundColor ??
            (isDark ? AppColors.primaryLight : AppColors.primary),
        foregroundColor: foregroundColor ?? AppColors.white,
        disabledBackgroundColor: disabledColor ??
            (isDark ? AppColors.grey700 : AppColors.grey300),
        disabledForegroundColor:
            isDark ? AppColors.grey400 : AppColors.grey500,
        minimumSize: Size(
          isFullWidth ? double.infinity : (width ?? 200),
          height ?? 48,
        ),
        padding:
            padding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius ?? BorderRadius.circular(12),
        ),
        textStyle: TextStyle(
          fontSize: fontSize ?? 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      child: isLoading
          ? SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: foregroundColor ?? AppColors.white,
                strokeWidth: 2,
              ),
            )
          : Row(
              mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20),
                  const SizedBox(width: 8),
                ],
                Text(text),
              ],
            ),
    );

    if (!isFullWidth && width == null) {
      return Center(child: button);
    }

    return button;
  }
}
