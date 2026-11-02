// lib/presentation/widgets/buttons/social_button.dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:sitedrop_core/app/theme/colors.dart';

class SocialButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String text;
  final FaIconData icon;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? iconColor;

  const SocialButton({
    super.key,
    required this.onPressed,
    required this.text,
    required this.icon,
    this.backgroundColor,
    this.textColor,
    this.iconColor,
  });

  /// Google OAuth-style button (Font Awesome brand icon).
  factory SocialButton.google({
    Key? key,
    required VoidCallback? onPressed,
    String text = 'Google',
  }) {
    return SocialButton(
      key: key,
      onPressed: onPressed,
      text: text,
      icon: FontAwesomeIcons.google,
      iconColor: const Color(0xFFDB4437),
    );
  }

  /// Apple Sign-In style button.
  factory SocialButton.apple({
    Key? key,
    required VoidCallback? onPressed,
    String text = 'Apple',
  }) {
    return SocialButton(
      key: key,
      onPressed: onPressed,
      text: text,
      icon: FontAwesomeIcons.apple,
      iconColor: AppColors.black,
    );
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: FaIcon(icon, color: iconColor ?? AppColors.grey700, size: 18),
      label: Text(
        text,
        style: TextStyle(
          color: textColor ?? AppColors.grey700,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      style: OutlinedButton.styleFrom(
        backgroundColor: backgroundColor ?? AppColors.white,
        foregroundColor: textColor ?? AppColors.grey700,
        side: BorderSide(color: AppColors.grey200),
        minimumSize: const Size(double.infinity, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
