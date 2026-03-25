import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/auth_session.dart';
import '../config.dart';

class ApiError implements Exception {
  final String message;
  final int? statusCode;

  ApiError({required this.message, this.statusCode});

  @override
  String toString() => 'ApiError(statusCode: $statusCode, message: $message)';
}

class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  Map<String, String> _defaultHeaders() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    final token = AuthSession.instance.token;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$apiBaseUrl$path');
    final res = await http.post(
      uri,
      headers: _defaultHeaders(),
      body: body == null ? null : jsonEncode(body),
    );

    final decoded = jsonDecode(res.body.isEmpty ? '{}' : res.body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiError(
        message: decoded is Map && decoded['message'] is String
            ? decoded['message'] as String
            : 'Request failed',
        statusCode: res.statusCode,
      );
    }

    return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    var uri = Uri.parse('$apiBaseUrl$path');
    if (queryParameters != null && queryParameters.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParameters);
    }
    final res = await http.get(
      uri,
      headers: _defaultHeaders(),
    );

    final decoded = jsonDecode(res.body.isEmpty ? '{}' : res.body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiError(
        message: decoded is Map && decoded['message'] is String
            ? decoded['message'] as String
            : 'Request failed',
        statusCode: res.statusCode,
      );
    }

    return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
  }

  Future<List<dynamic>> getJsonList(
    String path, {
    Map<String, String>? queryParameters,
    required String dataKey,
  }) async {
    var uri = Uri.parse('$apiBaseUrl$path');
    if (queryParameters != null && queryParameters.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParameters);
    }
    final res = await http.get(
      uri,
      headers: _defaultHeaders(),
    );

    final decoded = jsonDecode(res.body.isEmpty ? '{}' : res.body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiError(
        message: decoded is Map && decoded['message'] is String
            ? decoded['message'] as String
            : 'Request failed',
        statusCode: res.statusCode,
      );
    }

    if (decoded is Map && decoded[dataKey] is List) {
      return decoded[dataKey] as List<dynamic>;
    }

    return const <dynamic>[];
  }
}

