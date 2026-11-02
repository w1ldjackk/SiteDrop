import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

import '../../app/theme/colors.dart';
import 'app_logger.dart';

/// Centralized toast service — modern compact style (Bolt/Uber-like).
///
/// One shared renderer for every toast: small top-floating card, tinted
/// icon dot, message-first (redundant "Success"/"Error" titles are hidden
/// unless the caller passes a custom one), no progress bar, swipe/click
/// to dismiss. Public API is unchanged, so all call sites keep working.
class ToastService {
  // Private constructor to prevent instantiation
  ToastService._();

  /// Default titles per type — hidden when the caller passes the default.
  static String _defaultTitleFor(ToastificationType type) {
    if (type == ToastificationType.success) return 'Success';
    if (type == ToastificationType.error) return 'Error';
    if (type == ToastificationType.warning) return 'Warning';
    return 'Info';
  }

  /// Shows a success toast notification
  static void showSuccess(
    BuildContext context,
    String message, {
    String title = 'Success',
    Duration duration = const Duration(milliseconds: 2500),
  }) {
    _showToast(
      context: context,
      title: title,
      message: message,
      type: ToastificationType.success,
      duration: duration,
      isDark: Theme.of(context).brightness == Brightness.dark,
    );
  }

  /// Shows an error toast notification
  static void showError(
    BuildContext context,
    String message, {
    String title = 'Error',
    Duration duration = const Duration(milliseconds: 3500),
  }) {
    _showToast(
      context: context,
      title: title,
      message: message,
      type: ToastificationType.error,
      duration: duration,
      isDark: Theme.of(context).brightness == Brightness.dark,
    );
  }

  /// Shows an info toast notification
  static void showInfo(
    BuildContext context,
    String message, {
    String title = 'Info',
    Duration duration = const Duration(milliseconds: 2500),
  }) {
    _showToast(
      context: context,
      title: title,
      message: message,
      type: ToastificationType.info,
      duration: duration,
      isDark: Theme.of(context).brightness == Brightness.dark,
    );
  }

  /// Shows a warning toast notification
  static void showWarning(
    BuildContext context,
    String message, {
    String title = 'Warning',
    Duration duration = const Duration(seconds: 3),
  }) {
    _showToast(
      context: context,
      title: title,
      message: message,
      type: ToastificationType.warning,
      duration: duration,
      isDark: Theme.of(context).brightness == Brightness.dark,
    );
  }

  /// Core method to display toast with theme-aware styling
  static void _showToast({
    required BuildContext context,
    required String title,
    required String message,
    required ToastificationType type,
    required Duration duration,
    required bool isDark,
  }) {
    final colors = _getToastColors(type, isDark);
    final showTitle = title.trim().isNotEmpty &&
        title.trim() != _defaultTitleFor(type);

    toastification.show(
      context: context,
      title: showTitle ? _titleText(title, colors.primary) : null,
      description: _messageText(message, colors.foreground),
      type: type,
      style: ToastificationStyle.flat,
      alignment: Alignment.topCenter,
      autoCloseDuration: duration,
      animationDuration: const Duration(milliseconds: 250),
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(
        color: colors.primary.withValues(alpha: 0.22),
      ),
      primaryColor: colors.primary,
      backgroundColor: colors.background,
      foregroundColor: colors.foreground,
      icon: _leadingIcon(type, colors.primary),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      margin: const EdgeInsets.only(top: 12, left: 16, right: 16),
      sizeConstraints: const BoxConstraints(maxWidth: 480),
      boxShadow: [
        BoxShadow(
          color: colors.shadowColor,
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
      showProgressBar: false,
      dragToClose: true,
      applyBlurEffect: false,
      closeButton:
          const ToastCloseButton(showType: CloseButtonShowType.none),
      closeOnClick: true,
      pauseOnHover: true,
    );
  }

  /// Message-first body — the part users actually read.
  static Widget _messageText(String message, Color color) {
    return Text(
      message,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.35,
        color: color,
      ),
    );
  }

  /// Small accent label, only for custom titles.
  static Widget _titleText(String title, Color color) {
    return Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
        color: color,
      ),
    );
  }

  /// Tinted icon dot — one consistent look for every type.
  static Widget _leadingIcon(ToastificationType type, Color color) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(_iconFor(type), size: 20, color: color),
    );
  }

  static IconData _iconFor(ToastificationType type) {
    if (type == ToastificationType.success) {
      return Icons.check_circle_rounded;
    }
    if (type == ToastificationType.error) return Icons.error_rounded;
    if (type == ToastificationType.warning) return Icons.warning_rounded;
    return Icons.info_rounded;
  }

  /// Returns themed colors based on toast type and theme mode
  static _ToastColors _getToastColors(ToastificationType type, bool isDark) {
    final Color primary;
    if (type == ToastificationType.success) {
      primary = AppColors.success;
    } else if (type == ToastificationType.error) {
      primary = AppColors.error;
    } else if (type == ToastificationType.warning) {
      primary = AppColors.warning;
    } else {
      primary = AppColors.info;
    }
    return _ToastColors(
      primary: primary,
      background: isDark ? AppColors.grey900 : AppColors.white,
      foreground: isDark ? AppColors.white : AppColors.grey900,
      shadowColor: isDark
          ? Colors.black.withValues(alpha: 0.45)
          : Colors.black.withValues(alpha: 0.12),
    );
  }

  /// Convenience method for showing a toast without BuildContext
  /// Useful in providers, repositories, and services.
  /// Never throws: without a ToastificationWrapper ancestor (tests,
  /// background isolates) it falls back to a log line instead of
  /// crashing the caller with a red screen.
  static void showWithoutContext(
    String message, {
    String title = 'Info',
    ToastificationType type = ToastificationType.info,
    Duration duration = const Duration(milliseconds: 2500),
    bool? isDark,
  }) {
    final dark = isDark ??
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark;
    final colors = _getToastColors(type, dark);
    final showTitle = title.trim().isNotEmpty &&
        title.trim() != _defaultTitleFor(type) &&
        title.trim() != 'Notification';

    try {
      Toastification().show(
        title: showTitle ? _titleText(title, colors.primary) : null,
        description: _messageText(message, colors.foreground),
        type: type,
        style: ToastificationStyle.flat,
        alignment: Alignment.topCenter,
        autoCloseDuration: duration,
        animationDuration: const Duration(milliseconds: 250),
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: colors.primary.withValues(alpha: 0.22),
        ),
        primaryColor: colors.primary,
        backgroundColor: colors.background,
        foregroundColor: colors.foreground,
        icon: _leadingIcon(type, colors.primary),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        margin: const EdgeInsets.only(top: 12, left: 16, right: 16),
        sizeConstraints: const BoxConstraints(maxWidth: 480),
        boxShadow: [
          BoxShadow(
            color: colors.shadowColor,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        showProgressBar: false,
        dragToClose: true,
        applyBlurEffect: false,
        closeButton:
            const ToastCloseButton(showType: CloseButtonShowType.none),
        closeOnClick: true,
        pauseOnHover: true,
      );
    } catch (e) {
      // No overlay available (tests, background work) — log, don't crash.
      AppLogger.w('Toast suppressed (no overlay): [$type] $message');
    }
  }

  /// Special Ghana-themed success toast (celebratory)
  static void showGhanaSuccess(
    BuildContext context,
    String message, {
    String title = 'Success! 🇬🇭',
    Duration duration = const Duration(milliseconds: 3500),
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = _ToastColors(
      primary: AppColors.ghanaFlagGreen,
      background: isDark ? AppColors.grey900 : AppColors.white,
      foreground: isDark ? AppColors.white : AppColors.grey900,
      shadowColor: isDark
          ? Colors.black.withValues(alpha: 0.45)
          : Colors.black.withValues(alpha: 0.12),
    );

    toastification.show(
      context: context,
      title: _titleText(title, AppColors.ghanaFlagGold),
      description: _messageText(message, colors.foreground),
      type: ToastificationType.success,
      style: ToastificationStyle.flat,
      alignment: Alignment.topCenter,
      autoCloseDuration: duration,
      animationDuration: const Duration(milliseconds: 250),
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(
        color: AppColors.ghanaFlagGreen.withValues(alpha: 0.30),
      ),
      primaryColor: AppColors.ghanaFlagGreen,
      backgroundColor: colors.background,
      foregroundColor: colors.foreground,
      icon: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.ghanaFlagGold.withValues(alpha: 0.16),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.celebration_rounded,
          color: AppColors.ghanaFlagGold,
          size: 20,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      margin: const EdgeInsets.only(top: 12, left: 16, right: 16),
      sizeConstraints: const BoxConstraints(maxWidth: 480),
      boxShadow: [
        BoxShadow(
          color: colors.shadowColor,
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
      showProgressBar: false,
      dragToClose: true,
      applyBlurEffect: false,
      closeButton:
          const ToastCloseButton(showType: CloseButtonShowType.none),
      closeOnClick: true,
      pauseOnHover: true,
    );
  }
}

/// Helper class for toast color configuration
class _ToastColors {
  final Color primary;
  final Color background;
  final Color foreground;
  final Color shadowColor;

  _ToastColors({
    required this.primary,
    required this.background,
    required this.foreground,
    required this.shadowColor,
  });
}
