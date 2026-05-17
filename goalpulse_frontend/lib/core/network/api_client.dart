import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config.dart';

/// Thin wrapper around [Dio] pre-configured for the GoalPulse API.
class ApiClient {
  ApiClient()
      : _dio = Dio(
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

  final Dio _dio;

  // ── HTTP verbs ────────────────────────────────────────────────────────────

  Future<Response> get(String path, {Options? options}) =>
      _dio.get(path, options: options);

  Future<Response> post(String path,
          {dynamic data, Options? options}) =>
      _dio.post(path, data: data, options: options);

  Future<Response> put(String path,
          {dynamic data, Options? options}) =>
      _dio.put(path, data: data, options: options);

  Future<Response> patch(String path,
          {dynamic data, Options? options}) =>
      _dio.patch(path, data: data, options: options);

  Future<Response> delete(String path, {Options? options}) =>
      _dio.delete(path, options: options);

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Returns [Options] with an Authorization: Bearer header pre-filled.
  static Options bearerOptions(String token) => Options(
        headers: {'Authorization': 'Bearer $token'},
      );
}

// ── Provider ──────────────────────────────────────────────────────────────

/// Provides the singleton [ApiClient] to the widget tree.
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());
