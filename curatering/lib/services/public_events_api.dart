import 'api_client.dart';

/// Unauthenticated public endpoints (no login required).
class PublicEventsApi {
  PublicEventsApi._();
  static final PublicEventsApi instance = PublicEventsApi._();

  Future<void> submitOnlineInquiry({required Map<String, dynamic> payload}) async {
    await ApiClient.instance.postJson('/api/online-inquiries', body: payload);
  }
}
