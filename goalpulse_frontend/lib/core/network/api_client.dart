import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config.dart';

/// Thin wrapper around [Dio] pre-configured for the GoalPulse API.
class ApiClient {
  ApiClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (DioException e, handler) {
          String message = 'An unexpected error occurred.';
          
          if (e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.sendTimeout ||
              e.type == DioExceptionType.receiveTimeout ||
              e.type == DioExceptionType.connectionError) {
            message = 'Connection error. Please check your internet connection.';
          } else if (e.response != null) {
            // Check if backend provided a message
            final data = e.response?.data;
            if (data is Map && data.containsKey('detail')) {
              message = data['detail'].toString();
            } else {
              message = 'Server Error: ${e.response?.statusCode}';
            }
          }
          
          // Pass the cleaned up message as a simple Exception so toString() is clean.
          handler.next(DioException(
            requestOptions: e.requestOptions,
            error: ApiException(message),
            response: e.response,
            type: e.type,
          ));
        },
      ),
    );
  }

  late final Dio _dio;

  // ── HTTP verbs ────────────────────────────────────────────────────────────

  Future<Response> get(String path, {Options? options}) async {
    try {
      return await _dio.get(path, options: options);
    } on DioException catch (e) {
      throw e.error ?? e.message ?? 'An unknown error occurred';
    }
  }

  Future<Response> post(String path,
          {dynamic data, Options? options}) async {
    try {
      return await _dio.post(path, data: data, options: options);
    } on DioException catch (e) {
      throw e.error ?? e.message ?? 'An unknown error occurred';
    }
  }

  Future<Response> put(String path,
          {dynamic data, Options? options}) async {
    try {
      return await _dio.put(path, data: data, options: options);
    } on DioException catch (e) {
      throw e.error ?? e.message ?? 'An unknown error occurred';
    }
  }

  Future<Response> patch(String path,
          {dynamic data, Options? options}) async {
    try {
      return await _dio.patch(path, data: data, options: options);
    } on DioException catch (e) {
      throw e.error ?? e.message ?? 'An unknown error occurred';
    }
  }

  Future<Response> delete(String path, {Options? options}) async {
    try {
      return await _dio.delete(path, options: options);
    } on DioException catch (e) {
      throw e.error ?? e.message ?? 'An unknown error occurred';
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Returns [Options] with an Authorization: Bearer header pre-filled.
  static Options bearerOptions(String token) => Options(
        headers: {'Authorization': 'Bearer $token'},
      );
}

// ── Provider ──────────────────────────────────────────────────────────────

/// Provides the singleton [ApiClient] to the widget tree.
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

/// Clean Exception class that simply prints its message.
class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}
