import 'dart:convert';

import '../models/event_order.dart';
import 'api_client.dart';
import 'public_events_api.dart';

class EventsApi {
  EventsApi._();

  static final EventsApi instance = EventsApi._();

  Future<List<EventOrderDto>> listOrders({
    required String status,
    required String roleType, // manager | supervisor
    bool compact = false,
  }) async {
    final path =
        roleType == 'manager'
            ? '/api/manager/events/orders'
            : '/api/supervisor/events/orders';

    final qp = <String, String>{'status': status};
    if (compact) qp['compact'] = '1';

    final decoded = await ApiClient.instance.getJson(
      path,
      queryParameters: qp,
      useCache: false,
    );

    final raw = decoded['orders'] ?? decoded['data'];
    if (raw is! List) {
      return const <EventOrderDto>[];
    }

    return raw.map(_orderFromJson).toList();
  }

  Future<EventOrderDto> getEventOrder({
    required String orderId,
    required String roleType,
  }) async {
    final encoded = Uri.encodeComponent(orderId);
    final path =
        roleType == 'manager'
            ? '/api/manager/events/orders/$encoded'
            : '/api/supervisor/events/orders/$encoded';

    final decoded = await ApiClient.instance.getJson(path, useCache: false);
    final raw = decoded['order'];
    if (raw is! Map) {
      throw Exception('Invalid order response');
    }
    return _orderFromJson(raw);
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

  Future<void> acceptOrder({required String orderId}) async {
    await ApiClient.instance.postJson(
      '/api/events/orders/$orderId/accept',
      body: {},
    );
  }

  Future<void> cancelOrder({required String orderId}) async {
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

  // Checklist CRUD operations
  Future<void> addChecklistItem({
    required String orderId,
    required ChecklistItemDto item,
  }) async {
    await ApiClient.instance.postJson(
      '/api/events/orders/$orderId/checklist',
      body: {
        'id': item.id,
        'title': item.title,
        'description': item.description,
        'price': item.price,
        'assignedTo': item.assignedTo,
        'isCompleted': item.isCompleted,
      },
    );
  }

  Future<void> updateChecklistItem({
    required String orderId,
    required String itemId,
    required bool isCompleted,
    required String title,
    required String description,
    required double price,
    required String assignedTo,
  }) async {
    await ApiClient.instance.putJson(
      '/api/events/orders/$orderId/checklist/$itemId',
      body: {
        'isCompleted': isCompleted,
        'title': title,
        'description': description,
        'price': price,
        'assignedTo': assignedTo,
      },
    );
  }

  Future<void> deleteChecklistItem({
    required String orderId,
    required String itemId,
  }) async {
    await ApiClient.instance.delete(
      '/api/events/orders/$orderId/checklist/$itemId',
    );
  }

  // Payment status updates
  Future<void> updatePaymentStatus({
    required String orderId,
    required String paymentType, // 'down_payment' or 'full_payment'
    required String status, // 'paid' or 'pending'
    String? referenceNumber,
  }) async {
    final body = {'paymentType': paymentType, 'status': status};
    if (referenceNumber != null && referenceNumber.isNotEmpty) {
      body['referenceNumber'] = referenceNumber;
    }
    await ApiClient.instance.putJson(
      '/api/events/orders/$orderId/payment-status',
      body: body,
    );
  }

  // Event photos updates
  Future<void> updateEventPhotos({
    required String orderId,
    required List<String> photos,
  }) async {
    await ApiClient.instance.putJson(
      '/api/events/orders/$orderId/event-photos',
      body: {'photos': photos},
    );
  }

  Future<void> removeEventPhoto({
    required String orderId,
    required int photoIndex,
  }) async {
    await ApiClient.instance.delete(
      '/api/events/orders/$orderId/event-photos/$photoIndex',
    );
  }

  Future<Map<String, dynamic>> processThemeColor({
    required List<String> picksBase64,
    required String prompt,
    String? currentTintColorHex,
  }) async {
    return ApiClient.instance.postJson(
      '/api/events/theme-design/swap-colors',
      body: {
        'picksBase64': picksBase64,
        'prompt': prompt,
        'currentTintColorHex': currentTintColorHex,
      },
    );
  }

  Future<Map<String, dynamic>> inferThemeObjectsWithSam({
    required String imageBase64,
    double confidenceThreshold = 0.25,
    int maxDetections = 30,
    String maskFormat = 'polygon',
  }) async {
    try {
      return await ApiClient.instance.postJson(
        '/api/events/theme-design/yolo-sam-infer',
        body: {
          'imageBase64': imageBase64,
          'confidenceThreshold': confidenceThreshold,
          'maxDetections': maxDetections,
          'maskFormat': maskFormat,
        },
      );
    } on ApiError catch (e) {
      final msg = e.message.toLowerCase();
      // Fallback for local setups where internal AI token is missing.
      if (msg.contains('ai service token') ||
          msg.contains('not configured') ||
          e.statusCode == 500) {
        return PublicEventsApi.instance.inferThemeObjectsWithSam(
          imageBase64: imageBase64,
          confidenceThreshold: confidenceThreshold,
          maxDetections: maxDetections,
          maskFormat: maskFormat,
        );
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> swapThemeObjectColors({
    required String imageBase64,
    required List<Map<String, dynamic>> masks,
    required List<Map<String, dynamic>> edits,
  }) async {
    try {
      return await ApiClient.instance.postJson(
        '/api/events/theme-design/swap-colors',
        body: {'imageBase64': imageBase64, 'masks': masks, 'edits': edits},
      );
    } on ApiError catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('ai service token') ||
          msg.contains('not configured') ||
          e.statusCode == 500) {
        return PublicEventsApi.instance.swapThemeObjectColors(
          imageBase64: imageBase64,
          masks: masks,
          edits: edits,
        );
      }
      rethrow;
    }
  }

  int _toInt(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    if (value is num) return value.toInt();
    final parsed = num.tryParse(value.toString().trim());
    return parsed?.toInt() ?? fallback;
  }

  double _toDouble(dynamic value, {double fallback = 0.0}) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    final parsed = num.tryParse(value.toString().trim());
    return parsed?.toDouble() ?? fallback;
  }

  double? _toNullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    final parsed = num.tryParse(value.toString().trim());
    return parsed?.toDouble();
  }

  bool _toBool(dynamic value, {bool fallback = false}) {
    if (value == null) return fallback;
    if (value is bool) return value;
    final raw = value.toString().trim().toLowerCase();
    if (raw == 'true' || raw == '1' || raw == 'yes') return true;
    if (raw == 'false' || raw == '0' || raw == 'no') return false;
    return fallback;
  }

  Map<String, dynamic> _toMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return const <String, dynamic>{};
      try {
        final parsed = jsonDecode(trimmed);
        if (parsed is Map) return Map<String, dynamic>.from(parsed);
      } catch (_) {}
    }
    return const <String, dynamic>{};
  }

  List<dynamic> _toList(dynamic value) {
    if (value is List) return value;
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return const <dynamic>[];
      try {
        final parsed = jsonDecode(trimmed);
        if (parsed is List) return parsed;
      } catch (_) {}
    }
    return const <dynamic>[];
  }

  EventOrderDto _orderFromJson(dynamic raw) {
    final map = _toMap(raw);
    final scheduleRaw = map['scheduleSlots'] ?? map['schedule_slots'];
    final scheduleSlots = <EventScheduleSlotDto>[];
    for (final s in _toList(scheduleRaw)) {
      final sm = _toMap(s);
      if (sm.isEmpty) continue;
      scheduleSlots.add(
        EventScheduleSlotDto(
          date: (sm['date'] ?? '').toString(),
          startTime: (sm['startTime'] ?? sm['start_time'] ?? '').toString(),
          endTime: (sm['endTime'] ?? sm['end_time'] ?? '').toString(),
        ),
      );
    }

    final menuRaw = map['menu'];
    final menu = <EventMenuItemDto>[];
    for (final m in _toList(menuRaw)) {
      final mm = _toMap(m);
      if (mm.isEmpty) continue;
      menu.add(
        EventMenuItemDto(
          dishName: (mm['dishName'] ?? mm['dish_name'] ?? '').toString(),
          paxOption: (mm['paxOption'] ?? mm['pax_option'] ?? '').toString(),
          price: mm['price']?.toString() ?? '0',
        ),
      );
    }

    final rawTheme = map['themeDesign'] ?? map['theme_design'];
    final themeRaw = _toMap(rawTheme);
    final costBreakdown = _toMap(
      themeRaw['costBreakdown'] ?? themeRaw['cost_breakdown'],
    );
    final themeDesign = EventThemeDesignDto(
      picksBase64:
          _toList(themeRaw['picksBase64']).map((e) => e.toString()).toList(),
      tintEnabled: _toBool(themeRaw['tintEnabled']),
      tintColorHex: themeRaw['tintColorHex'] as String?,
      colorPrompt: themeRaw['colorPrompt'] as String?,
      wantsCustomDesign: _toBool(
        themeRaw['wantsCustomDesign'] ?? themeRaw['wants_custom_design'],
      ),
      customerThemeRequest:
          (themeRaw['customerThemeRequest'] ??
                  themeRaw['customer_theme_request'])
              ?.toString(),
      dishCost: _toNullableDouble(
        costBreakdown['dishCost'] ?? costBreakdown['dish_cost'],
      ),
      laborCost: _toNullableDouble(
        costBreakdown['laborCost'] ?? costBreakdown['labor_cost'],
      ),
      travelCost: _toNullableDouble(
        costBreakdown['travelCost'] ?? costBreakdown['travel_cost'],
      ),
    );

    PostAnalysisDto? postAnalysis;
    final paRaw = map['postAnalysis'] ?? map['post_analysis'];
    final pm = _toMap(paRaw);
    if (pm.isNotEmpty) {
      postAnalysis = PostAnalysisDto(
        businessCardsGivenAway: _toInt(
          pm['businessCardsGivenAway'] ?? pm['business_cards_given_away'],
        ),
        onTheSpotInquiries: _toInt(
          pm['onTheSpotInquiries'] ?? pm['on_the_spot_inquiries'],
        ),
        complaints: _toInt(pm['complaints']),
      );
    }

    final checklistRaw = map['checklist'];
    final checklist = <ChecklistItemDto>[];
    for (final c in _toList(checklistRaw)) {
      final cc = _toMap(c);
      if (cc.isEmpty) continue;
      checklist.add(
        ChecklistItemDto(
          id: cc['id'] as String? ?? '',
          title: cc['title'] as String? ?? '',
          description: cc['description'] as String? ?? '',
          price: _toDouble(cc['price']),
          isCompleted: cc['isCompleted'] as bool? ?? false,
          assignedTo: cc['assignedTo'] as String? ?? '',
        ),
      );
    }

    final actualEventImages = <String>[];
    for (final img in _toList(map['actualEventImages'])) {
      final value = img.toString().trim();
      if (value.isNotEmpty) actualEventImages.add(value);
    }

    return EventOrderDto(
      id: (map['id'] ?? '').toString(),
      source: (map['source'] ?? '').toString(),
      status: (map['status'] ?? '').toString(),
      themeAssetsDeferred: _toBool(map['listSummaryOnly']),
      eventTitle: map['eventTitle'] as String? ?? '',
      orderType: map['orderType'] as String? ?? 'catering',
      eventType: map['eventType'] as String? ?? '',
      formalityLevel: map['formalityLevel'] as String? ?? '',
      customerName:
          (map['customerName'] ?? map['customer_name'] ?? '').toString(),
      contactPerson:
          (map['contactPerson'] ?? map['contact_person'] ?? '').toString(),
      contactNumber:
          (map['contactNumber'] ?? map['contact_number'] ?? '').toString(),
      emailAddress:
          (map['emailAddress'] ?? map['email_address'] ?? '').toString(),
      scheduleSlots: scheduleSlots,
      address: (map['address'] ?? '').toString(),
      guestCount: _toInt(map['guestCount'] ?? map['guest_count']),
      menu: menu,
      themeDesign: themeDesign,
      postAnalysis: postAnalysis,
      downPaymentAmount: _toDouble(
        map['downPaymentAmount'] ?? map['down_payment_amount'],
      ),
      downPaymentStatus:
          (map['downPaymentStatus'] ?? map['down_payment_status'] ?? 'pending')
              .toString(),
      fullPaymentAmount: _toDouble(
        map['fullPaymentAmount'] ?? map['full_payment_amount'],
      ),
      fullPaymentStatus:
          (map['fullPaymentStatus'] ?? map['full_payment_status'] ?? 'pending')
              .toString(),
      totalCost: _toDouble(map['totalCost'] ?? map['total_cost']),
      checklist: checklist,
      actualEventImages: actualEventImages,
      finalStatus:
          (map['finalStatus'] ?? map['final_status'] ?? 'successful')
              .toString(),
    );
  }
}
