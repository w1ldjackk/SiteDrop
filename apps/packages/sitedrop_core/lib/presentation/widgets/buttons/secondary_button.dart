// lib/presentation/widgets/buttons/secondary_button.dart
import 'package:flutter/material.dart';

import 'package:sitedrop_core/app/theme/colors.dart';

class SecondaryButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String text;
  final bool isLoading;
  final bool isFullWidth;
  final double? width;
  final double? height;
  final Color? borderColor;
  final Color? textColor;
  final Color? disabledColor;
  final IconData? icon;
  final double? fontSize;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;

  const SecondaryButton({
    super.key,
    required this.onPressed,
    required this.text,
    this.isLoading = false,
    this.isFullWidth = true,
    this.width,
    this.height,
    this.borderColor,
    this.textColor,
    this.disabledColor,
    this.icon,
    this.fontSize,
    this.padding,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final button = OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: textColor ?? AppColors.primary,
        side: BorderSide(color: borderColor ?? AppColors.primary, width: 1.5),
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
                color: textColor ?? AppColors.primary,
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
