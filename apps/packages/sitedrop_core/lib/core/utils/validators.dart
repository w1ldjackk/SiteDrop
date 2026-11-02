// lib/core/utils/validators.dart
// Thin wrappers around [form_builder_validators] + Ghana-specific rules.
import 'package:form_builder_validators/form_builder_validators.dart';

import 'helpers.dart';

class Validators {
  static String? required(String? value) {
    return FormBuilderValidators.required(
      errorText: 'This field is required',
    )(value);
  }

  static String? email(String? value) {
    return FormBuilderValidators.compose([
      FormBuilderValidators.required(errorText: 'Email is required'),
      FormBuilderValidators.email(
        errorText: 'Please enter a valid email address',
      ),
    ])(value);
  }

  /// Optional email — empty is OK.
  static String? optionalEmail(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return FormBuilderValidators.email(
      errorText: 'Please enter a valid email address',
    )(value);
  }

  static String? phone(String? value) {
    final requiredErr = FormBuilderValidators.required(
      errorText: 'Phone number is required',
    )(value);
    if (requiredErr != null) return requiredErr;

    final trimmed = value!.trim();
    if (!Helpers.isValidPhone(trimmed)) {
      return 'Please enter a valid phone number';
    }
    if (!Helpers.isValidGhanaPhone(trimmed)) {
      return 'Please enter a valid Ghana phone number (+233XXXXXXXXX)';
    }
    return null;
  }

  /// Optional phone — empty is OK, otherwise Ghana-valid.
  static String? optionalPhone(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final trimmed = value.trim();
    if (!Helpers.isValidPhone(trimmed)) {
      return 'Please enter a valid phone number';
    }
    if (!Helpers.isValidGhanaPhone(trimmed)) {
      return 'Please enter a valid Ghana phone number (+233XXXXXXXXX)';
    }
    return null;
  }

  static String? password(String? value) {
    return FormBuilderValidators.compose([
      FormBuilderValidators.required(errorText: 'Password is required'),
      FormBuilderValidators.minLength(
        6,
        errorText: 'Password must be at least 6 characters',
      ),
    ])(value);
  }

  static String? passwordConfirmation(String? value, String password) {
    final requiredErr = FormBuilderValidators.required(
      errorText: 'Please confirm your password',
    )(value);
    if (requiredErr != null) return requiredErr;
    return FormBuilderValidators.equal(
      password,
      errorText: 'Passwords do not match',
    )(value);
  }

  static String? Function(String? value) minLengthValidator(int minLength) {
    return FormBuilderValidators.compose([
      FormBuilderValidators.required(errorText: 'This field is required'),
      FormBuilderValidators.minLength(
        minLength,
        errorText: 'Must be at least $minLength characters',
      ),
    ]);
  }

  static String? Function(String? value) maxLengthValidator(int maxLength) {
    return (String? value) {
      if (value == null || value.isEmpty) return null;
      return FormBuilderValidators.maxLength(
        maxLength,
        errorText: 'Must not exceed $maxLength characters',
      )(value);
    };
  }

  static String? numeric(String? value) {
    return FormBuilderValidators.compose([
      FormBuilderValidators.required(errorText: 'This field is required'),
      FormBuilderValidators.numeric(errorText: 'Please enter a valid number'),
    ])(value);
  }

  static String? positiveNumber(String? value) {
    return FormBuilderValidators.compose([
      FormBuilderValidators.required(errorText: 'This field is required'),
      FormBuilderValidators.numeric(errorText: 'Please enter a valid number'),
      FormBuilderValidators.min(
        0.000001,
        errorText: 'Must be greater than 0',
      ),
    ])(value);
  }

  static String? Function(String? value) minValue(double min) {
    return FormBuilderValidators.compose([
      FormBuilderValidators.required(errorText: 'This field is required'),
      FormBuilderValidators.numeric(errorText: 'Please enter a valid number'),
      FormBuilderValidators.min(min, errorText: 'Must be at least $min'),
    ]);
  }

  static String? Function(String? value) maxValue(double max) {
    return FormBuilderValidators.compose([
      FormBuilderValidators.required(errorText: 'This field is required'),
      FormBuilderValidators.numeric(errorText: 'Please enter a valid number'),
      FormBuilderValidators.max(max, errorText: 'Must not exceed $max'),
    ]);
  }

  static String? url(String? value) {
    return FormBuilderValidators.compose([
      FormBuilderValidators.required(errorText: 'URL is required'),
      FormBuilderValidators.url(errorText: 'Please enter a valid URL'),
    ])(value);
  }

  // Alias for required - for backward compatibility
  static String? get requiredField => required(null);
}
