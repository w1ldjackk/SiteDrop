// lib/presentation/screens/auth/auth_theme.dart
// Shared light/dark styles for auth screens.
import 'package:flutter/material.dart';

import 'package:sitedrop_core/app/theme/colors.dart';

/// Theme-aware decoration + text helpers for login/register/OTP screens.
class AuthTheme {
  AuthTheme._();

  static Color scaffoldBg(BuildContext context) => context.palette.background;

  static TextStyle title(BuildContext context, {double size = 32}) {
    return TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w700,
      color: context.palette.textPrimary,
    );
  }

  static TextStyle subtitle(BuildContext context) {
    return TextStyle(
      fontSize: 16,
      color: context.palette.textMuted,
      height: 1.4,
    );
  }

  static TextStyle label(BuildContext context) {
    return TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 14,
      color: context.palette.textSecondary,
    );
  }

  static TextStyle fieldText(BuildContext context) {
    return TextStyle(fontSize: 16, color: context.palette.textPrimary);
  }

  static TextStyle muted(BuildContext context, {double size = 14}) {
    return TextStyle(fontSize: size, color: context.palette.textMuted);
  }

  static InputDecoration field(
    BuildContext context, {
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
    bool dense = false,
  }) {
    final p = context.palette;
    final radius = BorderRadius.circular(14);

    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: p.inputHint, fontSize: 15),
      prefixIcon: Icon(icon, color: p.inputIcon),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: p.inputFill,
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: p.inputBorder, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: p.inputBorder, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: AppColors.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: AppColors.error, width: 2),
      ),
      contentPadding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: dense ? 12 : 16,
      ),
    );
  }

  /// Decoration for a single OTP digit box (digits fully visible).
  static InputDecoration otpBox(BuildContext context) {
    final p = context.palette;
    final radius = BorderRadius.circular(12);
    return InputDecoration(
      counterText: '',
      isDense: true,
      filled: true,
      fillColor: p.inputFill,
      contentPadding: EdgeInsets.zero,
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: p.inputBorder, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: p.inputBorder, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: p.border, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: AppColors.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: AppColors.error, width: 2),
      ),
    );
  }
}
