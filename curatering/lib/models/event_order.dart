import 'seating_plan.dart';

class EventScheduleSlotDto {
  final String date; // yyyy-mm-dd
  final String startTime; // HH:mm
  final String endTime; // HH:mm

  const EventScheduleSlotDto({
    required this.date,
    required this.startTime,
    required this.endTime,
  });
}

class EventMenuItemDto {
  final String dishName;
  final String paxOption;
  final String price;
  final String setMenuName;
  final String dishAllergens;

  const EventMenuItemDto({
    required this.dishName,
    required this.paxOption,
    required this.price,
    this.setMenuName = '',
    this.dishAllergens = '',
  });
}

class EventThemeDesignDto {
  final List<String> picksBase64;
  final bool tintEnabled;
  final String? tintColorHex; // #RRGGBB
  final String? colorPrompt;
  final bool wantsCustomDesign;
  final String? customerThemeRequest;
  final String? generatedImageUrl;
  final String? customInstructions;
  final String? eventDesignSource;
  final String? macrinaColorPalette;
  final String? macrinaTheme;
  final double? dishCost;
  final double? laborCost;
  final double? travelCost;

  const EventThemeDesignDto({
    required this.picksBase64,
    required this.tintEnabled,
    this.tintColorHex,
    this.colorPrompt,
    this.wantsCustomDesign = false,
    this.customerThemeRequest,
    this.generatedImageUrl,
    this.customInstructions,
    this.eventDesignSource,
    this.macrinaColorPalette,
    this.macrinaTheme,
    this.dishCost,
    this.laborCost,
    this.travelCost,
  });
}

class PostAnalysisDto {
  final int businessCardsGivenAway;
  final int onTheSpotInquiries;
  final int complaints;

  const PostAnalysisDto({
    required this.businessCardsGivenAway,
    required this.onTheSpotInquiries,
    required this.complaints,
  });
}

class EventOrderDto {
  final String id;
  final String cateringId;
  final String eventId;
  final String customerId;
  final String source;
  final String status;

  final String eventTitle;
  final String orderType; // catering | catering_event
  final String eventType;
  final String formalityLevel;
  final bool includeMinimalEventStyling;

  final String customerName;
  final String contactPerson;
  final String contactNumber;
  final String emailAddress;

  final List<EventScheduleSlotDto> scheduleSlots;
  final String address;
  final int guestCount;
  final String allergens;

  final List<EventMenuItemDto> menu;
  final EventThemeDesignDto themeDesign;
  final SeatingPlanData seatingPlan;
  final PostAnalysisDto? postAnalysis;

  /// Full `post_analysis` JSON from the server (task rows, additional costs, proofs, etc.).
  final Map<String, dynamic> postAnalysisRaw;

  /// `catering` | `event` — which table this order lives in.
  final String orderKind;

  // Payment information
  final double downPaymentAmount;
  final String downPaymentStatus; // pending | paid | cancelled
  final double fullPaymentAmount;
  final String fullPaymentStatus; // pending | paid | cancelled
  final double totalCost;

  // Checklist and images
  final List<ChecklistItemDto> checklist;
  final List<String> actualEventImages; // Base64 encoded images

  // Final status
  final String finalStatus; // successful | cancelled

  /// True when [listSummaryOnly] was returned: theme image payloads omitted; use [EventsApi.getEventOrder] for full data.
  final bool themeAssetsDeferred;

  final DateTime? updatedAt;

  /// Public transaction number: `event_id` for events, `catering_id` for catering.
  String get transactionNo {
    final isEvent =
        orderKind == 'event' ||
        orderType == 'catering_event' ||
        orderType.contains('event');
    if (isEvent && eventId.isNotEmpty) return eventId;
    if (cateringId.isNotEmpty) return cateringId;
    return id;
  }

  const EventOrderDto({
    required this.id,
    this.cateringId = '',
    this.eventId = '',
    this.customerId = '',
    required this.source,
    required this.status,
    required this.eventTitle,
    required this.orderType,
    required this.eventType,
    required this.formalityLevel,
    this.includeMinimalEventStyling = false,
    required this.customerName,
    required this.contactPerson,
    required this.contactNumber,
    required this.emailAddress,
    required this.scheduleSlots,
    required this.address,
    required this.guestCount,
    this.allergens = '',
    required this.menu,
    required this.themeDesign,
    this.seatingPlan = const SeatingPlanData(),
    this.postAnalysis,
    this.postAnalysisRaw = const {},
    this.orderKind = 'event',
    this.downPaymentAmount = 0.0,
    this.downPaymentStatus = 'pending',
    this.fullPaymentAmount = 0.0,
    this.fullPaymentStatus = 'pending',
    this.totalCost = 0.0,
    this.checklist = const [],
    this.actualEventImages = const [],
    this.finalStatus = 'successful',
    this.themeAssetsDeferred = false,
    this.updatedAt,
  });
}

class ChecklistItemDto {
  final String id;
  final String title;
  final String description;
  final double price;
  final bool isCompleted;
  final String assignedTo;

  const ChecklistItemDto({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    this.isCompleted = false,
    this.assignedTo = '',
  });
}

