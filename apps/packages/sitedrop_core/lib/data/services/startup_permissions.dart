// lib/data/services/startup_permissions.dart
// Ask-once first-launch permission gate (install → first run).
//
// Guarantees:
// - Each native permission dialog is triggered at most ONCE by us
//   (OS also only shows its system dialog once until the user picks
//   "Don't ask again" / denies permanently).
// - The gate never blocks startup and never nags: the flag is stored
//   even when the user denies, so later screens must NOT re-request —
//   they should call LocationService.checkPermissionStatus() and route
//   deniedForever users to app settings instead.
//
// What is requested here:
// - Location (while-in-use only): driver app only — live trip maps need it.
//   Buyer/seller don't use device GPS, so they skip it (Play/App Review
//   reject location declarations without a backing feature).
// - Notifications: all apps (order/trip updates via FCM).
//
// Deliberately NOT requested here:
// - Camera / Photos: lazy via image_picker when the user taps
//   avatar/product photo. Upfront requests tank acceptance rates.
// - Contacts / Calendar: no feature uses them. Declaring + requesting
//   them would trigger Play Data Safety + Apple rejections.
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'location_service.dart';

class StartupPermissions {
  StartupPermissions._();

  /// Persisted marker so the gate runs exactly once per install.
  /// Bump the suffix (v2, v3…) only if a NEW permission must be
  /// introduced later for existing installs.
  static const askedKey = 'sitedrop_permissions_gate_v1';

  /// Run the ask-once gate. Safe to call on every cold start —
  /// it no-ops after the first run.
  static Future<void> ensureAskedOnce({
    bool requestLocation = true,
    bool requestNotifications = true,
  }) async {
    try {
      // Web has no install-time OS prompts; browsers ask per-feature
      // (geolocation, notifications) in context instead.
      if (kIsWeb) return;
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(askedKey) == true) return;

      if (requestLocation) {
        try {
          // Foreground only. Handles denied → request → deniedForever
          // internally and never throws outwards.
          await LocationService().ensurePermission();
        } catch (_) {
          // Best-effort: a failed request must not block startup.
        }
      }

      if (requestNotifications) {
        try {
          final status = await Permission.notification.status;
          // Only prompt when undecided. Granted/limited/permanently-denied
          // are left alone — re-requesting is a no-op or a nag.
          if (status.isDenied) {
            await Permission.notification.request();
          }
        } catch (_) {
          // Best-effort.
        }
      }

      // Mark done REGARDLESS of grant/deny so we never nag.
      await prefs.setBool(askedKey, true);
    } catch (_) {
      // The gate must never crash or block app startup.
    }
  }
}
