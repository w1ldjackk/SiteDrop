// lib/data/services/api_service.dart
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../config/app_config.dart';
import '../../core/constants/api_constants.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/app_logger.dart';

class ApiService {
  static final Dio _dio = Dio(
    BaseOptions(
      // Placeholder — always overwritten in [ensureInitialized].
      baseUrl: '',
      connectTimeout: ApiConstants.connectTimeout,
      receiveTimeout: ApiConstants.receiveTimeout,
      sendTimeout: ApiConstants.sendTimeout,
      headers: {
        ApiConstants.contentType: ApiConstants.applicationJson,
        ApiConstants.accept: ApiConstants.applicationJson,
      },
    ),
  );

  static final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(),
  );

  static bool _interceptorsAdded = false;

  /// In-flight GET coalescing: identical concurrent GETs share one Future.
  static final Map<String, Future<dynamic>> _inflightGets = {};

  /// Called once when a request that sent a bearer token gets HTTP 401.
  /// Wire this from the auth layer to clear in-memory session state.
  static void Function()? onUnauthorized;

  /// Stable key for request coalescing (method + path + sorted query).
  static String _requestKey(
    String method,
    String endpoint, {
    Map<String, dynamic>? queryParams,
  }) {
    if (queryParams == null || queryParams.isEmpty) {
      return '$method $endpoint';
    }
    final entries = queryParams.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final q = entries.map((e) => '${e.key}=${e.value}').join('&');
    return '$method $endpoint?$q';
  }

  /// Ensures base URL + interceptors are ready (safe to call often).
  static void ensureInitialized() {
    // Re-apply every time so hot restart / platform can't leave a stale host.
    _dio.options.baseUrl = ApiConstants.baseUrl;
    _initInterceptors();
  }

  // Initialize interceptors
  static void _initInterceptors() {
    if (_interceptorsAdded) return;
    _interceptorsAdded = true;

    // Request interceptor
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Always re-bind base URL (web must never keep 10.0.2.2 from dart-define).
          final base = ApiConstants.baseUrl;
          _dio.options.baseUrl = base;
          options.baseUrl = base;

          // Add auth token
          final authToken = await _secureStorage.read(
            key: AppConstants.authTokenKey,
          );
          if (authToken != null && authToken.isNotEmpty) {
            options.headers[ApiConstants.authorization] =
                '${ApiConstants.bearer} $authToken';
          }

          AppLogger.i('🌐 Request: ${options.method} ${options.uri}');
          AppLogger.d('📦 Data: ${options.data}');
          AppLogger.d('📨 Headers: ${options.headers}');

          return handler.next(options);
        },
        onResponse: (response, handler) {
          AppLogger.i(
            '✅ Response: ${response.statusCode} ${response.requestOptions.uri}',
          );
          AppLogger.d('📦 Data: ${response.data}');

          return handler.next(response);
        },
        onError: (error, handler) async {
          AppLogger.e('❌ Error: ${error.message}');
          AppLogger.e('📦 Error Data: ${error.response?.data}');

          // Only clear stored token when a request that *sent* a bearer token
          // gets 401 (expired/invalid session). Guest 401s on protected
          // endpoints must not wipe anything or force global logout.
          if (error.response?.statusCode == 401) {
            final authHeader =
                error.requestOptions.headers[ApiConstants.authorization]
                    ?.toString();
            if (authHeader != null && authHeader.isNotEmpty) {
              await _secureStorage.delete(key: AppConstants.authTokenKey);
              try {
                onUnauthorized?.call();
              } catch (e) {
                AppLogger.w('onUnauthorized callback failed: $e');
              }
            }
          }

          return handler.next(error);
        },
      ),
    );

    // FIXED: Use the const value from AppConfig
    // Only add LogInterceptor in development mode
    if (!AppConfig.isProduction) {
      _dio.interceptors.add(
        LogInterceptor(
          request: true,
          requestHeader: true,
          requestBody: true,
          responseHeader: true,
          responseBody: true,
          error: true,
        ),
      );
    }
  }

  // Generic GET request — concurrent identical GETs are coalesced into one.
  static Future<T> get<T>(
    String endpoint, {
    Map<String, dynamic>? queryParams,
    Options? options,
    bool coalesce = true,
  }) async {
    ensureInitialized();

    if (!coalesce) {
      return _executeGet<T>(endpoint, queryParams: queryParams, options: options);
    }

    final key = _requestKey('GET', endpoint, queryParams: queryParams);
    final existing = _inflightGets[key];
    if (existing != null) {
      AppLogger.d('🔁 Coalescing duplicate GET: $key');
      return await existing as T;
    }

    final future = _executeGet<T>(
      endpoint,
      queryParams: queryParams,
      options: options,
    );
    _inflightGets[key] = future;
    try {
      return await future;
    } finally {
      if (identical(_inflightGets[key], future)) {
        _inflightGets.remove(key);
      }
    }
  }

  static Future<T> _executeGet<T>(
    String endpoint, {
    Map<String, dynamic>? queryParams,
    Options? options,
  }) async {
    try {
      final response = await _dio.get(
        endpoint,
        queryParameters: queryParams,
        options: options,
      );
      return response.data as T;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Generic POST request
  static Future<T> post<T>(
    String endpoint, {
    dynamic data,
    Map<String, dynamic>? queryParams,
    Options? options,
  }) async {
    try {
      ensureInitialized();
      final response = await _dio.post(
        endpoint,
        data: data,
        queryParameters: queryParams,
        options: options,
      );
      return response.data as T;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Generic PUT request
  static Future<T> put<T>(
    String endpoint, {
    dynamic data,
    Map<String, dynamic>? queryParams,
    Options? options,
  }) async {
    try {
      ensureInitialized();
      final response = await _dio.put(
        endpoint,
        data: data,
        queryParameters: queryParams,
        options: options,
      );
      return response.data as T;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Generic DELETE request
  static Future<T> delete<T>(
    String endpoint, {
    Map<String, dynamic>? queryParams,
    Options? options,
  }) async {
    try {
      ensureInitialized();
      final response = await _dio.delete(
        endpoint,
        queryParameters: queryParams,
        options: options,
      );
      return response.data as T;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Generic PATCH request
  static Future<T> patch<T>(
    String endpoint, {
    dynamic data,
    Map<String, dynamic>? queryParams,
    Options? options,
  }) async {
    try {
      ensureInitialized();
      final response = await _dio.patch(
        endpoint,
        data: data,
        queryParameters: queryParams,
        options: options,
      );
      return response.data as T;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Auth token management
  static Future<void> setAuthToken(String token) async {
    await _secureStorage.write(key: AppConstants.authTokenKey, value: token);
  }

  static Future<String?> getAuthToken() async {
    return await _secureStorage.read(key: AppConstants.authTokenKey);
  }

  static Future<void> clearAuthToken() async {
    await _secureStorage.delete(key: AppConstants.authTokenKey);
  }

  /// Extract a short, user-facing message from any API / Dio failure.
  static String messageFromError(Object error) {
    if (error is ApiException) return error.message;
    if (error is DioException) return _extractDioMessage(error);

    final raw = error.toString().trim();
    // Common wrappers: Exception: … / ApiException: …
    final stripped = raw
        .replaceFirst(RegExp(r'^(Exception|ApiException|Error):\s*'), '')
        .trim();

    // Never show raw Dio validateStatus walls of text
    if (_isRawDioStatusMessage(stripped) || _isRawDioStatusMessage(raw)) {
      return 'Something went wrong. Please try again.';
    }

    // Prefer a clean message if the string itself is already user-facing
    if (stripped.isNotEmpty && stripped.length < 280) return stripped;
    if (stripped.isNotEmpty) return 'Something went wrong. Please try again.';
    return 'Something went wrong. Please try again.';
  }

  // Error handling
  static ApiException _handleError(DioException error) {
    return ApiException(
      message: _extractDioMessage(error),
      statusCode: error.response?.statusCode,
      errors: _extractFieldErrors(error.response?.data),
    );
  }

  static String _extractDioMessage(DioException error) {
    final data = error.response?.data;

    if (data is Map) {
      // Laravel validation: { message, errors: { field: ["…"] } }
      final fieldMessage = _firstFieldError(data['errors']);
      if (fieldMessage != null && fieldMessage.isNotEmpty) {
        return fieldMessage;
      }

      final message = data['message']?.toString().trim();
      if (message != null &&
          message.isNotEmpty &&
          !_isRawDioStatusMessage(message)) {
        return message;
      }

      final err = data['error']?.toString().trim();
      if (err != null && err.isNotEmpty) return err;
    } else if (data is String && data.trim().isNotEmpty) {
      // Sometimes HTML or plain text
      final text = data.trim();
      if (text.length < 200 && !text.contains('<html')) return text;
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timeout. Please check your internet.';
      case DioExceptionType.connectionError:
        return 'No internet connection. Please check your network.';
      case DioExceptionType.cancel:
        return 'Request was cancelled.';
      case DioExceptionType.badResponse:
        final code = error.response?.statusCode;
        if (code == 401) return 'Please sign in to continue.';
        if (code == 403) return 'You do not have permission to do that.';
        if (code == 404) return 'The requested resource was not found.';
        if (code == 422) {
          return 'Please check your details and try again.';
        }
        if (code != null && code >= 500) {
          return 'Server error. Please try again later.';
        }
        return 'Request failed. Please try again.';
      default:
        final msg = error.message?.toString() ?? '';
        if (msg.isNotEmpty && !_isRawDioStatusMessage(msg)) return msg;
        return 'Something went wrong. Please try again.';
    }
  }

  static Map<String, List<String>>? _extractFieldErrors(dynamic data) {
    if (data is! Map) return null;
    final errors = data['errors'];
    if (errors is! Map) return null;

    final out = <String, List<String>>{};
    errors.forEach((key, value) {
      if (value is List) {
        out[key.toString()] =
            value.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
      } else if (value != null) {
        out[key.toString()] = [value.toString()];
      }
    });
    return out.isEmpty ? null : out;
  }

  static String? _firstFieldError(dynamic errors) {
    if (errors is! Map || errors.isEmpty) return null;
    final first = errors.values.first;
    if (first is List && first.isNotEmpty) {
      return first.first.toString().trim();
    }
    if (first is String && first.trim().isNotEmpty) {
      return first.trim();
    }
    return null;
  }

  static bool _isRawDioStatusMessage(String message) {
    final m = message.toLowerCase();
    return m.contains('validatestatus') ||
        m.contains('status code of') ||
        m.contains('status codes at https://') ||
        m.contains('this exception was thrown because the response');
  }

  // Get Dio instance for custom usage
  static Dio get dio => _dio;
}

/// Clean API failure for UI (no Dio stack / status-code essay).
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, List<String>>? errors;

  const ApiException({
    required this.message,
    this.statusCode,
    this.errors,
  });

  /// Prefer first field error, else [message].
  String get userMessage => message;

  @override
  String toString() => message;
}
