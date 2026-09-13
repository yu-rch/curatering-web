import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import 'api_client.dart';

/// Public menu recommendation via RunPod Qwen3 (server proxy).
class MenuRecommendationService {
  MenuRecommendationService._();
  static final MenuRecommendationService instance =
      MenuRecommendationService._();

  static const Duration _startTimeout = Duration(seconds: 20);
  static const Duration _pollTimeout = Duration(seconds: 20);
  static const Duration _overallTimeout = Duration(seconds: 180);
  static const Duration _pollInterval = Duration(seconds: 2);

  Future<MenuRecommendationResult> recommend({
    required String eventType,
    required String eventTitle,
    required String eventSetting,
    required int guestCount,
    required List<String> allergens,
    required List<Map<String, dynamic>> dishes,
  }) async {
    final uri = Uri.parse('$apiBaseUrl/api/recommend-menu');
    final response = await http
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'eventType': eventType,
            'eventTitle': eventTitle,
            'eventSetting': eventSetting,
            'guestCount': guestCount,
            'allergens': allergens,
            'dishes': dishes,
          }),
        )
        .timeout(_startTimeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiError(
        message: _errorMessage(
          response,
          'Menu recommendation failed (${response.statusCode})',
        ),
        statusCode: response.statusCode,
      );
    }

    final data = _decodeMap(response.body);
    if (data['dishIds'] is List) {
      return MenuRecommendationResult.fromJson(data);
    }

    final jobId = data['jobId']?.toString().trim() ?? '';
    if (jobId.isEmpty) {
      throw ApiError(message: 'Invalid menu recommendation response');
    }

    return _pollJob(jobId);
  }

  Future<MenuRecommendationResult> _pollJob(String jobId) async {
    final deadline = DateTime.now().add(_overallTimeout);
    final statusUri = Uri.parse(
      '$apiBaseUrl/api/recommend-menu/${Uri.encodeComponent(jobId)}',
    );

    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(_pollInterval);
      final response = await http.get(statusUri).timeout(_pollTimeout);

      if (response.statusCode == 404) {
        throw ApiError(
          message: 'Menu recommendation expired. Please try again.',
          statusCode: 404,
        );
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiError(
          message: _errorMessage(
            response,
            'Menu recommendation failed (${response.statusCode})',
          ),
          statusCode: response.statusCode,
        );
      }

      final data = _decodeMap(response.body);
      final status = data['status']?.toString().toLowerCase() ?? '';
      if (status == 'completed' || data['dishIds'] is List) {
        return MenuRecommendationResult.fromJson(data);
      }
      if (status == 'failed') {
        throw ApiError(
          message: data['error']?.toString() ??
              'Unable to generate menu recommendation',
        );
      }
    }

    throw ApiError(
      message:
          'Menu recommendation took too long. Please try again in a moment.',
    );
  }

  Map<String, dynamic> _decodeMap(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw ApiError(message: 'Invalid menu recommendation response');
    }
    return Map<String, dynamic>.from(decoded);
  }

  String _errorMessage(http.Response response, String fallback) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['error'] != null) {
        return decoded['error'].toString();
      }
    } catch (_) {}
    return fallback;
  }
}

class MenuRecommendationResult {
  const MenuRecommendationResult({
    required this.dishIds,
    required this.dishes,
    required this.summary,
    required this.notes,
  });

  final List<String> dishIds;
  final List<Map<String, dynamic>> dishes;
  final String summary;
  final List<String> notes;

  factory MenuRecommendationResult.fromJson(Map<String, dynamic> json) {
    return MenuRecommendationResult(
      dishIds: (json['dishIds'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
      dishes: (json['dishes'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
      summary: json['summary']?.toString() ?? '',
      notes: (json['notes'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}
