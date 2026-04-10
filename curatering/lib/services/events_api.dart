import '../models/event_order.dart';
import 'api_client.dart';

class EventsApi {
  EventsApi._();

  static final EventsApi instance = EventsApi._();

  Future<List<EventOrderDto>> listOrders({
    required String status,
    required String roleType, // manager | supervisor
  }) async {
    final path = roleType == 'manager'
        ? '/api/manager/events/orders'
        : '/api/supervisor/events/orders';

    final decoded = await ApiClient.instance.getJson(
      path,
      queryParameters: {'status': status},
    );

    final raw = decoded['orders'];
    if (raw is! List) return const <EventOrderDto>[];

    return raw.map(_orderFromJson).toList();
  }

  Future<void> managerSubmitNewEventToProcessing({
    required Map<String, dynamic> payload,
  }) async {
    await ApiClient.instance.postJson(
      '/api/manager/events/orders',
      body: payload,
    );
  }

  Future<void> managerFinalizeOnlineInquiry({
    required String orderId,
    required Map<String, dynamic> payload,
  }) async {
    await ApiClient.instance.postJson(
      '/api/manager/events/orders/$orderId/finalize',
      body: payload,
    );
  }

  Future<void> supervisorUpdateProcessingOrder({
    required String orderId,
    required Map<String, dynamic> payload,
  }) async {
    await ApiClient.instance.postJson(
      '/api/supervisor/events/orders/$orderId',
      body: payload,
    );
  }

  Future<void> acceptOrder({
    required String orderId,
  }) async {
    await ApiClient.instance.postJson(
      '/api/events/orders/$orderId/accept',
      body: {},
    );
  }

  Future<void> cancelOrder({
    required String orderId,
  }) async {
    await ApiClient.instance.postJson(
      '/api/events/orders/$orderId/cancel',
      body: {},
    );
  }

  Future<void> completePostAnalysis({
    required String orderId,
    required int businessCardsGivenAway,
    required int onTheSpotInquiries,
    required int complaints,
  }) async {
    await ApiClient.instance.postJson(
      '/api/events/orders/$orderId/complete-post-analysis',
      body: {
        'businessCardsGivenAway': businessCardsGivenAway,
        'onTheSpotInquiries': onTheSpotInquiries,
        'complaints': complaints,
      },
    );
  }

  EventOrderDto _orderFromJson(dynamic raw) {
    final map = raw as Map<String, dynamic>;
    final scheduleRaw = map['scheduleSlots'];
    final scheduleSlots = <EventScheduleSlotDto>[];
    if (scheduleRaw is List) {
      for (final s in scheduleRaw) {
        final sm = s as Map<String, dynamic>;
        scheduleSlots.add(
          EventScheduleSlotDto(
            date: sm['date'] as String,
            startTime: sm['startTime'] as String,
            endTime: sm['endTime'] as String,
          ),
        );
      }
    }

    final menuRaw = map['menu'];
    final menu = <EventMenuItemDto>[];
    if (menuRaw is List) {
      for (final m in menuRaw) {
        final mm = m as Map<String, dynamic>;
        menu.add(
          EventMenuItemDto(
            dishName: mm['dishName'] as String,
            paxOption: mm['paxOption'] as String,
            price: mm['price'] as String,
          ),
        );
      }
    }

    final themeRaw = map['themeDesign'] as Map<String, dynamic>;
    final themeDesign = EventThemeDesignDto(
      picksBase64: (themeRaw['picksBase64'] as List).map((e) => e as String).toList(),
      tintEnabled: themeRaw['tintEnabled'] as bool,
      tintColorHex: themeRaw['tintColorHex'] as String?,
      colorPrompt: themeRaw['colorPrompt'] as String?,
    );

    PostAnalysisDto? postAnalysis;
    final paRaw = map['postAnalysis'];
    if (paRaw != null && paRaw is Map) {
      final pm = Map<String, dynamic>.from(paRaw);
      postAnalysis = PostAnalysisDto(
        businessCardsGivenAway: (pm['businessCardsGivenAway'] as num?)?.toInt() ?? 0,
        onTheSpotInquiries: (pm['onTheSpotInquiries'] as num?)?.toInt() ?? 0,
        complaints: (pm['complaints'] as num?)?.toInt() ?? 0,
      );
    }

    return EventOrderDto(
      id: map['id'].toString(),
      source: map['source'] as String,
      status: map['status'] as String,
      eventTitle: map['eventTitle'] as String,
      eventType: map['eventType'] as String,
      formalityLevel: map['formalityLevel'] as String,
      customerName: map['customerName'] as String,
      contactPerson: map['contactPerson'] as String,
      contactNumber: map['contactNumber'] as String,
      emailAddress: map['emailAddress'] as String,
      scheduleSlots: scheduleSlots,
      address: map['address'] as String,
      guestCount: (map['guestCount'] as num).toInt(),
      menu: menu,
      themeDesign: themeDesign,
      postAnalysis: postAnalysis,
    );
  }
}

