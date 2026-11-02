import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:sitedrop_core/app/theme/colors.dart';
import '../../presentation/widgets/common/loading_widget.dart';
import 'package:sitedrop_core/core/utils/toast_service.dart';

extension ContextExtensions on BuildContext {
  // ============================================================
  // THEME
  // ============================================================
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => theme.textTheme;
  ColorScheme get colorScheme => theme.colorScheme;

  // ============================================================
  // MEDIA QUERY
  // ============================================================
  Size get screenSize => MediaQuery.of(this).size;
  double get screenWidth => screenSize.width;
  double get screenHeight => screenSize.height;
  EdgeInsets get viewPadding => MediaQuery.of(this).viewPadding;
  EdgeInsets get viewInsets => MediaQuery.of(this).viewInsets;

  // ============================================================
  // NAVIGATION - Using GoRouter for better routing
  // ============================================================
  /// Navigate to a new page using GoRouter
  void pushNamed(String routeName, {Object? extra}) {
    GoRouter.of(this).push(routeName, extra: extra);
  }

  /// Navigate to a new page and replace the current one
  void pushReplacementNamed(String routeName, {Object? extra}) {
    GoRouter.of(this).pushReplacement(routeName, extra: extra);
  }

  /// Navigate to a new page and remove all previous routes
  void pushNamedAndRemoveUntil(String routeName, {Object? extra}) {
    GoRouter.of(this).go(routeName, extra: extra);
  }

  /// Go back to the previous page
  void pop<T extends Object?>([T? result]) {
    try {
      final router = GoRouter.of(this);
      if (router.canPop()) {
        router.pop(result);
        return;
      }
    } catch (_) {
      // Fallback to Navigator if GoRouter isn't available
    }
    Navigator.pop(this, result);
  }

  /// Check if can pop
  bool get canPop {
    try {
      return GoRouter.of(this).canPop();
    } catch (_) {
      return Navigator.canPop(this);
    }
  }

  // ============================================================
  // NAVIGATION - GoRouter helpers
  // ============================================================
  /// Navigate to a route using GoRouter
  void go(String routeName, {Object? extra}) {
    GoRouter.of(this).go(routeName, extra: extra);
  }

  /// Navigate to a route and replace the current one
  void replace(String routeName, {Object? extra}) {
    GoRouter.of(this).replace(routeName, extra: extra);
  }

  // ============================================================
  // SNACKBAR
  // ============================================================
  void showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : null,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void showSuccessSnackBar(String message) => showSnackBar(message);
  void showErrorSnackBar(String message) =>
      showSnackBar(message, isError: true);

  // ============================================================
  // TOAST - Using ToastService for theme-aware notifications
  // ============================================================
  /// Show a success toast notification
  void showSuccessToast(
    String message, {
    String title = 'Success',
    Duration duration = const Duration(seconds: 3),
  }) {
    ToastService.showSuccess(this, message, title: title, duration: duration);
  }

  /// Show an error toast notification
  void showErrorToast(
    String message, {
    String title = 'Error',
    Duration duration = const Duration(seconds: 4),
  }) {
    ToastService.showError(this, message, title: title, duration: duration);
  }

  /// Show an info toast notification
  void showInfoToast(
    String message, {
    String title = 'Info',
    Duration duration = const Duration(seconds: 3),
  }) {
    ToastService.showInfo(this, message, title: title, duration: duration);
  }

  /// Show a warning toast notification
  void showWarningToast(
    String message, {
    String title = 'Warning',
    Duration duration = const Duration(seconds: 3),
  }) {
    ToastService.showWarning(this, message, title: title, duration: duration);
  }

  /// Show a Ghana-themed success toast (celebratory)
  void showGhanaSuccessToast(
    String message, {
    String title = 'Success! 🇬🇭',
    Duration duration = const Duration(seconds: 4),
  }) {
    ToastService.showGhanaSuccess(
      this,
      message,
      title: title,
      duration: duration,
    );
  }

  // ============================================================
  // LOADING
  // ============================================================
  void showLoading({String? message}) {
    showDialog(
      context: this,
      barrierDismissible: false,
      barrierColor: palette.scrim.withValues(alpha: 0.4),
      builder: (context) => PopScope(
        canPop: false,
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: LoadingWidget.overlay(message: message),
          ),
        ),
      ),
    );
  }

  void hideLoading() {
    if (canPop) pop();
  }

  // ============================================================
  // RESPONSIVE SCREEN
  // ============================================================
  /// Phones in portrait (~360–430) and very narrow windows.
  bool get isCompactWidth => screenWidth < 400;
  bool get isSmallScreen => screenWidth < 600;
  bool get isMediumScreen => screenWidth >= 600 && screenWidth < 900;
  bool get isLargeScreen => screenWidth >= 900;
  bool get isLandscape => screenWidth > screenHeight;

  /// Horizontal page padding that scales with width.
  double get pagePaddingH => isLargeScreen
      ? 32
      : isMediumScreen
          ? 24
          : isCompactWidth
              ? 12
              : 16;

  /// Max content width for readable layouts on tablet/desktop.
  double get contentMaxWidth => isLargeScreen
      ? 960
      : isMediumScreen
          ? 720
          : double.infinity;

  /// Safe fraction of available height for modal sheets (avoids overflow).
  double sheetHeight(double fraction, {double min = 280, double maxFraction = 0.92}) {
    final h = screenHeight - viewPadding.top - viewPadding.bottom;
    final target = h * fraction.clamp(0.2, maxFraction);
    final maxH = h * maxFraction;
    if (target < min) return min.clamp(0, maxH);
    return target.clamp(min, maxH);
  }

  // ============================================================
  // KEYBOARD
  // ============================================================
  void hideKeyboard() => FocusScope.of(this).unfocus();
  bool get isKeyboardVisible => MediaQuery.of(this).viewInsets.bottom > 0;

  // ============================================================
  // DARK MODE
  // ============================================================
  bool get isDarkMode => theme.brightness == Brightness.dark;
  bool get isLightMode => theme.brightness == Brightness.light;

  // ============================================================
  // APP COLORS (from AppColors)
  // ============================================================
  Color get primaryColor => AppColors.primary;
  Color get primaryLightColor => AppColors.primaryLight;
  Color get primaryDarkColor => AppColors.primaryDark;
  Color get accentColor => AppColors.accent;
  Color get successColor => AppColors.success;
  Color get warningColor => AppColors.warning;
  Color get errorColor => AppColors.error;
  Color get infoColor => AppColors.info;
  Color get grey50 => AppColors.grey50;
  Color get grey100 => AppColors.grey100;
  Color get grey200 => AppColors.grey200;
  Color get grey300 => AppColors.grey300;
  Color get grey400 => AppColors.grey400;
  Color get grey500 => AppColors.grey500;
  Color get grey600 => AppColors.grey600;
  Color get grey700 => AppColors.grey700;
  Color get grey800 => AppColors.grey800;
  Color get grey900 => AppColors.grey900;
}
