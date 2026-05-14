import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_client.dart';
import '../config.dart';

/// Unauthenticated public endpoints (no login required).
class PublicEventsApi {
  PublicEventsApi._();
  static final PublicEventsApi instance = PublicEventsApi._();
  static const Duration _aiTimeout = Duration(seconds: 180);
  /// Composite rendering often runs longer than search/extract.
  static const Duration _compositeTimeout = Duration(seconds: 180);

  Future<void> submitOnlineInquiry({required Map<String, dynamic> payload}) async {
    final res = await http.post(
      Uri.parse('$apiBaseUrl/api/online-inquiries'),
      headers: const <String, String>{'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      var msg = 'Failed to submit online inquiry (${res.statusCode})';
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map && decoded['message'] != null) {
          msg = decoded['message'].toString();
        }
      } catch (_) {}
      throw ApiError(message: msg, statusCode: res.statusCode);
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

  Future<Map<String, dynamic>> searchThemeImages({
    required String eventTitle,
    required String eventType,
    required String formalityLevel,
    required String prompt,
    String? baseImageUrl,
    List<String> tags = const [],
    int page = 1,
    int perPage = 12,
  }) async {
    return ApiClient.instance
        .postJson(
          '/api/public/events/theme-design/theme-search',
          body: {
            'eventTitle': eventTitle,
            'eventType': eventType,
            'formalityLevel': formalityLevel,
            'prompt': prompt,
            'baseImageUrl': baseImageUrl,
            'tags': tags,
            'page': page,
            'perPage': perPage,
          },
        )
        .timeout(_aiTimeout);
  }

  Future<Map<String, dynamic>> addThemeObjectsByPrompt({
    required String baseImageBase64,
    required String eventTitle,
    required String eventType,
    required String formalityLevel,
    required String prompt,
    String? baseImageUrl,
  }) async {
    return ApiClient.instance
        .postJson(
          '/api/public/events/theme-design/add-by-prompt',
          body: {
            'baseImageBase64': baseImageBase64,
            'eventTitle': eventTitle,
            'eventType': eventType,
            'formalityLevel': formalityLevel,
            'prompt': prompt,
            'baseImageUrl': baseImageUrl,
          },
        )
        .timeout(_compositeTimeout);
  }

  Future<Map<String, dynamic>> extractThemeObjects({
    required List<String> imagesBase64,
    double confidenceThreshold = 0.25,
    int maxDetections = 20,
  }) async {
    return ApiClient.instance
        .postJson(
          '/api/public/events/theme-design/extract-objects',
          body: {
            'imagesBase64': imagesBase64,
            'confidenceThreshold': confidenceThreshold,
            'maxDetections': maxDetections,
          },
        )
        .timeout(_aiTimeout);
  }

  Future<Map<String, dynamic>> analyzeBaseImage({
    required String baseImageBase64,
  }) async {
    return ApiClient.instance
        .postJson(
          '/api/public/events/theme-design/analyze-base',
          body: {'baseImageBase64': baseImageBase64},
        )
        .timeout(_aiTimeout);
  }

  Future<Map<String, dynamic>> autoPlaceThemeObjects({
    required List<Map<String, dynamic>> freeSpaces,
    required List<Map<String, dynamic>> objects,
  }) async {
    return ApiClient.instance
        .postJson(
          '/api/public/events/theme-design/auto-place',
          body: {
            'freeSpaces': freeSpaces,
            'objects': objects,
          },
        )
        .timeout(_aiTimeout);
  }

  Future<Map<String, dynamic>> renderThemeComposite({
    required String baseImageBase64,
    required List<Map<String, dynamic>> objects,
  }) async {
    return ApiClient.instance
        .postJson(
          '/api/public/events/theme-design/render-composite',
          body: {
            'baseImageBase64': baseImageBase64,
            'objects': objects,
          },
        )
        .timeout(_compositeTimeout);
  }
}
