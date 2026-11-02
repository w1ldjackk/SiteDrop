// lib/app/theme/colors.dart
// Brand / fixed tokens. For surfaces & text that change with theme,
// use `context.palette` from app_palette.dart.
// Neutral + semantic hues from [tailwind_colors] (TW3 palette).
import 'package:flutter/material.dart';
import 'package:tailwind_colors/tailwind_colors.dart';

export 'app_palette.dart';

class AppColors {
  // Brand Colors (same in light & dark; primaryLight used on dark surfaces)
  static const Color primary = Color(0xFFC8553D);
  static const Color primaryLight = Color(0xFFD97A63);
  static const Color primaryDark = Color(0xFFA3412E);
  static const Color primarySurface = Color(0xFFF5EDE6);
  static const Color primaryLightest = Color(0xFFFAF4EF);

  // Secondary / amber from Tailwind v3
  static final Color secondary = TW3Colors.amber.shade500;
  static final Color secondaryLight = TW3Colors.amber.shade400;
  static final Color secondaryDark = TW3Colors.amber.shade600;
  static final Color secondarySurface = TW3Colors.amber.shade100;

  // Neutral Colors
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);

  // Gray Scale (Tailwind v3 via tailwind_colors)
  static final Color grey50 = TW3Colors.gray.shade50!;
  static final Color grey100 = TW3Colors.gray.shade100;
  static final Color grey200 = TW3Colors.gray.shade200;
  static final Color grey300 = TW3Colors.gray.shade300;
  static final Color grey400 = TW3Colors.gray.shade400;
  static final Color grey500 = TW3Colors.gray.shade500;
  static final Color grey600 = TW3Colors.gray.shade600;
  static final Color grey700 = TW3Colors.gray.shade700;
  static const Color grey800 = Color(0xFF4A4A4A);
  static const Color grey900 = Color(0xFF2B2B2B);

  // Semantic Colors (Tailwind v3)
  static final Color success = TW3Colors.emerald.shade500;
  static final Color successSurface = TW3Colors.emerald.shade100;
  static final Color error = TW3Colors.red.shade500;
  static final Color errorSurface = TW3Colors.red.shade100;
  static final Color warning = TW3Colors.amber.shade500;
  static final Color warningSurface = TW3Colors.amber.shade100;
  static final Color info = TW3Colors.blue.shade500;
  static final Color infoSurface = TW3Colors.blue.shade100;

  // Ghana Market Colors
  static const Color ghanaFlagRed = Color(0xFFCE1126);
  static const Color ghanaFlagGold = Color(0xFFFCD116);
  static const Color ghanaFlagGreen = Color(0xFF006B3F);
  static const Color ghanaFlagBlack = Color(0xFF000000);

  // Additional UI Colors
  static final Color muted = Color(0xFF4A4A4A);
  static final Color accent = TW3Colors.amber.shade500;
  static final Color surface = Color(0xFFF5EDE6);
  static final Color onSurface = Color(0xFF2B2B2B);
  static final Color onBackground = Color(0xFF2B2B2B);
  static const Color inputBackground = Color(0xFFF8FAFC);
  static const Color inputBorder = Color(0xFFCBD5E1);
  static const Color inputFocusedBorder = primary;
  static final Color inputErrorBorder = error;
}

// Extra semantic tokens not on ColorScheme. Do not shadow primary/error —
// instance members always win over extension getters.
extension AppColorScheme on ColorScheme {
  Color get primarySurface => AppColors.primarySurface;
  Color get secondarySurface => AppColors.secondarySurface;
  Color get success => AppColors.success;
  Color get warning => AppColors.warning;
  Color get info => AppColors.info;
}
