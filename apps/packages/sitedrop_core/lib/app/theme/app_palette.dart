// lib/app/theme/app_palette.dart
// Semantic colors for light + dark (real-world dual theme).
import 'package:flutter/material.dart';

import 'colors.dart';

/// Theme-aware palette. Access via `context.palette`.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color surfaceElevated;

  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color textDisabled;
  final Color textOnPrimary;
  final Color textOnInverse;

  final Color border;
  final Color borderStrong;
  final Color divider;

  final Color inputFill;
  final Color inputHint;
  final Color inputBorder;
  final Color inputIcon;

  final Color icon;
  final Color iconMuted;

  final Color shadow;
  final Color scrim;
  final Color overlay;

  final Color successBg;
  final Color errorBg;
  final Color warningBg;
  final Color infoBg;
  final Color primarySoft;

  final Color chipBg;
  final Color chipText;

  final Color navBarBg;
  final Color navSelected;
  final Color navUnselected;

  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.surfaceElevated,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textDisabled,
    required this.textOnPrimary,
    required this.textOnInverse,
    required this.border,
    required this.borderStrong,
    required this.divider,
    required this.inputFill,
    required this.inputHint,
    required this.inputBorder,
    required this.inputIcon,
    required this.icon,
    required this.iconMuted,
    required this.shadow,
    required this.scrim,
    required this.overlay,
    required this.successBg,
    required this.errorBg,
    required this.warningBg,
    required this.infoBg,
    required this.primarySoft,
    required this.chipBg,
    required this.chipText,
    required this.navBarBg,
    required this.navSelected,
    required this.navUnselected,
  });

  // Not `const` — grey/semantic tokens come from tailwind_colors at runtime.
  static final AppPalette light = AppPalette(
    background: AppColors.surface,
    surface: AppColors.white,
    surfaceMuted: AppColors.grey100,
    surfaceElevated: AppColors.white,
    textPrimary: AppColors.grey900,
    textSecondary: AppColors.grey800,
    textMuted: AppColors.grey600,
    textDisabled: AppColors.grey400,
    textOnPrimary: AppColors.white,
    textOnInverse: AppColors.white,
    border: AppColors.grey200,
    borderStrong: AppColors.grey300,
    divider: AppColors.grey200,
    inputFill: AppColors.white,
    inputHint: AppColors.grey600,
    inputBorder: AppColors.grey300,
    inputIcon: AppColors.grey600,
    icon: AppColors.grey700,
    iconMuted: AppColors.grey500,
    shadow: const Color(0x1A000000),
    scrim: const Color(0x66000000),
    overlay: const Color(0x0D000000),
    successBg: AppColors.successSurface,
    errorBg: AppColors.errorSurface,
    warningBg: AppColors.warningSurface,
    infoBg: AppColors.infoSurface,
    primarySoft: AppColors.primarySurface,
    chipBg: AppColors.grey100,
    chipText: AppColors.grey800,
    navBarBg: AppColors.white,
    navSelected: AppColors.primary,
    navUnselected: AppColors.grey500,
  );

  static final AppPalette dark = AppPalette(
    background: const Color(0xFF0B1220),
    surface: const Color(0xFF151C2C),
    surfaceMuted: const Color(0xFF1C2538),
    surfaceElevated: const Color(0xFF222B3F),
    textPrimary: const Color(0xFFF3F4F6),
    textSecondary: const Color(0xFFE5E7EB),
    textMuted: const Color(0xFF9CA3AF),
    textDisabled: const Color(0xFF6B7280),
    textOnPrimary: AppColors.white,
    textOnInverse: AppColors.grey900,
    border: const Color(0xFF2A3448),
    borderStrong: const Color(0xFF3B465C),
    divider: const Color(0xFF2A3448),
    inputFill: const Color(0xFF1C2538),
    inputHint: const Color(0xFF9CA3AF),
    inputBorder: const Color(0xFF3B465C),
    inputIcon: const Color(0xFF9CA3AF),
    icon: const Color(0xFFD1D5DB),
    iconMuted: const Color(0xFF9CA3AF),
    shadow: const Color(0x66000000),
    scrim: const Color(0x99000000),
    overlay: const Color(0x14FFFFFF),
    successBg: const Color(0xFF0F3D2E),
    errorBg: const Color(0xFF3F1A1A),
    warningBg: const Color(0xFF3D3010),
    infoBg: const Color(0xFF0F2744),
    primarySoft: const Color(0xFF3A241E),
    chipBg: const Color(0xFF1C2538),
    chipText: const Color(0xFFE5E7EB),
    navBarBg: const Color(0xFF151C2C),
    navSelected: AppColors.primaryLight,
    navUnselected: const Color(0xFF9CA3AF),
  );

  @override
  AppPalette copyWith({
    Color? background,
    Color? surface,
    Color? surfaceMuted,
    Color? surfaceElevated,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? textDisabled,
    Color? textOnPrimary,
    Color? textOnInverse,
    Color? border,
    Color? borderStrong,
    Color? divider,
    Color? inputFill,
    Color? inputHint,
    Color? inputBorder,
    Color? inputIcon,
    Color? icon,
    Color? iconMuted,
    Color? shadow,
    Color? scrim,
    Color? overlay,
    Color? successBg,
    Color? errorBg,
    Color? warningBg,
    Color? infoBg,
    Color? primarySoft,
    Color? chipBg,
    Color? chipText,
    Color? navBarBg,
    Color? navSelected,
    Color? navUnselected,
  }) {
    return AppPalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      textDisabled: textDisabled ?? this.textDisabled,
      textOnPrimary: textOnPrimary ?? this.textOnPrimary,
      textOnInverse: textOnInverse ?? this.textOnInverse,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      divider: divider ?? this.divider,
      inputFill: inputFill ?? this.inputFill,
      inputHint: inputHint ?? this.inputHint,
      inputBorder: inputBorder ?? this.inputBorder,
      inputIcon: inputIcon ?? this.inputIcon,
      icon: icon ?? this.icon,
      iconMuted: iconMuted ?? this.iconMuted,
      shadow: shadow ?? this.shadow,
      scrim: scrim ?? this.scrim,
      overlay: overlay ?? this.overlay,
      successBg: successBg ?? this.successBg,
      errorBg: errorBg ?? this.errorBg,
      warningBg: warningBg ?? this.warningBg,
      infoBg: infoBg ?? this.infoBg,
      primarySoft: primarySoft ?? this.primarySoft,
      chipBg: chipBg ?? this.chipBg,
      chipText: chipText ?? this.chipText,
      navBarBg: navBarBg ?? this.navBarBg,
      navSelected: navSelected ?? this.navSelected,
      navUnselected: navUnselected ?? this.navUnselected,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    Color lerpColor(Color a, Color b) => Color.lerp(a, b, t) ?? a;
    return AppPalette(
      background: lerpColor(background, other.background),
      surface: lerpColor(surface, other.surface),
      surfaceMuted: lerpColor(surfaceMuted, other.surfaceMuted),
      surfaceElevated: lerpColor(surfaceElevated, other.surfaceElevated),
      textPrimary: lerpColor(textPrimary, other.textPrimary),
      textSecondary: lerpColor(textSecondary, other.textSecondary),
      textMuted: lerpColor(textMuted, other.textMuted),
      textDisabled: lerpColor(textDisabled, other.textDisabled),
      textOnPrimary: lerpColor(textOnPrimary, other.textOnPrimary),
      textOnInverse: lerpColor(textOnInverse, other.textOnInverse),
      border: lerpColor(border, other.border),
      borderStrong: lerpColor(borderStrong, other.borderStrong),
      divider: lerpColor(divider, other.divider),
      inputFill: lerpColor(inputFill, other.inputFill),
      inputHint: lerpColor(inputHint, other.inputHint),
      inputBorder: lerpColor(inputBorder, other.inputBorder),
      inputIcon: lerpColor(inputIcon, other.inputIcon),
      icon: lerpColor(icon, other.icon),
      iconMuted: lerpColor(iconMuted, other.iconMuted),
      shadow: lerpColor(shadow, other.shadow),
      scrim: lerpColor(scrim, other.scrim),
      overlay: lerpColor(overlay, other.overlay),
      successBg: lerpColor(successBg, other.successBg),
      errorBg: lerpColor(errorBg, other.errorBg),
      warningBg: lerpColor(warningBg, other.warningBg),
      infoBg: lerpColor(infoBg, other.infoBg),
      primarySoft: lerpColor(primarySoft, other.primarySoft),
      chipBg: lerpColor(chipBg, other.chipBg),
      chipText: lerpColor(chipText, other.chipText),
      navBarBg: lerpColor(navBarBg, other.navBarBg),
      navSelected: lerpColor(navSelected, other.navSelected),
      navUnselected: lerpColor(navUnselected, other.navUnselected),
    );
  }
}

extension AppPaletteContext on BuildContext {
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;

  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  bool get isLight => !isDark;

  ColorScheme get colors => Theme.of(this).colorScheme;
}
