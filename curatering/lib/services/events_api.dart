import 'dart:convert';

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

    final raw = decoded['orders'] ?? decoded['data'];
    if (raw is! List) {
      return const <EventOrderDto>[];
    }

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
  }) async {
    await ApiClient.instance.putJson(
      '/api/events/orders/$orderId/payment-status',
      body: {
        'paymentType': paymentType,
        'status': status,
      },
    );
  }

  // Event photos updates
  Future<void> updateEventPhotos({
    required String orderId,
    required List<String> photos,
  }) async {
    await ApiClient.instance.putJson(
      '/api/events/orders/$orderId/event-photos',
      body: {
        'photos': photos,
      },
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

  Future<Map<String, dynamic>> detectThemeObjects({
    required String imageBase64,
  }) async {
    return ApiClient.instance.postJson(
      '/api/events/theme-design/detect-objects',
      body: {'imageBase64': imageBase64},
    );
  }

  Future<Map<String, dynamic>> segmentThemeObjects({
    required String imageBase64,
    required List<Map<String, dynamic>> detections,
    required List<String> selectedClassIds,
  }) async {
    return ApiClient.instance.postJson(
      '/api/events/theme-design/segment-objects',
      body: {
        'imageBase64': imageBase64,
        'detections': detections,
        'selectedClassIds': selectedClassIds,
      },
    );
  }

  EventOrderDto _orderFromJson(dynamic raw) {
    final map = Map<String, dynamic>.from(raw as Map);
    final scheduleRaw = map['scheduleSlots'] ?? map['schedule_slots'];
    final scheduleSlots = <EventScheduleSlotDto>[];
    if (scheduleRaw is List) {
      for (final s in scheduleRaw) {
        final sm = Map<String, dynamic>.from(s as Map);
        scheduleSlots.add(
          EventScheduleSlotDto(
            date: (sm['date'] ?? '').toString(),
            startTime: (sm['startTime'] ?? sm['start_time'] ?? '').toString(),
            endTime: (sm['endTime'] ?? sm['end_time'] ?? '').toString(),
          ),
        );
      }
    } else if (scheduleRaw is String && scheduleRaw.isNotEmpty) {
      try {
        final parsed = jsonDecode(scheduleRaw);
        if (parsed is List) {
          for (final s in parsed) {
            final sm = Map<String, dynamic>.from(s as Map);
            scheduleSlots.add(
              EventScheduleSlotDto(
                date: (sm['date'] ?? '').toString(),
                startTime: (sm['startTime'] ?? sm['start_time'] ?? '').toString(),
                endTime: (sm['endTime'] ?? sm['end_time'] ?? '').toString(),
              ),
            );
          }
        }
      } catch (_) {}
    }

    final menuRaw = map['menu'];
    final menu = <EventMenuItemDto>[];
    if (menuRaw is List) {
      for (final m in menuRaw) {
        final mm = Map<String, dynamic>.from(m as Map);
        menu.add(
          EventMenuItemDto(
            dishName: (mm['dishName'] ?? mm['dish_name'] ?? '').toString(),
            paxOption: (mm['paxOption'] ?? mm['pax_option'] ?? '').toString(),
            price: mm['price']?.toString() ?? '0',
          ),
        );
      }
    } else if (menuRaw is String && menuRaw.isNotEmpty) {
      try {
        final parsed = jsonDecode(menuRaw);
        if (parsed is List) {
          for (final m in parsed) {
            final mm = Map<String, dynamic>.from(m as Map);
            menu.add(
              EventMenuItemDto(
                dishName: (mm['dishName'] ?? mm['dish_name'] ?? '').toString(),
                paxOption: (mm['paxOption'] ?? mm['pax_option'] ?? '').toString(),
                price: mm['price']?.toString() ?? '0',
              ),
            );
          }
        }
      } catch (_) {}
    }

    Map<String, dynamic> themeRaw = <String, dynamic>{};
    final rawTheme = map['themeDesign'] ?? map['theme_design'];
    if (rawTheme is Map) {
      themeRaw = Map<String, dynamic>.from(rawTheme);
    } else if (rawTheme is String && rawTheme.isNotEmpty) {
      try {
        final parsed = jsonDecode(rawTheme);
        if (parsed is Map) {
          themeRaw = Map<String, dynamic>.from(parsed);
        }
      } catch (_) {}
    }
    final themeDesign = EventThemeDesignDto(
      picksBase64: (themeRaw['picksBase64'] as List<dynamic>? ?? const <dynamic>[])
          .map((e) => e.toString())
          .toList(),
      tintEnabled: themeRaw['tintEnabled'] as bool? ?? false,
      tintColorHex: themeRaw['tintColorHex'] as String?,
      colorPrompt: themeRaw['colorPrompt'] as String?,
    );

    PostAnalysisDto? postAnalysis;
    final paRaw = map['postAnalysis'] ?? map['post_analysis'];
    if (paRaw != null && paRaw is Map) {
      final pm = Map<String, dynamic>.from(paRaw);
      postAnalysis = PostAnalysisDto(
        businessCardsGivenAway: (pm['businessCardsGivenAway'] as num?)?.toInt() ?? 0,
        onTheSpotInquiries: (pm['onTheSpotInquiries'] as num?)?.toInt() ?? 0,
        complaints: (pm['complaints'] as num?)?.toInt() ?? 0,
      );
    }

    final checklistRaw = map['checklist'];
    final checklist = <ChecklistItemDto>[];
    if (checklistRaw is List) {
      for (final c in checklistRaw) {
        final cc = c as Map<String, dynamic>;
        checklist.add(
          ChecklistItemDto(
            id: cc['id'] as String? ?? '',
            title: cc['title'] as String? ?? '',
            description: cc['description'] as String? ?? '',
            price: (cc['price'] as num?)?.toDouble() ?? 0.0,
            isCompleted: cc['isCompleted'] as bool? ?? false,
            assignedTo: cc['assignedTo'] as String? ?? '',
          ),
        );
      }
    }

    final actualEventImages = <String>[];
    if (map['actualEventImages'] is List) {
      actualEventImages.addAll((map['actualEventImages'] as List).map((e) => e as String));
    }

    return EventOrderDto(
      id: (map['id'] ?? '').toString(),
      source: (map['source'] ?? '').toString(),
      status: (map['status'] ?? '').toString(),
      eventTitle: map['eventTitle'] as String? ?? '',
      orderType: map['orderType'] as String? ?? 'catering',
      eventType: map['eventType'] as String? ?? '',
      formalityLevel: map['formalityLevel'] as String? ?? '',
      customerName: (map['customerName'] ?? map['customer_name'] ?? '').toString(),
      contactPerson: (map['contactPerson'] ?? map['contact_person'] ?? '').toString(),
      contactNumber: (map['contactNumber'] ?? map['contact_number'] ?? '').toString(),
      emailAddress: (map['emailAddress'] ?? map['email_address'] ?? '').toString(),
      scheduleSlots: scheduleSlots,
      address: (map['address'] ?? '').toString(),
      guestCount: ((map['guestCount'] ?? map['guest_count']) as num?)?.toInt() ?? 0,
      menu: menu,
      themeDesign: themeDesign,
      postAnalysis: postAnalysis,
      downPaymentAmount: (map['downPaymentAmount'] as num?)?.toDouble() ?? 0.0,
      downPaymentStatus: map['downPaymentStatus'] as String? ?? 'pending',
      fullPaymentAmount: (map['fullPaymentAmount'] as num?)?.toDouble() ?? 0.0,
      fullPaymentStatus: map['fullPaymentStatus'] as String? ?? 'pending',
      totalCost: (map['totalCost'] as num?)?.toDouble() ?? 0.0,
      checklist: checklist,
      actualEventImages: actualEventImages,
      finalStatus: map['finalStatus'] as String? ?? 'successful',
    );
  }
}

