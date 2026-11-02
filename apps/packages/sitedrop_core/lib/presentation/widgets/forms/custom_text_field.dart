// lib/presentation/widgets/forms/custom_text_field.dart
import 'package:flutter/material.dart';

import 'package:sitedrop_core/app/theme/colors.dart';
import 'package:sitedrop_core/app/theme/input_styles.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? errorText;
  final String? helperText;
  final bool obscureText;
  final bool enabled;
  final bool readOnly;
  final bool autofocus;
  final int? maxLength;
  final int? maxLines;
  final int? minLines;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final Widget? prefix;
  final Widget? suffix;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final FocusNode? focusNode;
  final EdgeInsetsGeometry? contentPadding;

  const CustomTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.errorText,
    this.helperText,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.maxLength,
    this.maxLines = 1,
    this.minLines,
    this.keyboardType,
    this.textInputAction,
    this.prefixIcon,
    this.suffixIcon,
    this.prefix,
    this.suffix,
    this.validator,
    this.onChanged,
    this.onTap,
    this.focusNode,
    this.contentPadding,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label!, style: InputStyles.label(context)),
          const SizedBox(height: 8),
        ],
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscureText,
          enabled: enabled,
          readOnly: readOnly,
          autofocus: autofocus,
          maxLength: maxLength,
          maxLines: maxLines,
          minLines: minLines,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          validator: validator,
          onChanged: onChanged,
          onTap: onTap,
          style: enabled
              ? InputStyles.text(context)
              : InputStyles.textDisabled(context),
          cursorColor: AppColors.primary,
          decoration:
              InputStyles.decoration(
                context,
                hintText: hint,
                errorText: errorText,
                helperText: helperText,
                prefixIcon: prefixIcon,
                suffixIcon: suffixIcon,
              ).copyWith(
                contentPadding:
                    contentPadding ??
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                fillColor: enabled ? p.inputFill : p.surfaceMuted,
                prefix: prefix,
                suffix: suffix,
              ),
        ),
      ],
    );
  }
}
