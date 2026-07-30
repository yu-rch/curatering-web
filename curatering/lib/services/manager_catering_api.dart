import 'api_client.dart';

/// Manager helpers for catering/event stage metadata (additional costs, tasks).
class ManagerCateringApi {
  ManagerCateringApi._();
  static final ManagerCateringApi instance = ManagerCateringApi._();

  Future<void> patchStageData({
    required String id,
    required String orderKind,
    required Map<String, dynamic> patch,
  }) async {
    final encoded = Uri.encodeComponent(id);
    await ApiClient.instance.patchJson(
      '/api/manager/events/orders/$encoded/stage-data',
      body: {
        'orderKind': orderKind,
        'patch': patch,
      },
    );
  }
}
