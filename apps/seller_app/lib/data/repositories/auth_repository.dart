// lib/data/repositories/auth_repository.dart
import 'package:sitedrop_core/data/models/user.dart';
import 'package:sitedrop_core/data/services/auth_service.dart';

class AuthRepository {
  static Future<Map<String, dynamic>> login({
    required String login,
    required String password,
    bool remember = false,
  }) async {
    return await AuthService.login(
      login: login,
      password: password,
      remember: remember,
    );
  }

  static Future<Map<String, dynamic>> register({
    required String name,
    required String phone,
    String? email,
    required String password,
    required String passwordConfirmation,
    required String role,
  }) async {
    return await AuthService.register(
      name: name,
      phone: phone,
      email: email,
      password: password,
      passwordConfirmation: passwordConfirmation,
      role: role,
    );
  }

  static Future<Map<String, dynamic>> loginOtp(String phone) async {
    return await AuthService.loginOtp(phone);
  }

  static Future<Map<String, dynamic>> verifyOtpLogin({
    required String phone,
    required String code,
  }) async {
    return await AuthService.verifyOtpLogin(phone: phone, code: code);
  }

  static Future<Map<String, dynamic>> sendOtp(String phone) async {
    return await AuthService.sendOtp(phone);
  }

  static Future<Map<String, dynamic>> verifyOtp({
    required String phone,
    required String code,
  }) async {
    return await AuthService.verifyOtp(phone: phone, code: code);
  }

  static Future<Map<String, dynamic>> forgotPassword({
    String? phone,
    String? email,
  }) async {
    return await AuthService.forgotPassword(phone: phone, email: email);
  }

  static Future<Map<String, dynamic>> resetPassword({
    String? phone,
    String? email,
    required String code,
    required String password,
    required String passwordConfirmation,
  }) async {
    return await AuthService.resetPassword(
      phone: phone,
      email: email,
      code: code,
      password: password,
      passwordConfirmation: passwordConfirmation,
    );
  }

  static Future<void> logout() async {
    await AuthService.logout();
  }

  static Future<User> getCurrentUser() async {
    return await AuthService.getCurrentUser();
  }
}
