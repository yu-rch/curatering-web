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

    print('DEBUG: Calling API at path: $path with status: $status'); // Debug line

    final decoded = await ApiClient.instance.getJson(
      path,
      queryParameters: {'status': status},
    );

    print('DEBUG: Raw API response: $decoded'); // Debug line
    print('DEBUG: Response type: ${decoded.runtimeType}'); // Debug line

    final raw = decoded['orders'];
    print('DEBUG: Orders array: $raw'); // Debug line
    print('DEBUG: Orders array type: ${raw.runtimeType}'); // Debug line
    
    if (raw is! List) {
      print('DEBUG: Raw is not a List, returning empty');
      return const <EventOrderDto>[];
    }

    print('DEBUG: Mapping ${raw.length} orders to EventOrderDto'); // Debug line
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
      id: map['id'].toString(),
      source: map['source'] as String,
      status: map['status'] as String,
      eventTitle: map['eventTitle'] as String? ?? '',
      orderType: map['orderType'] as String? ?? 'catering',
      eventType: map['eventType'] as String? ?? '',
      formalityLevel: map['formalityLevel'] as String? ?? '',
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

