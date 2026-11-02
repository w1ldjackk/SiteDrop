// lib/app/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'colors.dart';

class AppTheme {
  static const String fontFamily = 'Inter';

  // ============================================================
  // LIGHT
  // ============================================================
  static ThemeData get lightTheme {
    final palette = AppPalette.light;
    final textTheme = _textTheme(palette);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: fontFamily,
      extensions: [AppPalette.light],
      colorScheme: ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: AppColors.white,
        secondary: AppColors.secondary,
        onSecondary: AppColors.white,
        surface: AppColors.white,
        onSurface: AppColors.grey900,
        error: AppColors.error,
        onError: AppColors.white,
        primaryContainer: AppColors.primarySurface,
        onPrimaryContainer: AppColors.primaryDark,
        secondaryContainer: AppColors.secondarySurface,
        onSecondaryContainer: AppColors.secondaryDark,
        outline: AppColors.grey300,
        outlineVariant: AppColors.grey200,
        surfaceContainerHighest: AppColors.grey100,
      ),
      scaffoldBackgroundColor: palette.background,
      canvasColor: palette.surface,
      cardColor: palette.surface,
      dividerColor: palette.divider,
      disabledColor: palette.textDisabled,
      hintColor: palette.inputHint,
      primaryColor: AppColors.primary,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      iconTheme: IconThemeData(color: palette.icon, size: 24),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: palette.surface,
        foregroundColor: palette.textPrimary,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: palette.textPrimary,
        ),
        iconTheme: IconThemeData(color: palette.icon, size: 24),
        actionsIconTheme: IconThemeData(color: palette.icon, size: 24),
      ),
      inputDecorationTheme: _inputTheme(palette, Brightness.light),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.primary,
        selectionColor: Color(0x331A8E5A),
        selectionHandleColor: AppColors.primary,
      ),
      elevatedButtonTheme: _elevatedButton(Brightness.light),
      filledButtonTheme: _filledButton(Brightness.light),
      textButtonTheme: _textButton(Brightness.light),
      outlinedButtonTheme: _outlinedButton(Brightness.light),
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        selectedTileColor: palette.primarySoft.withValues(alpha: 0.4),
        textColor: palette.textPrimary,
        iconColor: palette.icon,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: palette.textPrimary,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 13,
          color: palette.textMuted,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: palette.border),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.chipBg,
        labelStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: palette.chipText,
        ),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: palette.navBarBg,
        selectedItemColor: palette.navSelected,
        unselectedItemColor: palette.navUnselected,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: palette.navSelected,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: palette.navUnselected,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: palette.textPrimary,
        ),
        contentTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          color: palette.textSecondary,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.textPrimary,
        contentTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          color: palette.textOnInverse,
        ),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
      dividerTheme: DividerThemeData(color: palette.divider, thickness: 1),
      switchTheme: _switchTheme(Brightness.light),
      checkboxTheme: _checkboxTheme(Brightness.light),
      radioTheme: _radioTheme(Brightness.light),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
    );
  }

  // ============================================================
  // DARK
  // ============================================================
  static ThemeData get darkTheme {
    final palette = AppPalette.dark;
    final textTheme = _textTheme(palette);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: fontFamily,
      extensions: [AppPalette.dark],
      colorScheme: ColorScheme.dark(
        primary: AppColors.primaryLight,
        onPrimary: AppColors.white,
        secondary: AppColors.secondaryLight,
        onSecondary: AppColors.grey900,
        surface: palette.surface,
        onSurface: palette.textPrimary,
        error: AppColors.error,
        onError: AppColors.white,
        primaryContainer: palette.primarySoft,
        onPrimaryContainer: AppColors.primaryLight,
        secondaryContainer: palette.warningBg,
        onSecondaryContainer: AppColors.secondaryLight,
        outline: palette.borderStrong,
        outlineVariant: palette.border,
        surfaceContainerHighest: palette.surfaceMuted,
      ),
      scaffoldBackgroundColor: palette.background,
      canvasColor: palette.surface,
      cardColor: palette.surface,
      dividerColor: palette.divider,
      disabledColor: palette.textDisabled,
      hintColor: palette.inputHint,
      primaryColor: AppColors.primaryLight,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      iconTheme: IconThemeData(color: palette.icon, size: 24),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: palette.surface,
        foregroundColor: palette.textPrimary,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: palette.textPrimary,
        ),
        iconTheme: IconThemeData(color: palette.icon, size: 24),
        actionsIconTheme: IconThemeData(color: palette.icon, size: 24),
      ),
      inputDecorationTheme: _inputTheme(palette, Brightness.dark),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.primaryLight,
        selectionColor: AppColors.primaryLight.withValues(alpha: 0.3),
        selectionHandleColor: AppColors.primaryLight,
      ),
      elevatedButtonTheme: _elevatedButton(Brightness.dark),
      filledButtonTheme: _filledButton(Brightness.dark),
      textButtonTheme: _textButton(Brightness.dark),
      outlinedButtonTheme: _outlinedButton(Brightness.dark),
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        selectedTileColor: palette.primarySoft.withValues(alpha: 0.55),
        textColor: palette.textPrimary,
        iconColor: palette.icon,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: palette.textPrimary,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 13,
          color: palette.textMuted,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: palette.border),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.chipBg,
        labelStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: palette.chipText,
        ),
        side: BorderSide(color: palette.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: palette.navBarBg,
        selectedItemColor: palette.navSelected,
        unselectedItemColor: palette.navUnselected,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: palette.navSelected,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: palette.navUnselected,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: palette.textPrimary,
        ),
        contentTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          color: palette.textSecondary,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.surfaceElevated,
        contentTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          color: palette.textPrimary,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          side: BorderSide(color: palette.border),
        ),
      ),
      dividerTheme: DividerThemeData(color: palette.divider, thickness: 1),
      switchTheme: _switchTheme(Brightness.dark),
      checkboxTheme: _checkboxTheme(Brightness.dark),
      radioTheme: _radioTheme(Brightness.dark),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primaryLight,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryLight,
        foregroundColor: AppColors.white,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
    );
  }

  // ============================================================
  // SHARED BUILDERS
  // ============================================================
  static TextTheme _textTheme(AppPalette p) {
    return TextTheme(
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
        color: p.textPrimary,
        fontFamily: fontFamily,
      ),
      displayMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
        color: p.textPrimary,
        fontFamily: fontFamily,
      ),
      displaySmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
        color: p.textPrimary,
        fontFamily: fontFamily,
      ),
      headlineLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        color: p.textPrimary,
        fontFamily: fontFamily,
      ),
      headlineMedium: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        color: p.textPrimary,
        fontFamily: fontFamily,
      ),
      headlineSmall: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: p.textPrimary,
        fontFamily: fontFamily,
      ),
      titleLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        color: p.textPrimary,
        fontFamily: fontFamily,
      ),
      titleMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        color: p.textSecondary,
        fontFamily: fontFamily,
      ),
      titleSmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.05,
        color: p.textMuted,
        fontFamily: fontFamily,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: p.textPrimary,
        fontFamily: fontFamily,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: p.textSecondary,
        fontFamily: fontFamily,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: p.textMuted,
        fontFamily: fontFamily,
      ),
      labelLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: p.textPrimary,
        fontFamily: fontFamily,
      ),
      labelMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: p.textSecondary,
        fontFamily: fontFamily,
      ),
      labelSmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: p.textMuted,
        fontFamily: fontFamily,
      ),
    );
  }

  static InputDecorationTheme _inputTheme(AppPalette p, Brightness brightness) {
    final radius = BorderRadius.circular(14);
    final primary = brightness == Brightness.dark
        ? AppColors.primaryLight
        : AppColors.primary;

    return InputDecorationTheme(
      filled: true,
      fillColor: p.inputFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
        borderSide: BorderSide(color: primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: AppColors.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: AppColors.error, width: 2),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: p.border, width: 1.5),
      ),
      labelStyle: TextStyle(
        fontFamily: fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: p.textMuted,
      ),
      floatingLabelStyle: TextStyle(
        fontFamily: fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      hintStyle: TextStyle(
        fontFamily: fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: p.inputHint,
      ),
      helperStyle: TextStyle(
        fontFamily: fontFamily,
        fontSize: 12,
        color: p.textMuted,
      ),
      errorStyle: TextStyle(
        fontFamily: fontFamily,
        fontSize: 12,
        color: AppColors.error,
      ),
      prefixIconColor: p.inputIcon,
      suffixIconColor: p.inputIcon,
      iconColor: p.inputIcon,
    );
  }

  // Note: do NOT use minimumSize width = infinity here.
  // That crashes buttons placed in Rows / unbounded horizontal parents.
  // Full-width CTAs should use SizedBox(width: double.infinity, ...) or
  // PrimaryButton / SecondaryButton with isFullWidth: true.
  static ElevatedButtonThemeData _elevatedButton(Brightness b) {
    final bg = b == Brightness.dark
        ? AppColors.primaryLight
        : AppColors.primary;
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: AppColors.white,
        disabledBackgroundColor: b == Brightness.dark
            ? AppColors.grey700
            : AppColors.grey300,
        disabledForegroundColor: b == Brightness.dark
            ? AppColors.grey400
            : AppColors.grey600,
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static FilledButtonThemeData _filledButton(Brightness b) {
    final bg = b == Brightness.dark
        ? AppColors.primaryLight
        : AppColors.primary;
    return FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: AppColors.white,
        disabledBackgroundColor: b == Brightness.dark
            ? AppColors.grey700
            : AppColors.grey300,
        disabledForegroundColor: b == Brightness.dark
            ? AppColors.grey400
            : AppColors.grey600,
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static TextButtonThemeData _textButton(Brightness b) {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: b == Brightness.dark
            ? AppColors.primaryLight
            : AppColors.primary,
        textStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static OutlinedButtonThemeData _outlinedButton(Brightness b) {
    final color = b == Brightness.dark
        ? AppColors.primaryLight
        : AppColors.primary;
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color),
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static SwitchThemeData _switchTheme(Brightness b) {
    final active = b == Brightness.dark
        ? AppColors.primaryLight
        : AppColors.primary;
    return SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.white;
        return b == Brightness.dark ? AppColors.grey400 : AppColors.grey100;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return active;
        return b == Brightness.dark ? AppColors.grey700 : AppColors.grey300;
      }),
    );
  }

  static CheckboxThemeData _checkboxTheme(Brightness b) {
    final active = b == Brightness.dark
        ? AppColors.primaryLight
        : AppColors.primary;
    return CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return active;
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(AppColors.white),
      side: BorderSide(
        color: b == Brightness.dark ? AppColors.grey500 : AppColors.grey400,
        width: 1.5,
      ),
    );
  }

  static RadioThemeData _radioTheme(Brightness b) {
    final active = b == Brightness.dark
        ? AppColors.primaryLight
        : AppColors.primary;
    return RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return active;
        return b == Brightness.dark ? AppColors.grey500 : AppColors.grey500;
      }),
    );
  }
}
