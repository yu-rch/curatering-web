import '../../services/api_client.dart';
import '../../services/events_api.dart';
import '../seating/seating_plan.dart';
import 'event_design_categories.dart';

class EventsFeatureApi {
  EventsFeatureApi({required this.apiBase});

  final String apiBase;

  Future<EventDesignCategories> getEventDesignCategories() async {
    try {
      final data = await ApiClient.instance.getJson(
        '/api/mobile/event-design/categories',
        useCache: false,
      );
      return EventDesignCategories.fromJson(data);
    } catch (_) {
      return EventDesignCategories.defaults;
    }
  }

  Future<void> saveEventDesignCategories({
    required EventDesignCategories categories,
    required String staffEmail,
    required String staffPassword,
  }) async {
    await ApiClient.instance.putJson(
      '/api/mobile/event-design/categories',
      body: {'categories': categories.toJson()},
    );
  }

  Future<List<Map<String, dynamic>>> listAiGenerations(
    String userEmail, {
    String? orderId,
    String? designSessionId,
  }) async {
    try {
      final query = <String, String>{'user_email': userEmail};
      if (orderId != null && orderId.trim().isNotEmpty) {
        query['order_id'] = orderId.trim();
      } else if (designSessionId != null && designSessionId.trim().isNotEmpty) {
        query['design_session_id'] = designSessionId.trim();
      }
      final data = await ApiClient.instance.getJson(
        '/api/mobile/ai-generations',
        queryParameters: query,
        useCache: false,
      );
      final raw = data['rows'] ?? data['data'] ?? data['generations'];
      if (raw is List) {
        return raw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {}
    return const [];
  }

  Future<Map<String, dynamic>> getThemeDesign({
    required String orderId,
    required String orderKind,
    required String userEmail,
    String? cashierEmail,
    String? cashierPassword,
  }) async {
    final order = await EventsApi.instance.getEventOrder(
      orderId: orderId,
      roleType: 'manager',
    );
    final theme = order.themeDesign;
    return {
      'picksBase64': theme.picksBase64,
      'tintEnabled': theme.tintEnabled,
      if (theme.tintColorHex != null) 'tintColorHex': theme.tintColorHex,
      if (theme.colorPrompt != null) 'colorPrompt': theme.colorPrompt,
      'wantsCustomDesign': theme.wantsCustomDesign,
      if (theme.customerThemeRequest != null)
        'customerThemeRequest': theme.customerThemeRequest,
      if (theme.generatedImageUrl != null)
        'generatedImageUrl': theme.generatedImageUrl,
      if (theme.customInstructions != null)
        'customInstructions': theme.customInstructions,
      if (theme.eventDesignSource != null)
        'eventDesignSource': theme.eventDesignSource,
      if (theme.macrinaColorPalette != null)
        'macrinaColorPalette': theme.macrinaColorPalette,
      if (theme.macrinaTheme != null) 'macrinaTheme': theme.macrinaTheme,
      'costBreakdown': {
        if (theme.dishCost != null) 'dishCost': theme.dishCost,
        if (theme.laborCost != null) 'laborCost': theme.laborCost,
        if (theme.travelCost != null) 'travelCost': theme.travelCost,
      },
    };
  }

  Future<void> saveThemeDesign({
    required String orderId,
    required String orderKind,
    required Map<String, dynamic> themeDesign,
    required String userEmail,
    String? cashierEmail,
    String? cashierPassword,
  }) async {
    await ApiClient.instance.putJson(
      '/api/events/orders/${Uri.encodeComponent(orderId)}/theme-design',
      body: {'themeDesign': themeDesign, 'theme_design': themeDesign},
    );
  }

  Future<SeatingPlanData> getSeatingPlan({
    required String orderId,
    required String orderKind,
    required String userEmail,
    String? cashierEmail,
    String? cashierPassword,
  }) async {
    final order = await EventsApi.instance.getEventOrder(
      orderId: orderId,
      roleType: 'manager',
    );
    return order.seatingPlan;
  }

  Future<void> saveSeatingPlan({
    required String orderId,
    required String orderKind,
    required SeatingPlanData plan,
    required String userEmail,
    String? cashierEmail,
    String? cashierPassword,
  }) async {
    await EventsApi.instance.putStaffSeatingPlan(
      orderId: orderId,
      seatingPlan: plan.toJson(),
    );
  }
}
