import 'api_client.dart';

/// Manager catering API — mirrors mobile `/api/mobile/pos/catering/*` using web JWT auth.
class ManagerCateringApi {
  ManagerCateringApi._();
  static final ManagerCateringApi instance = ManagerCateringApi._();

  Future<List<Map<String, dynamic>>> listByStage(
    String stage, {
    bool compact = false,
  }) async {
    final decoded = await ApiClient.instance.postJson(
      '/api/manager/catering/list',
      body: {'stage': stage, if (compact) 'compact': true},
    );
    final raw = decoded['orders'] ?? decoded['data'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const [];
  }

  Future<Map<String, dynamic>> getItem({
    required String id,
    required String orderKind,
  }) async {
    final decoded = await ApiClient.instance.postJson(
      '/api/manager/catering/item',
      body: {'id': id, 'order_kind': orderKind},
    );
    final order = decoded['order'];
    if (order is Map) return Map<String, dynamic>.from(order);
    return decoded;
  }

  Future<void> createNewEvent(Map<String, dynamic> body) async {
    await ApiClient.instance.postJson('/api/manager/catering/new-event', body: body);
  }

  Future<void> saveDraft({
    required String id,
    required String orderKind,
    required Map<String, dynamic> draft,
  }) async {
    await ApiClient.instance.patchJson(
      '/api/manager/catering/$id/draft',
      body: {'order_kind': orderKind, ...draft},
    );
  }

  Future<void> advanceStage({
    required String id,
    required String orderKind,
    required Map<String, dynamic> body,
  }) async {
    await ApiClient.instance.patchJson(
      '/api/manager/catering/$id/stage',
      body: {'order_kind': orderKind, ...body},
    );
  }

  /// Patch stage-related metadata (additional costs, pax buffer, etc.).
  ///
  /// Note: This replaces the older "post-analysis" wording in the web UI/API.
  Future<void> patchStageData({
    required String id,
    required String orderKind,
    required Map<String, dynamic> patch,
  }) async {
    await ApiClient.instance.patchJson(
      '/api/manager/catering/$id/stage-data-patch',
      body: {'order_kind': orderKind, 'patch': patch},
    );
  }

  /// Backwards-compatible alias. Prefer [patchStageData].
  Future<void> patchPostAnalysis({
    required String id,
    required String orderKind,
    required Map<String, dynamic> patch,
  }) async {
    return patchStageData(id: id, orderKind: orderKind, patch: patch);
  }
}
