import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_client.dart';
import '../config.dart';

/// Unauthenticated public endpoints (no login required).
class PublicEventsApi {
  PublicEventsApi._();
  static final PublicEventsApi instance = PublicEventsApi._();
  static const Duration _aiTimeout = Duration(seconds: 45);

  Future<void> submitOnlineInquiry({required Map<String, dynamic> payload}) async {
    // Public inquiry submit should not include Authorization header from any
    // active staff/customer session; keep this endpoint anonymous.
    final res = await http.post(
      Uri.parse('$apiBaseUrl/api/online-inquiries'),
      headers: const <String, String>{'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiError(
        message: 'Failed to submit online inquiry',
        statusCode: res.statusCode,
      );
    }
  }

  Future<Map<String, dynamic>> inferThemeObjectsWithSam({
    required String imageBase64,
    double confidenceThreshold = 0.25,
    int maxDetections = 30,
    String maskFormat = 'polygon',
  }) async {
    return ApiClient.instance
        .postJson(
          '/api/public/events/theme-design/yolo-sam-infer',
          body: {
            'imageBase64': imageBase64,
            'confidenceThreshold': confidenceThreshold,
            'maxDetections': maxDetections,
            'maskFormat': maskFormat,
          },
        )
        .timeout(_aiTimeout);
  }

  Future<Map<String, dynamic>> swapThemeObjectColors({
    required String imageBase64,
    required List<Map<String, dynamic>> masks,
    required List<Map<String, dynamic>> edits,
  }) async {
    return ApiClient.instance
        .postJson(
          '/api/public/events/theme-design/swap-colors',
          body: {
            'imageBase64': imageBase64,
            'masks': masks,
            'edits': edits,
          },
        )
        .timeout(_aiTimeout);
  }
}
