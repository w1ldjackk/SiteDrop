// lib/data/services/auth_service.dart
import '../../core/constants/api_constants.dart';
import '../../core/utils/helpers.dart';
import '../models/user.dart';
import 'api_service.dart';

class AuthService {
  static Future<Map<String, dynamic>> login({
    required String login,
    required String password,
    bool remember = false,
  }) async {
    final response = await ApiService.post<Map<String, dynamic>>(
      ApiConstants.login,
      data: {'login': login, 'password': password, 'remember': remember},
    );
    return response;
  }

  static Future<Map<String, dynamic>> register({
    required String name,
    required String phone,
    String? email,
    required String password,
    required String passwordConfirmation,
    required String role,
  }) async {
    // Format phone number with + prefix
    final normalizedPhone = Helpers.formatPhoneNumber(phone);

    final response = await ApiService.post<Map<String, dynamic>>(
      ApiConstants.register,
      data: {
        'name': name,
        'phone': normalizedPhone,
        'email': email,
        'phone_country': 'GH',
        'password': password,
        'password_confirmation': passwordConfirmation,
        'role': role,
      },
    );
    return response;
  }

  /// Login with OTP - Step 1: Send OTP
  static Future<Map<String, dynamic>> loginOtp(String phone) async {
    // Format phone number with + prefix
    final normalizedPhone = Helpers.formatPhoneNumber(phone);

    final response = await ApiService.post<Map<String, dynamic>>(
      ApiConstants.loginOtp,
      data: {
        'phone': normalizedPhone, // e.g., +233247131610
      },
    );
    return response;
  }

  /// Login with OTP - Step 2: Verify OTP
  static Future<Map<String, dynamic>> verifyOtpLogin({
    required String phone,
    required String code,
  }) async {
    // Format phone number with + prefix
    final normalizedPhone = Helpers.formatPhoneNumber(phone);

    final response = await ApiService.post<Map<String, dynamic>>(
      ApiConstants.otpVerify,
      data: {
        'phone': normalizedPhone, // e.g., +233247131610
        'otp': code,
      },
    );
    return response;
  }

  /// Send OTP (for forgot password / phone verification)
  static Future<Map<String, dynamic>> sendOtp(String phone) async {
    final normalizedPhone = Helpers.formatPhoneNumber(phone);

    final response = await ApiService.post<Map<String, dynamic>>(
      ApiConstants.otpSend,
      data: {
        'phone': normalizedPhone, // e.g., +233247131610
        'phone_country': 'GH',
      },
    );
    return response;
  }

  /// Verify OTP (for phone verification)
  static Future<Map<String, dynamic>> verifyOtp({
    required String phone,
    required String code,
  }) async {
    final normalizedPhone = Helpers.formatPhoneNumber(phone);

    final response = await ApiService.post<Map<String, dynamic>>(
      ApiConstants.otpVerify,
      data: {
        'phone': normalizedPhone, // e.g., +233247131610
        'code': code,
      },
    );
    return response;
  }

  /// Forgot Password via phone (OTP) or email (reset link).
  /// Provide exactly one of [phone] or [email].
  static Future<Map<String, dynamic>> forgotPassword({
    String? phone,
    String? email,
  }) async {
    final data = <String, dynamic>{};
    if (email != null && email.trim().isNotEmpty) {
      data['email'] = email.trim().toLowerCase();
    } else if (phone != null && phone.trim().isNotEmpty) {
      data['phone'] = Helpers.formatPhoneNumber(phone);
      data['phone_country'] = 'GH';
    } else {
      throw ArgumentError('Provide either phone or email');
    }

    final response = await ApiService.post<Map<String, dynamic>>(
      ApiConstants.forgotPassword,
      data: data,
    );
    return response;
  }

  /// Reset password with email code or phone OTP.
  /// Provide exactly one of [phone] or [email].
  static Future<Map<String, dynamic>> resetPassword({
    String? phone,
    String? email,
    required String code,
    required String password,
    required String passwordConfirmation,
  }) async {
    final data = <String, dynamic>{
      'otp': code,
      'code': code,
      'password': password,
      'password_confirmation': passwordConfirmation,
    };

    if (email != null && email.trim().isNotEmpty) {
      data['email'] = email.trim().toLowerCase();
    } else if (phone != null && phone.trim().isNotEmpty) {
      data['phone'] = Helpers.formatPhoneNumber(phone);
    } else {
      throw ArgumentError('Provide either phone or email');
    }

    final response = await ApiService.post<Map<String, dynamic>>(
      ApiConstants.resetPassword,
      data: data,
    );
    return response;
  }

  static Future<void> logout() async {
    try {
      await ApiService.post<Map<String, dynamic>>(
        ApiConstants.logout,
        data: {},
      );
    } catch (e) {
      // Continue with logout even if API fails
    }
    await ApiService.clearAuthToken();
  }

  static Future<User> getCurrentUser() async {
    final response = await ApiService.get<Map<String, dynamic>>(
      ApiConstants.user,
    );
    final data = response['data'] as Map<String, dynamic>? ?? {};
    final userData = data['user'] as Map<String, dynamic>? ?? data;
    return User.fromJson(userData);
  }

  static Future<Map<String, dynamic>> updateProfile({
    String? name,
    String? phone,
    String? email,
  }) async {
    final response = await ApiService.put<Map<String, dynamic>>(
      ApiConstants.profile,
      data: {'name': ?name, 'phone': ?phone, 'email': ?email},
    );
    return response;
  }

  static Future<Map<String, dynamic>> uploadAvatar(String path) async {
    // Implementation would use multipart form data
    // This is a simplified version
    final response = await ApiService.post<Map<String, dynamic>>(
      ApiConstants.profileAvatar,
      data: {'avatar': path},
    );
    return response;
  }

  static Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    final response = await ApiService.post<Map<String, dynamic>>(
      ApiConstants.changePassword,
      data: {
        'current_password': currentPassword,
        'new_password': newPassword,
        'new_password_confirmation': newPasswordConfirmation,
      },
    );
    return response;
  }

  static Future<Map<String, dynamic>> deleteAccount(String password) async {
    final response = await ApiService.post<Map<String, dynamic>>(
      '${ApiConstants.user}/delete',
      data: {'password': password},
    );
    return response;
  }
}
