import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/auth_session.dart';
import '../config.dart';
import '../utils/api_cache.dart';

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

  static const Duration _requestTimeout = Duration(seconds: 30);

  /// Customer JWT from SharedPreferences (checkout / cart); staff uses [AuthSession].
  String? _customerBearer;

  void setCustomerBearer(String? token) {
    _customerBearer = token?.trim().isEmpty == true ? null : token?.trim();
  }

  void clearCustomerBearer() {
    _customerBearer = null;
  }

  String _resolveUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    return '$apiBaseUrl$path';
  }

  Map<String, String> _defaultHeaders() {
    final headers = <String, String>{'Content-Type': 'application/json'};
    final token = AuthSession.instance.token ?? _customerBearer;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
    Duration? timeout,
  }) async {
    final uri = Uri.parse(_resolveUrl(path));
    final res = await http
        .post(
          uri,
          headers: _defaultHeaders(),
          body: body == null ? null : jsonEncode(body),
        )
        .timeout(timeout ?? _requestTimeout);

    return _handleResponse(res, uri);
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? queryParameters,
    bool useCache = true,
    Duration? cacheExpiry,
  }) async {
    var uri = Uri.parse(_resolveUrl(path));
    if (queryParameters != null && queryParameters.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParameters);
    }

    final res =
        useCache
            ? await ApiCache().get(
              uri,
              headers: _defaultHeaders(),
              expiry: cacheExpiry ?? const Duration(minutes: 2),
            )
            : await http
                .get(uri, headers: _defaultHeaders())
                .timeout(_requestTimeout);

    return _handleResponse(res, uri);
  }

  Future<List<dynamic>> getJsonList(
    String path, {
    Map<String, String>? queryParameters,
    required String dataKey,
  }) async {
    var uri = Uri.parse(_resolveUrl(path));
    if (queryParameters != null && queryParameters.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParameters);
    }
    final res = await http
        .get(uri, headers: _defaultHeaders())
        .timeout(_requestTimeout);

    final decoded = _parseResponse(res, uri);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiError(
        message:
            decoded is Map && decoded['message'] is String
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

  Future<Map<String, dynamic>> putJson(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse(_resolveUrl(path));
    final res = await http
        .put(
          uri,
          headers: _defaultHeaders(),
          body: body == null ? null : jsonEncode(body),
        )
        .timeout(_requestTimeout);

    final decoded = _handleResponse(res, uri);
    ApiCache().invalidate(path);
    return decoded;
  }

  Future<Map<String, dynamic>> patchJson(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse(_resolveUrl(path));
    final res = await http
        .patch(
          uri,
          headers: _defaultHeaders(),
          body: body == null ? null : jsonEncode(body),
        )
        .timeout(_requestTimeout);

    return _handleResponse(res, uri);
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse(_resolveUrl(path));
    final res = await http
        .delete(
          uri,
          headers: _defaultHeaders(),
          body: body == null ? null : jsonEncode(body),
        )
        .timeout(_requestTimeout);

    return _handleResponse(res, uri);
  }

  /// Parse response body and detect HTML error pages
  dynamic _parseResponse(http.Response res, Uri uri) {
    final contentType = res.headers['content-type'] ?? '';
    final body = res.body.isEmpty ? '{}' : res.body;

    if (body.trim().startsWith('<!DOCTYPE') ||
        body.trim().startsWith('<html') ||
        contentType.contains('text/html')) {
      throw ApiError(
        message:
            'Server returned HTML error page. Status: ${res.statusCode}. URL: $uri',
        statusCode: res.statusCode,
      );
    }

    return jsonDecode(body);
  }

  /// Handle response and return Map for successful requests
  Map<String, dynamic> _handleResponse(http.Response res, Uri uri) {
    final decoded = _parseResponse(res, uri);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      String buildMessage() {
        final message =
            decoded is Map && decoded['message'] is String
                ? decoded['message'] as String
                : 'Request failed';
        final code =
            decoded is Map && decoded['code'] is String
                ? decoded['code'] as String
                : null;
        final details = decoded is Map ? decoded['details'] : null;

        // Keep message readable; include details when backend provides them.
        if (details != null) {
          final detailsStr = details is String ? details : details.toString();
          final shortDetails =
              detailsStr.length > 500
                  ? '${detailsStr.substring(0, 500)}…'
                  : detailsStr;
          return code != null
              ? '$message (code: $code). Details: $shortDetails'
              : '$message. Details: $shortDetails';
        }
        return code != null ? '$message (code: $code)' : message;
      }

      throw ApiError(message: buildMessage(), statusCode: res.statusCode);
    }

    return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
  }
}
