// lib/core/extensions/string_extensions.dart
import 'package:sitedrop_core/core/utils/formatters.dart';

extension StringExtensions on String {
  bool get isValidEmail {
    return RegExp(
      r'^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$',
    ).hasMatch(this);
  }

  bool get isValidPhone {
    final cleaned = replaceAll(RegExp(r'\s+'), '');
    return RegExp(r'^(\+233|0)[0-9]{9}$').hasMatch(cleaned) ||
        RegExp(r'^[0-9]{10}$').hasMatch(cleaned);
  }

  bool get isValidGhanaPhone {
    final cleaned = replaceAll(RegExp(r'\s+'), '');
    return RegExp(r'^(\+233|0)([2357][0-9]{8})$').hasMatch(cleaned);
  }

  bool get isValidUrl {
    return Uri.parse(this).isAbsolute;
  }

  bool get isNumeric {
    return double.tryParse(this) != null;
  }

  bool get isInt {
    return int.tryParse(this) != null;
  }

  String get capitalize {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
  }

  String get titleCase {
    if (isEmpty) return this;
    return split(' ').map((word) => word.capitalize).join(' ');
  }

  String get snakeCase {
    if (isEmpty) return this;
    return replaceAllMapped(
      RegExp(r'[A-Z]'),
      (match) => '_${match.group(0)!.toLowerCase()}',
    ).toLowerCase();
  }

  String get camelCase {
    if (isEmpty) return this;
    final parts = split('_');
    return parts.first + parts.skip(1).map((part) => part.capitalize).join('');
  }

  String get truncate {
    if (length <= 50) return this;
    return '${substring(0, 50)}...';
  }

  String truncateWithLength(int maxLength) {
    if (length <= maxLength) return this;
    return '${substring(0, maxLength)}...';
  }

  // FIXED: Removed the invalid parameter
  String get formatPhone {
    return Formatters.formatPhoneNumber(this);
  }

  String get formatPhoneDisplay {
    return Formatters.formatPhoneDisplay(this);
  }

  String get toOrderCode {
    return Formatters.formatOrderCode(this);
  }

  String get removeWhitespace {
    return replaceAll(RegExp(r'\s+'), '');
  }

  String get removeSpecialChars {
    return replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '');
  }

  bool get isEmptyOrNull {
    return isEmpty || trim().isEmpty;
  }

  bool get isNotEmptyOrNull {
    return !isEmptyOrNull;
  }
}
