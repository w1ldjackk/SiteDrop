/// SiteDrop shared library for role apps (buyer / seller / driver).
///
/// Import with:
/// ```dart
/// import 'package:sitedrop_core/sitedrop_core.dart';
/// ```
///
/// Apps own: screens, Riverpod providers, and go_router trees.
/// This package owns: API, models, theme tokens, constants, utils.
library;

// ── Config ──────────────────────────────────────────────────────────
export 'config/app_config.dart';
export 'config/app_flavor.dart';
export 'config/auth_role_guard.dart';
export 'config/firebase_options.dart';

// ── Theme ───────────────────────────────────────────────────────────
export 'app/theme/app_palette.dart';
export 'app/theme/app_theme.dart';
export 'app/theme/colors.dart';
export 'app/theme/input_styles.dart';

// ── Route name constants only (no GoRouter) ─────────────────────────
export 'app/routes/route_names.dart';

// ── Constants ───────────────────────────────────────────────────────
export 'core/constants/api_constants.dart';
export 'core/constants/app_constants.dart';

// ── Utils ───────────────────────────────────────────────────────────
export 'core/utils/app_logger.dart';
export 'core/utils/display_names.dart';
export 'core/utils/file_log_output.dart';
export 'core/utils/formatters.dart';
export 'core/utils/helpers.dart';
export 'core/utils/image_picker_helper.dart';
export 'core/utils/toast_service.dart';
export 'core/utils/validators.dart';
// Prefer: import 'package:sitedrop_core/core/utils/utils.dart';
// or use the individual exports above.

// ── Models ──────────────────────────────────────────────────────────
export 'data/models/models.dart';

// ── Maps (OSM-first, provider-neutral, no API key) ────────────────────
export 'maps/app_map_point.dart';

// ── Services ────────────────────────────────────────────────────────
export 'data/services/services.dart';
