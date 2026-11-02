import 'package:sitedrop_core/core/utils/app_logger.dart';
// lib/presentation/providers/auth_provider.dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart';

import 'package:sitedrop_core/data/models/user.dart';
import 'package:sitedrop_core/data/services/api_service.dart';
import 'package:sitedrop_core/data/services/auth_service.dart';
import 'package:sitedrop_core/data/services/notification_service.dart';
import 'package:sitedrop_core/data/services/storage_service.dart';
import 'package:sitedrop_core/config/auth_role_guard.dart';
import 'package:sitedrop_core/core/utils/helpers.dart';
import 'session_bootstrap_provider.dart';

final authProvider = AsyncNotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

class AuthNotifier extends AsyncNotifier<AuthState> {
  @override
  FutureOr<AuthState> build() async {
    // Keep Riverpod session in sync when Dio sees an expired bearer token.
    ApiService.onUnauthorized = () {
      // Defer so we never mutate state mid-build (e.g. cold-start /user 401).
      Future.microtask(() {
        if (!ref.mounted) return;
        final current = state;
        if (current is AsyncData && current.value is AuthAuthenticated) {
          state = const AsyncData<AuthState>(AuthState.unauthenticated());
        }
      });
    };

    // Check token on app start
    final token = await StorageService.getAuthToken();
    if (token != null && token.isNotEmpty) {
      try {
        final user = await AuthService.getCurrentUser();
        // Wrong-role tokens (e.g. seller account on the buyer app) sign out.
        AuthRoleGuard.ensureAllowed(user);
        // Coordinated once-per-session load (cart/wishlist/notifications/FCM).
        _scheduleSessionBootstrap(force: false, userKey: user.id);
        return AuthState.authenticated(user);
      } catch (e) {
        await StorageService.clearAuthToken();
        return const AuthState.unauthenticated();
      }
    }
    return const AuthState.unauthenticated();
  }

  /// Persist token only when the API actually returned one.
  Future<void> _persistSession({
    required String? token,
    required Map<String, dynamic> userData,
  }) async {
    final t = token?.trim() ?? '';
    if (t.isEmpty) {
      throw Exception('Login succeeded but no access token was returned.');
    }
    await StorageService.saveAuthToken(t);
    await StorageService.saveUserData(userData);
  }

  /// Reject accounts that belong to another role app (buyer/seller/driver).
  /// Clears any stale token so a wrong-role attempt never leaves a session.
  Future<void> _ensureRoleAllowed(User user) async {
    try {
      AuthRoleGuard.ensureAllowed(user);
    } catch (_) {
      await StorageService.clearAuthToken();
      rethrow;
    }
  }

  /// Single post-auth bootstrap (deduped across auth paths + AuthListener).
  void _scheduleSessionBootstrap({
    bool force = true,
    String? userKey,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!ref.mounted) return;
      try {
        ref.read(sessionBootstrapProvider).run(
              force: force,
              userKey: userKey,
            );
      } catch (e) {
        AppLogger.e('❌ Session bootstrap after auth failed: $e');
      }
    });
  }

  /// Login with phone/email + password
  Future<AsyncValue<AuthState>> login({
    required String login,
    required String password,
    bool remember = false,
  }) async {
    state = const AsyncLoading<AuthState>();

    state = await AsyncValue.guard(() async {
      final response = await AuthService.login(
        login: login,
        password: password,
        remember: remember,
      );

      final userData = response['user'] as Map<String, dynamic>? ?? {};
      await _persistSession(
        token: response['token']?.toString(),
        userData: userData,
      );
      await StorageService.saveRememberMe(remember);

      final user = User.fromJson(userData);
      await _ensureRoleAllowed(user);
      _scheduleSessionBootstrap(force: true, userKey: user.id);

      return AuthState.authenticated(user);
    });

    return state;
  }

  /// OTP Login - Step 1: Send OTP
  Future<AsyncValue<Map<String, dynamic>>> sendOtpForLogin(String phone) async {
    return await AsyncValue.guard(() async {
      final normalizedPhone = Helpers.formatPhoneNumber(phone);
      final response = await AuthService.loginOtp(normalizedPhone);
      return response;
    });
  }

  /// OTP Login - Step 2: Verify OTP
  Future<AsyncValue<AuthState>> verifyOtpForLogin({
    required String phone,
    required String code,
  }) async {
    state = const AsyncLoading<AuthState>();

    state = await AsyncValue.guard(() async {
      final normalizedPhone = Helpers.formatPhoneNumber(phone);
      final response = await AuthService.verifyOtpLogin(
        phone: normalizedPhone,
        code: code,
      );

      final userData = response['user'] as Map<String, dynamic>? ?? {};
      await _persistSession(
        token: response['token']?.toString(),
        userData: userData,
      );

      final user = User.fromJson(userData);
      await _ensureRoleAllowed(user);
      _scheduleSessionBootstrap(force: true, userKey: user.id);

      return AuthState.authenticated(user);
    });

    return state;
  }

  /// Register (buyer/seller/driver)
  Future<AsyncValue<AuthState>> register({
    required String name,
    required String phone,
    String? email,
    required String password,
    required String passwordConfirmation,
    required String role,
  }) async {
    state = const AsyncLoading<AuthState>();

    state = await AsyncValue.guard(() async {
      final response = await AuthService.register(
        name: name,
        phone: phone,
        email: email,
        password: password,
        passwordConfirmation: passwordConfirmation,
        role: role,
      );

      final userData = response['user'] as Map<String, dynamic>? ?? {};
      await _persistSession(
        token: response['token']?.toString(),
        userData: userData,
      );

      final user = User.fromJson(userData);
      await _ensureRoleAllowed(user);
      _scheduleSessionBootstrap(force: true, userKey: user.id);

      return AuthState.authenticated(user);
    });

    return state;
  }

  /// Send OTP (for forgot password / phone verification)
  Future<AsyncValue<void>> sendOtp(String phone) async {
    return await AsyncValue.guard(() async {
      final normalizedPhone = Helpers.formatPhoneNumber(phone);
      await AuthService.sendOtp(normalizedPhone);
    });
  }

  /// Verify OTP (for phone verification)
  Future<AsyncValue<AuthState>> verifyOtp({
    required String phone,
    required String code,
  }) async {
    state = const AsyncLoading<AuthState>();

    state = await AsyncValue.guard(() async {
      final normalizedPhone = Helpers.formatPhoneNumber(phone);
      final response = await AuthService.verifyOtp(
        phone: normalizedPhone,
        code: code,
      );

      final userData = response['user'] as Map<String, dynamic>? ?? {};
      await _persistSession(
        token: response['token']?.toString(),
        userData: userData,
      );

      final user = User.fromJson(userData);
      await _ensureRoleAllowed(user);
      _scheduleSessionBootstrap(force: true, userKey: user.id);

      return AuthState.authenticated(user);
    });

    return state;
  }

  /// Forgot Password via phone (OTP) or email (reset link).
  Future<AsyncValue<Map<String, dynamic>>> forgotPassword({
    String? phone,
    String? email,
  }) async {
    return await AsyncValue.guard(() async {
      return await AuthService.forgotPassword(phone: phone, email: email);
    });
  }

  /// Reset password via phone OTP or email code.
  Future<AsyncValue<void>> resetPassword({
    String? phone,
    String? email,
    required String code,
    required String password,
    required String passwordConfirmation,
  }) async {
    return await AsyncValue.guard(() async {
      await AuthService.resetPassword(
        phone: phone != null ? Helpers.formatPhoneNumber(phone) : null,
        email: email,
        code: code,
        password: password,
        passwordConfirmation: passwordConfirmation,
      );
    });
  }

  /// Logout - Just clear local data
  Future<AsyncValue<void>> logout() async {
    state = const AsyncLoading<AuthState>();

    return await AsyncValue.guard(() async {
      // Try to call logout API but don't fail if it doesn't work
      try {
        await AuthService.logout();
      } catch (e) {
        AppLogger.e('Logout API error (continuing with local logout): $e');
      }
      // Clear local storage + session-scoped providers
      await StorageService.clearAll();
      try {
        ref.read(sessionBootstrapProvider).reset();
      } catch (_) {}
      NotificationService.clearRegistrationCache();
      state = const AsyncData<AuthState>(AuthState.unauthenticated());
    });
  }

  /// Check authentication status
  Future<bool> checkAuth() async {
    final token = await StorageService.getAuthToken();
    if (token == null || token.isEmpty) {
      state = const AsyncData<AuthState>(AuthState.unauthenticated());
      return false;
    }

    try {
      final user = await AuthService.getCurrentUser();
      // Wrong-role tokens (e.g. buyer account on the seller app) sign out.
      AuthRoleGuard.ensureAllowed(user);
      state = AsyncData<AuthState>(AuthState.authenticated(user));
      _scheduleSessionBootstrap(force: false, userKey: user.id);
      return true;
    } catch (e) {
      await StorageService.clearAuthToken();
      state = const AsyncData<AuthState>(AuthState.unauthenticated());
      return false;
    }
  }

  /// Get current user
  User? get currentUser {
    final authState = state.value;
    if (authState is AuthAuthenticated) {
      return authState.user;
    }
    return null;
  }

  /// Check if user is authenticated
  bool get isAuthenticated {
    return state.value is AuthAuthenticated;
  }

  /// Check if user has a specific role
  bool hasRole(String role) {
    final user = currentUser;
    return user != null && user.role == role;
  }

  /// Check if user is buyer
  bool get isBuyer {
    final user = currentUser;
    return user != null && user.isBuyer;
  }

  /// Check if user is seller
  bool get isSeller {
    final user = currentUser;
    return user != null && user.isSeller;
  }

  /// Check if user is driver
  bool get isDriver {
    final user = currentUser;
    return user != null && user.isDriver;
  }
}

// ====================== AUTH STATE ======================

sealed class AuthState {
  const AuthState();

  const factory AuthState.unauthenticated() = AuthUnauthenticated;
  const factory AuthState.authenticated(User user) = AuthAuthenticated;
  const factory AuthState.loading() = AuthLoading;
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthAuthenticated extends AuthState {
  final User user;
  const AuthAuthenticated(this.user);
}

class AuthLoading extends AuthState {
  const AuthLoading();
}
