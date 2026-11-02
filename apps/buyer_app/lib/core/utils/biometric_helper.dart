// lib/core/utils/biometric_helper.dart
// Device biometrics (fingerprint / face) via local_auth.
// Used for the Security "Biometric unlock" toggle + launch gate.

import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricHelper {
  BiometricHelper._();

  static const localKey = 'biometric_unlock';
  static final LocalAuthentication _auth = LocalAuthentication();

  /// True when the device can do biometric auth (hardware + enrolled).
  static Future<bool> isAvailable() async {
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) return false;
      final canCheck = await _auth.canCheckBiometrics;
      if (!canCheck) return false;
      final enrolled = await _auth.getAvailableBiometrics();
      return enrolled.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// System biometric prompt. Returns true when the user passes.
  static Future<bool> authenticate([String reason = '']) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason.isNotEmpty
            ? reason
            : 'Unlock SiteDrop with biometrics',
        biometricOnly: true,
      );
    } catch (_) {
      return false;
    }
  }

  static Future<bool> localEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(localKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> setLocalEnabled(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(localKey, value);
    } catch (_) {}
  }
}
