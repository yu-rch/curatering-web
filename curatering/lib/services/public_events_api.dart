import 'api_client.dart';

/// Unauthenticated public endpoints (no login required).
class PublicEventsApi {
  PublicEventsApi._();
  static final PublicEventsApi instance = PublicEventsApi._();

  Future<void> submitOnlineInquiry({required Map<String, dynamic> payload}) async {
    await ApiClient.instance.postJson('/api/online-inquiries', body: payload);
  }

  Future<Map<String, dynamic>> inferThemeObjectsWithSam({
    required String imageBase64,
    double confidenceThreshold = 0.25,
    int maxDetections = 30,
    String maskFormat = 'polygon',
  }) async {
    return ApiClient.instance.postJson(
      '/api/public/events/theme-design/yolo-sam-infer',
      body: {
        'imageBase64': imageBase64,
        'confidenceThreshold': confidenceThreshold,
        'maxDetections': maxDetections,
        'maskFormat': maskFormat,
      },
    );
  }

  Future<Map<String, dynamic>> swapThemeObjectColors({
    required String imageBase64,
    required List<Map<String, dynamic>> masks,
    required List<Map<String, dynamic>> edits,
  }) async {
    return ApiClient.instance.postJson(
      '/api/public/events/theme-design/swap-colors',
      body: {
        'imageBase64': imageBase64,
        'masks': masks,
        'edits': edits,
      },
    );
  }
}
