import 'dart:convert';
import 'package:http/http.dart' as http;

/// Simple in-memory cache for API responses
class ApiCache {
  static final ApiCache _instance = ApiCache._internal();
  factory ApiCache() => _instance;
  ApiCache._internal();

  final Map<String, _CacheEntry> _cache = {};
  static const Duration _defaultExpiry = Duration(minutes: 5);

  /// Cache GET request response
  Future<http.Response> get(
    Uri uri, {
    Map<String, String>? headers,
    Duration? expiry,
    bool forceRefresh = false,
  }) async {
    final cacheKey = '${uri.toString()}_${jsonEncode(headers ?? {})}';

    // Return cached if valid
    if (!forceRefresh && _cache.containsKey(cacheKey)) {
      final entry = _cache[cacheKey]!;
      if (!entry.isExpired) {
        return http.Response(entry.body, entry.statusCode, headers: entry.responseHeaders);
      }
    }

    // Make request
    final response = await http.get(uri, headers: headers);

    // Cache successful responses
    if (response.statusCode >= 200 && response.statusCode < 300) {
      _cache[cacheKey] = _CacheEntry(
        body: response.body,
        statusCode: response.statusCode,
        responseHeaders: Map.from(response.headers),
        expiry: expiry ?? _defaultExpiry,
      );
    }

    return response;
  }

  /// Invalidate specific cache entry
  void invalidate(String urlPattern) {
    _cache.removeWhere((key, _) => key.contains(urlPattern));
  }

  /// Clear all cached responses
  void clear() {
    _cache.clear();
  }

  /// Get cache size (for debugging)
  int get cacheSize => _cache.length;
}

class _CacheEntry {
  final String body;
  final int statusCode;
  final Map<String, String> responseHeaders;
  final DateTime _timestamp;
  final Duration _expiry;

  _CacheEntry({
    required this.body,
    required this.statusCode,
    required this.responseHeaders,
    required Duration expiry,
  })  : _timestamp = DateTime.now(),
        _expiry = expiry;

  bool get isExpired => DateTime.now().difference(_timestamp) > _expiry;
}

/// Mixin for adding debounced API calls
mixin DebouncedApiCalls {
  DateTime? _lastApiCall;
  static const Duration _minApiInterval = Duration(milliseconds: 100);

  Future<T?> debouncedApiCall<T>(Future<T> Function() apiCall) async {
    final now = DateTime.now();
    if (_lastApiCall != null && now.difference(_lastApiCall!) < _minApiInterval) {
      await Future.delayed(_minApiInterval - now.difference(_lastApiCall!));
    }
    _lastApiCall = DateTime.now();
    return await apiCall();
  }
}
