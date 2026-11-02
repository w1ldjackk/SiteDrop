// lib/app/theme/input_styles.dart
// Theme-aware input / text styles for light + dark.
import 'package:flutter/material.dart';

import 'colors.dart';

class InputStyles {
  InputStyles._();

  static TextStyle text(BuildContext context) {
    final p = context.palette;
    return TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: p.textPrimary,
      height: 1.35,
    );
  }

  static TextStyle textDisabled(BuildContext context) {
    final p = context.palette;
    return TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: p.textDisabled,
      height: 1.35,
    );
  }

  static TextStyle hint(BuildContext context) {
    final p = context.palette;
    return TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w400,
      color: p.inputHint,
      height: 1.35,
    );
  }

  static TextStyle label(BuildContext context) {
    final p = context.palette;
    return TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: p.textSecondary,
    );
  }

  static TextStyle section(BuildContext context) {
    final p = context.palette;
    return TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: p.textMuted,
      letterSpacing: 0.4,
    );
  }

  static InputDecoration decoration(
    BuildContext context, {
    String? hintText,
    String? labelText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    String? errorText,
    String? helperText,
  }) {
    final p = context.palette;
    final radius = BorderRadius.circular(12);

    return InputDecoration(
      hintText: hintText,
      labelText: labelText,
      errorText: errorText,
      helperText: helperText,
      hintStyle: hint(context),
      labelStyle: label(context),
      floatingLabelStyle: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.primary,
      ),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      prefixIconColor: p.inputIcon,
      suffixIconColor: p.inputIcon,
      filled: true,
      fillColor: p.inputFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: p.inputBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: p.inputBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: AppColors.error, width: 2),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: p.border),
      ),
      errorStyle: TextStyle(fontSize: 12, color: AppColors.error),
      helperStyle: TextStyle(fontSize: 12, color: p.textMuted),
    );
  }
}
