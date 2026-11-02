import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:toastification/toastification.dart';

import '../../data/services/api_service.dart';
import 'toast_service.dart';

class Helpers {
  /// Human-readable message from API / Dio / generic errors (for toasts & UI).
  static String errorMessage(
    Object? error, {
    String fallback = 'Something went wrong. Please try again.',
  }) {
    if (error == null) return fallback;
    final message = ApiService.messageFromError(error).trim();
    if (message.isEmpty) return fallback;
    return message;
  }

  // ============================================================
  // TOAST METHODS - Now using ToastService
  // ============================================================

  /// Show a toast notification with customizable options
  /// @deprecated Use the specific toast methods instead (showSuccessToast, showErrorToast, etc.)
  @Deprecated('Use showSuccessToast, showErrorToast, or showInfoToast instead')
  static void showToast({
    required String message,
    // Parameters kept for backward compatibility but ignored
    dynamic gravity,
    Color? backgroundColor,
    Color? textColor,
    int duration = 3,
  }) {
    // Default to info toast for backward compatibility
    // Using the new ToastService with default settings
    ToastService.showWithoutContext(
      message,
      type: ToastificationType.info,
      title: 'Notification',
      duration: Duration(seconds: duration),
    );
  }

  /// Show a success toast notification
  static void showSuccessToast(
    String message, {
    String title = 'Success',
    Duration duration = const Duration(milliseconds: 2500),
  }) {
    ToastService.showWithoutContext(
      message,
      type: ToastificationType.success,
      title: title,
      duration: duration,
    );
  }

  /// Show an error toast notification.
  /// Pass either a user string or any [error] object (Dio/API/Exception).
  static void showErrorToast(
    Object messageOrError, {
    String title = 'Error',
    Duration duration = const Duration(milliseconds: 3500),
  }) {
    // Always normalize so raw Dio / Exception: prefixes never hit the UI
    final text = errorMessage(messageOrError);

    ToastService.showWithoutContext(
      text,
      type: ToastificationType.error,
      title: title,
      duration: duration,
    );
  }

  /// Show an info toast notification
  static void showInfoToast(
    String message, {
    String title = 'Info',
    Duration duration = const Duration(milliseconds: 2500),
  }) {
    ToastService.showWithoutContext(
      message,
      type: ToastificationType.info,
      title: title,
      duration: duration,
    );
  }

  /// Show a warning toast notification
  static void showWarningToast(
    String message, {
    String title = 'Warning',
    Duration duration = const Duration(seconds: 3),
  }) {
    ToastService.showWithoutContext(
      message,
      type: ToastificationType.warning,
      title: title,
      duration: duration,
    );
  }

  /// Show a Ghana-themed success toast (celebratory)
  static void showGhanaSuccessToast(
    String message, {
    String title = 'Success! 🇬🇭',
    Duration duration = const Duration(milliseconds: 3500),
  }) {
    // Note: showGhanaSuccess requires BuildContext
    // For context-less usage, we'll use a themed success
    ToastService.showWithoutContext(
      message,
      type: ToastificationType.success,
      title: title,
      duration: duration,
    );
  }

  // ============================================================
  // PHONE NUMBER FORMATTING
  // ============================================================

  static String formatPhoneNumber(String phone) {
    // Remove all non-digit characters
    String cleaned = phone.replaceAll(RegExp(r'\D'), '');

    // Handle different formats
    if (cleaned.isEmpty) {
      return phone;
    }

    // If it already has +233 format, convert to the expected format
    if (cleaned.startsWith('233') && cleaned.length == 12) {
      // Remove 233 prefix and add 0 for validation
      return '0${cleaned.substring(3)}';
    }

    // If it starts with 0 and has 10 digits, keep as is
    if (cleaned.startsWith('0') && cleaned.length == 10) {
      return cleaned;
    }

    // If it has 9 digits (missing leading 0), add it
    if (cleaned.length == 9) {
      return '0$cleaned';
    }

    // If it has 10 digits without leading 0, add 0
    if (cleaned.length == 10 && !cleaned.startsWith('0')) {
      return '0$cleaned';
    }

    // If it has 12 digits starting with 233, convert to 0 format
    if (cleaned.startsWith('233') && cleaned.length == 12) {
      return '0${cleaned.substring(3)}';
    }

    return phone;
  }

  static String formatPhoneDisplay(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'\D'), '');
    if (cleaned.length == 10 && cleaned.startsWith('0')) {
      return '${cleaned.substring(0, 3)} ${cleaned.substring(3, 6)} ${cleaned.substring(6)}';
    } else if (cleaned.startsWith('233') && cleaned.length == 12) {
      return '+${cleaned.substring(0, 3)} ${cleaned.substring(3, 6)} ${cleaned.substring(6, 9)} ${cleaned.substring(9)}';
    }
    return phone;
  }

  // ============================================================
  // PRICE FORMATTING
  // ============================================================

  static String formatPrice(double price) {
    final formatter = NumberFormat.currency(symbol: 'GHS ', decimalDigits: 2);
    return formatter.format(price);
  }

  // ============================================================
  // DATE FORMATTING
  // ============================================================

  static String formatDate(DateTime date) {
    final formatter = DateFormat('dd MMM yyyy, hh:mm a');
    return formatter.format(date);
  }

  static String formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      return formatDate(date);
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  // ============================================================
  // STRING HELPERS
  // ============================================================

  static String getInitials(String name) {
    if (name.isEmpty) return '';

    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, 1).toUpperCase();
  }

  // ============================================================
  // VALIDATION HELPERS
  // ============================================================

  static bool isValidEmail(String email) {
    return RegExp(
      r'^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$',
    ).hasMatch(email);
  }

  static bool isValidPhone(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'\s+'), '');
    return RegExp(r'^(\+233|0)[0-9]{9}$').hasMatch(cleaned) ||
        RegExp(r'^[0-9]{10}$').hasMatch(cleaned);
  }

  static bool isValidGhanaPhone(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'\s+'), '');
    return RegExp(r'^(\+233|0)([2357][0-9]{8})$').hasMatch(cleaned);
  }

  // ============================================================
  // MASKING HELPERS
  // ============================================================

  static String maskEmail(String email) {
    if (!email.contains('@')) return email;
    final parts = email.split('@');
    final name = parts[0];
    final domain = parts[1];

    if (name.length <= 2) return email;

    final visible = name.substring(0, 2);
    return '$visible...@$domain';
  }

  static String maskPhone(String phone) {
    if (phone.length <= 6) return phone;
    final visible = phone.substring(0, 4);
    final masked = phone.substring(4);
    return '$visible${'*' * masked.length}';
  }

  // ============================================================
  // THEME & RESPONSIVE HELPERS
  // ============================================================

  static bool isDarkMode(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  static double getScreenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  static double getScreenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  static bool isSmallScreen(BuildContext context) {
    return getScreenWidth(context) < 600;
  }

  static bool isMediumScreen(BuildContext context) {
    return getScreenWidth(context) >= 600 && getScreenWidth(context) < 900;
  }

  static bool isLargeScreen(BuildContext context) {
    return getScreenWidth(context) >= 900;
  }
}
