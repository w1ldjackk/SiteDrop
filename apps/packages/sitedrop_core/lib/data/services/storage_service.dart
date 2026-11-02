// lib/data/services/storage_service.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';

class StorageService {
  // ============================================================
  // SECURE STORAGE (for sensitive data)
  // ============================================================
  static final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(),
  );

  // ============================================================
  // SHARED PREFERENCES (for simple key-value)
  // ============================================================
  static Future<SharedPreferences> get _prefs async =>
      await SharedPreferences.getInstance();

  // ============================================================
  // HIVE BOXES
  // ============================================================
  static Box? _cartBox;
  static Box? _userBox;
  static Box? _settingsBox;
  static Box? _ordersBox;
  static Box? _productsBox;

  // Initialize Hive boxes
  static Future<void> initHive() async {
    _cartBox = await Hive.openBox(AppConstants.cartBox);
    _userBox = await Hive.openBox(AppConstants.userBox);
    _settingsBox = await Hive.openBox(AppConstants.settingsBox);
    _ordersBox = await Hive.openBox(AppConstants.ordersBox);
    _productsBox = await Hive.openBox(AppConstants.productsBox);
  }

  // ============================================================
  // SECURE STORAGE METHODS
  // ============================================================
  static Future<void> saveSecure(String key, String value) async {
    await _secureStorage.write(key: key, value: value);
  }

  static Future<String?> readSecure(String key) async {
    return await _secureStorage.read(key: key);
  }

  static Future<void> deleteSecure(String key) async {
    await _secureStorage.delete(key: key);
  }

  static Future<void> clearSecure() async {
    await _secureStorage.deleteAll();
  }

  // ============================================================
  // SHARED PREFERENCES METHODS
  // ============================================================
  static Future<void> savePref(String key, dynamic value) async {
    final prefs = await _prefs;
    if (value is String) {
      await prefs.setString(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    } else if (value is double) {
      await prefs.setDouble(key, value);
    } else if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is List<String>) {
      await prefs.setStringList(key, value);
    }
  }

  static Future<dynamic> readPref(String key) async {
    final prefs = await _prefs;
    return prefs.get(key);
  }

  static Future<bool> containsPref(String key) async {
    final prefs = await _prefs;
    return prefs.containsKey(key);
  }

  static Future<void> removePref(String key) async {
    final prefs = await _prefs;
    await prefs.remove(key);
  }

  static Future<void> clearPrefs() async {
    final prefs = await _prefs;
    await prefs.clear();
  }

  // ============================================================
  // HIVE BOX METHODS - Generic
  // ============================================================
  static Box getBox(String boxName) {
    return Hive.box(boxName);
  }

  static Future<void> putInBox(
    String boxName,
    dynamic key,
    dynamic value,
  ) async {
    final box = Hive.box(boxName);
    await box.put(key, value);
  }

  static dynamic getFromBox(String boxName, dynamic key) {
    final box = Hive.box(boxName);
    return box.get(key);
  }

  static Future<void> deleteFromBox(String boxName, dynamic key) async {
    final box = Hive.box(boxName);
    await box.delete(key);
  }

  static Future<void> clearBox(String boxName) async {
    final box = Hive.box(boxName);
    await box.clear();
  }

  // ============================================================
  // CONVENIENCE METHODS FOR SPECIFIC BOXES
  // ============================================================
  static Box get cartBox => _cartBox ?? Hive.box(AppConstants.cartBox);
  static Box get userBox => _userBox ?? Hive.box(AppConstants.userBox);
  static Box get settingsBox =>
      _settingsBox ?? Hive.box(AppConstants.settingsBox);
  static Box get ordersBox => _ordersBox ?? Hive.box(AppConstants.ordersBox);
  static Box get productsBox =>
      _productsBox ?? Hive.box(AppConstants.productsBox);

  // ============================================================
  // USER DATA METHODS
  // ============================================================
  static Future<void> saveUserData(Map<String, dynamic> data) async {
    await saveSecure('user_id', data['id']?.toString() ?? '');
    await saveSecure('user_name', data['name']?.toString() ?? '');
    await saveSecure('user_phone', data['phone']?.toString() ?? '');
    await saveSecure('user_email', data['email']?.toString() ?? '');
    await saveSecure('user_role', data['role']?.toString() ?? 'buyer');
    await saveSecure('user_avatar', data['avatar']?.toString() ?? '');

    if (data['is_verified'] != null) {
      await saveSecure('user_verified', data['is_verified'].toString());
    }
  }

  static Future<Map<String, String?>> getUserData() async {
    return {
      'id': await readSecure('user_id'),
      'name': await readSecure('user_name'),
      'phone': await readSecure('user_phone'),
      'email': await readSecure('user_email'),
      'role': await readSecure('user_role'),
      'avatar': await readSecure('user_avatar'),
      'verified': await readSecure('user_verified'),
    };
  }

  static Future<void> clearUserData() async {
    await deleteSecure('user_id');
    await deleteSecure('user_name');
    await deleteSecure('user_phone');
    await deleteSecure('user_email');
    await deleteSecure('user_role');
    await deleteSecure('user_avatar');
    await deleteSecure('user_verified');
    await deleteSecure(AppConstants.authTokenKey);
  }

  // ============================================================
  // AUTH TOKEN METHODS
  // ============================================================
  static Future<void> saveAuthToken(String token) async {
    await saveSecure(AppConstants.authTokenKey, token);
  }

  static Future<String?> getAuthToken() async {
    return await readSecure(AppConstants.authTokenKey);
  }

  static Future<void> clearAuthToken() async {
    await deleteSecure(AppConstants.authTokenKey);
  }

  // ============================================================
  // THEME PREFERENCE
  // ============================================================
  static Future<void> saveThemeMode(String mode) async {
    await savePref(AppConstants.themeModeKey, mode);
  }

  static Future<String?> getThemeMode() async {
    return await readPref(AppConstants.themeModeKey) as String?;
  }

  // ============================================================
  // LANGUAGE PREFERENCE
  // ============================================================
  static Future<void> saveLanguage(String language) async {
    await savePref(AppConstants.languageKey, language);
  }

  static Future<String?> getLanguage() async {
    return await readPref(AppConstants.languageKey) as String?;
  }

  // ============================================================
  // REMEMBER ME
  // ============================================================
  static Future<void> saveRememberMe(bool remember) async {
    await savePref(AppConstants.rememberMeKey, remember);
  }

  static Future<bool> getRememberMe() async {
    return await readPref(AppConstants.rememberMeKey) as bool? ?? false;
  }

  // ============================================================
  // CLEAR ALL DATA
  // ============================================================
  static Future<void> clearAll() async {
    await clearSecure();
    await clearPrefs();
    await clearBox(AppConstants.cartBox);
    await clearBox(AppConstants.userBox);
    await clearBox(AppConstants.ordersBox);
    await clearBox(AppConstants.productsBox);
  }
}
