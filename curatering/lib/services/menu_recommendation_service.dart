import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import 'api_client.dart';

/// Public menu recommendation via RunPod Qwen3 (server proxy).
class MenuRecommendationService {
  MenuRecommendationService._();
  static final MenuRecommendationService instance =
      MenuRecommendationService._();

  static const Duration _timeout = Duration(seconds: 60);

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
        .timeout(_timeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      var msg = 'Menu recommendation failed (${response.statusCode})';
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['error'] != null) {
          msg = decoded['error'].toString();
        }
      } catch (_) {}
      throw ApiError(message: msg, statusCode: response.statusCode);
    }

    final data = jsonDecode(response.body);
    if (data is! Map) {
      throw ApiError(message: 'Invalid menu recommendation response');
    }
    return MenuRecommendationResult.fromJson(
      Map<String, dynamic>.from(data),
    );
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
