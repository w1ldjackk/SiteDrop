// lib/presentation/widgets/forms/custom_dropdown.dart
import 'package:flutter/material.dart';

import 'package:sitedrop_core/app/theme/app_palette.dart';
import 'package:sitedrop_core/app/theme/colors.dart';
import 'package:sitedrop_core/app/theme/input_styles.dart';

class CustomDropdown<T> extends StatelessWidget {
  final T? value;
  final String? label;
  final String? hint;
  final String? errorText;
  final List<Map<String, String>> items;
  final ValueChanged<T?>? onChanged;
  final FormFieldValidator<T>? validator;
  final bool enabled;
  final Widget? prefixIcon;
  final EdgeInsetsGeometry? contentPadding;

  const CustomDropdown({
    super.key,
    this.value,
    this.label,
    this.hint,
    this.errorText,
    required this.items,
    this.onChanged,
    this.validator,
    this.enabled = true,
    this.prefixIcon,
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
        DropdownButtonFormField<T>(
          initialValue: value,
          isExpanded: true,
          hint: hint != null
              ? Text(hint!, style: InputStyles.hint(context))
              : null,
          style: InputStyles.text(context),
          dropdownColor: p.surfaceElevated,
          icon: Icon(
            Icons.arrow_drop_down,
            color: enabled ? p.inputIcon : p.textDisabled,
          ),
          decoration: InputStyles.decoration(
            context,
            errorText: errorText,
            prefixIcon: prefixIcon,
          ).copyWith(
            contentPadding: contentPadding ??
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            fillColor: enabled ? p.inputFill : p.surfaceMuted,
          ),
          items: items.map((item) {
            return DropdownMenuItem<T>(
              value: item['value'] as T?,
              child: Text(
                item['label'] ?? '',
                style: InputStyles.text(context),
              ),
            );
          }).toList(),
          onChanged: enabled ? onChanged : null,
          validator: validator,
        ),
      ],
    );
  }
}
