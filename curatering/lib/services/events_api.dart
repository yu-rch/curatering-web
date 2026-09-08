import 'dart:convert';

import '../models/event_order.dart';
import '../models/seating_plan.dart';
import 'api_client.dart';
import '../utils/api_cache.dart';
import 'public_events_api.dart';

class EventsApi {
  EventsApi._();

  static final EventsApi instance = EventsApi._();

  /// Parse a catering/event order map from any staff API response.
  EventOrderDto parseOrder(Map<String, dynamic> map) => _orderFromJson(map);

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

  Future<void> putStaffSeatingPlan({
    required String orderId,
    required Map<String, dynamic> seatingPlan,
  }) async {
    final encoded = Uri.encodeComponent(orderId);
    await ApiClient.instance.putJson(
      '/api/events/orders/$encoded/seating',
      body: {'seatingPlan': seatingPlan},
    );
  }

  Future<void> acceptOrder({required String orderId}) async {
    final encoded = Uri.encodeComponent(orderId);
    await ApiClient.instance.postJson(
      '/api/events/orders/$encoded/accept',
      body: {},
    );
  }

  Future<void> postOrderChanges({required String orderId}) async {
    final encoded = Uri.encodeComponent(orderId);
    await ApiClient.instance.postJson(
      '/api/events/orders/$encoded/post-changes',
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

  /// Mark order completed (no post-analysis form). Falls back to catering route.
  Future<void> completeOrder({required String orderId}) async {
    final encoded = Uri.encodeComponent(orderId);
    try {
      await ApiClient.instance.postJson(
        '/api/events/orders/$encoded/complete',
        body: {},
      );
    } on ApiError catch (e) {
      if (e.statusCode == 404) {
        await ApiClient.instance.postJson(
          '/api/catering/orders/$encoded/complete',
          body: {},
        );
        return;
      }
      rethrow;
    }
  }

  Future<void> replaceChecklist({
    required String orderId,
    required List<Map<String, dynamic>> items,
    bool deductInventory = false,
  }) async {
    final encoded = Uri.encodeComponent(orderId);
    await ApiClient.instance.putJson(
      '/api/events/orders/$encoded/checklist',
      body: {'checklist': items, if (deductInventory) 'deductInventory': true},
    );
    ApiCache().invalidate('/api/manager/events/orders');
    ApiCache().invalidate('/api/supervisor/events/orders');
  }

  Future<void> sendOrderSummaryEmail({
    required String orderId,
    required String pdfBase64,
    required String paymentType,
  }) async {
    final encoded = Uri.encodeComponent(orderId);
    await ApiClient.instance.postJson(
      '/api/events/orders/$encoded/send-order-summary',
      body: {'pdfBase64': pdfBase64, 'paymentType': paymentType},
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
    String? paymentMethod,
    double? amount,
    String? paymentProofBase64,
  }) async {
    final body = <String, dynamic>{
      'paymentType': paymentType,
      'status': status,
    };
    if (referenceNumber != null && referenceNumber.isNotEmpty) {
      body['referenceNumber'] = referenceNumber;
    }
    if (paymentMethod != null && paymentMethod.isNotEmpty) {
      body['paymentMethod'] = paymentMethod;
    }
    if (amount != null && amount >= 0) {
      body['amount'] = amount;
    }
    if (paymentProofBase64 != null && paymentProofBase64.trim().isNotEmpty) {
      body['paymentProof'] = paymentProofBase64.trim();
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

  /// Plain array or mobile-packed `{ items: [...] }` (optionally with `post_analysis`).
  List<dynamic> _checklistItemsList(dynamic value) {
    if (value is List) return value;
    if (value is Map) {
      final items = value['items'];
      if (items is List) return items;
      return const <dynamic>[];
    }
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return const <dynamic>[];
      try {
        return _checklistItemsList(jsonDecode(trimmed));
      } catch (_) {}
    }
    return const <dynamic>[];
  }

  bool _checklistItemIsCompleted(Map<String, dynamic> cc) {
    if (cc['isCompleted'] == true) return true;
    final status = '${cc['status'] ?? ''}'.trim().toLowerCase();
    if (status.isEmpty) return false;
    if (status.contains('not')) return false;
    return status == 'completed' ||
        status == 'done' ||
        status.contains('completed') ||
        status.contains('done');
  }

  List<String> _toStringList(dynamic value) {
    return _toList(value)
        .map((e) => e.toString().trim())
        .where((s) => s.isNotEmpty)
        .toList();
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

      final setMenuName =
          (mm['setMenuName'] ?? mm['set_menu_name'] ?? '').toString().trim();
      final dishAllergens =
          (mm['dishAllergens'] ?? mm['dish_allergens'] ?? '').toString().trim();

      final dishNameRaw = mm['dishName'] ?? mm['dish_name'];
      if (dishNameRaw != null && dishNameRaw.toString().trim().isNotEmpty) {
        final addCharge = _toDouble(
          mm['additionalChargeAmount'] ??
              mm['additional_charge_amount'] ??
              mm['menu_dishes_additional_charge_amount'] ??
              0,
        );
        menu.add(
          EventMenuItemDto(
            dishName: dishNameRaw.toString().trim(),
            paxOption: (mm['paxOption'] ?? mm['pax_option'] ?? '').toString(),
            price: mm['price']?.toString() ?? '0',
            setMenuName: setMenuName,
            dishAllergens: dishAllergens,
            additionalChargeAmount: addCharge,
          ),
        );
        continue;
      }

      final names = mm['dishNames'] ?? mm['dish_names'];
      if (names is List) {
        for (final n in names) {
          final name = n.toString().trim();
          if (name.isEmpty) continue;
          menu.add(
            EventMenuItemDto(
              dishName: name,
              paxOption: '',
              price: '0',
              setMenuName: setMenuName,
            ),
          );
        }
      }
    }

    final rawTheme = map['themeDesign'] ?? map['theme_design'];
    final themeRaw = _toMap(rawTheme);
    final costBreakdown = _toMap(
      themeRaw['costBreakdown'] ?? themeRaw['cost_breakdown'],
    );
    final customInstructions =
        (themeRaw['customInstructions'] ??
                themeRaw['custom_instructions'] ??
                themeRaw['colorPrompt'] ??
                themeRaw['color_prompt'])
            ?.toString();
    final macrinaPalette =
        (themeRaw['macrinaColorPalette'] ?? themeRaw['macrina_color_palette'])
            ?.toString();
    final macrinaTheme =
        (themeRaw['macrinaTheme'] ?? themeRaw['macrina_theme'])?.toString();
    final generatedImageUrl =
        (themeRaw['generatedImageUrl'] ??
                themeRaw['generated_image_url'] ??
                themeRaw['imageUrl'] ??
                themeRaw['image_url'])
            ?.toString();
    final eventDesignSource =
        (themeRaw['eventDesignSource'] ?? themeRaw['event_design_source'])
            ?.toString();
    final style = (themeRaw['style'] ?? '')?.toString();
    final mood = (themeRaw['mood'] ?? '')?.toString();
    final colorPalette = _toStringList(
      themeRaw['colorPalette'] ?? themeRaw['color_palette'],
    );
    final decorElements = _toStringList(
      themeRaw['decorElements'] ?? themeRaw['decor_elements'],
    );
    final customerNote =
        (themeRaw['customerNote'] ??
                themeRaw['customer_note'] ??
                themeRaw['note'])
            ?.toString();

    String? customerThemeRequest =
        (themeRaw['customerThemeRequest'] ?? themeRaw['customer_theme_request'])
            ?.toString();
    if ((customerThemeRequest == null || customerThemeRequest.trim().isEmpty) &&
        eventDesignSource == 'macrina') {
      final parts = <String>[];
      if (macrinaPalette != null && macrinaPalette.trim().isNotEmpty) {
        parts.add('Palette: $macrinaPalette');
      }
      if (macrinaTheme != null && macrinaTheme.trim().isNotEmpty) {
        parts.add('Theme: $macrinaTheme');
      }
      if (parts.isNotEmpty) customerThemeRequest = parts.join('\n');
    }

    final themeDesign = EventThemeDesignDto(
      picksBase64:
          _toList(themeRaw['picksBase64']).map((e) => e.toString()).toList(),
      tintEnabled: _toBool(themeRaw['tintEnabled']),
      tintColorHex: themeRaw['tintColorHex'] as String?,
      colorPrompt: themeRaw['colorPrompt'] as String?,
      wantsCustomDesign: _toBool(
        themeRaw['wantsCustomDesign'] ?? themeRaw['wants_custom_design'],
      ),
      customerThemeRequest: customerThemeRequest,
      generatedImageUrl: generatedImageUrl,
      customInstructions: customInstructions,
      eventDesignSource: eventDesignSource,
      style: style?.trim().isEmpty == true ? null : style,
      mood: mood?.trim().isEmpty == true ? null : mood,
      colorPalette: colorPalette,
      decorElements: decorElements,
      customerNote: customerNote?.trim().isEmpty == true ? null : customerNote,
      macrinaColorPalette: macrinaPalette,
      macrinaTheme: macrinaTheme,
      dishCost: _toNullableDouble(
        costBreakdown['dishCost'] ?? costBreakdown['dish_cost'],
      ),
      laborCost: _toNullableDouble(
        costBreakdown['laborCost'] ??
            costBreakdown['labor_cost'] ??
            themeRaw['laborCost'] ??
            themeRaw['labor_cost'],
      ),
      travelCost: _toNullableDouble(
        costBreakdown['travelCost'] ??
            costBreakdown['travel_cost'] ??
            themeRaw['travelCost'] ??
            themeRaw['travel_cost'],
      ),
    );

    final seatingPlan = SeatingPlanData.fromJson(
      map['seatingPlan'] ?? map['seating_plan'],
    );

    PostAnalysisDto? postAnalysis;
    final paRaw = map['postAnalysis'] ?? map['post_analysis'];
    final pm = Map<String, dynamic>.from(_toMap(paRaw));
    // Surface top-level payment columns so Manage Events can reflect confirm inputs.
    final paymentMethod =
        (map['paymentMethod'] ?? map['payment_method'] ?? '').toString().trim();
    if (paymentMethod.isNotEmpty) {
      pm.putIfAbsent('payment_method', () => paymentMethod);
    }
    final downPaymentReference =
        (map['downPaymentReference'] ?? map['down_payment_reference'] ?? '')
            .toString()
            .trim();
    if (downPaymentReference.isNotEmpty) {
      pm.putIfAbsent('down_payment_reference', () => downPaymentReference);
    }
    final fullPaymentReference =
        (map['fullPaymentReference'] ?? map['full_payment_reference'] ?? '')
            .toString()
            .trim();
    if (fullPaymentReference.isNotEmpty) {
      pm.putIfAbsent('full_payment_reference', () => fullPaymentReference);
    }
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
    for (final c in _checklistItemsList(checklistRaw)) {
      final cc = _toMap(c);
      if (cc.isEmpty) continue;
      checklist.add(
        ChecklistItemDto(
          id: (cc['id'] ?? '').toString(),
          title: (cc['title'] ?? cc['item'] ?? '').toString(),
          description: (cc['description'] ?? '').toString(),
          price: _toDouble(cc['price'] ?? cc['cost']),
          quantity: () {
            final q = cc['quantity'] ?? cc['qty'];
            if (q is num) return q.toInt().clamp(1, 999999);
            return (int.tryParse('$q') ?? 1).clamp(1, 999999);
          }(),
          isCompleted: _checklistItemIsCompleted(cc),
          assignedTo: (cc['assignedTo'] ?? cc['assigned_to'] ?? '').toString(),
        ),
      );
    }

    final actualEventImages = <String>[];
    for (final img in _toList(
      map['actualEventImages'] ?? map['actual_event_images'],
    )) {
      final value = img.toString().trim();
      if (value.isNotEmpty) actualEventImages.add(value);
    }

    final eventTitleStr =
        (map['eventTitle'] ?? map['event_title'] ?? '').toString().trim();
    final rawOrderType =
        (map['orderType'] ?? map['order_type'])?.toString().trim() ?? '';
    final orderType =
        rawOrderType.isNotEmpty
            ? rawOrderType
            : (eventTitleStr.isNotEmpty ? 'catering_event' : 'catering');

    final orderKindRaw =
        (map['orderKind'] ?? map['order_kind'] ?? map['order_type'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
    final orderKind =
        orderKindRaw == 'catering' || orderKindRaw == 'catering_only'
            ? 'catering'
            : 'event';

    final eventIdStr =
        (map['eventId'] ?? map['event_id'] ?? '').toString().trim();
    final cateringIdStr =
        (map['cateringId'] ??
                map['catering_id'] ??
                map['inquiryId'] ??
                map['inquiry_id'] ??
                '')
            .toString()
            .trim();

    return EventOrderDto(
      id: (map['id'] ?? '').toString(),
      eventId: eventIdStr,
      cateringId: cateringIdStr,
      customerId: (map['customerId'] ?? map['customer_id'] ?? '').toString(),
      source: (map['source'] ?? '').toString(),
      status: (map['status'] ?? '').toString(),
      themeAssetsDeferred: _toBool(map['listSummaryOnly']),
      eventTitle: eventTitleStr,
      orderType: orderType,
      eventType: map['eventType'] as String? ?? '',
      formalityLevel: map['formalityLevel'] as String? ?? '',
      includeMinimalEventStyling: _toBool(
        map['includeMinimalEventStyling'] ??
            map['include_minimal_event_styling'],
      ),
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
      addressLat: _toNullableDouble(
        map['addressLat'] ?? map['address_lat'],
      ),
      addressLng: _toNullableDouble(
        map['addressLng'] ?? map['address_lng'],
      ),
      guestCount: _toInt(map['guestCount'] ?? map['guest_count']),
      allergens: (map['allergens'] ?? '').toString(),
      menu: menu,
      themeDesign: themeDesign,
      seatingPlan: seatingPlan,
      postAnalysis: postAnalysis,
      postAnalysisRaw: pm,
      orderKind: orderKind,
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
      updatedAt: _parseDateTime(
        map['updatedAt'] ?? map['updated_at'] ?? map['created_at'],
      ),
    );
  }

  DateTime? _parseDateTime(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    return DateTime.tryParse(raw.toString());
  }
}
