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

  const EventMenuItemDto({
    required this.dishName,
    required this.paxOption,
    required this.price,
  });
}

class EventThemeDesignDto {
  final List<String> picksBase64;
  final bool tintEnabled;
  final String? tintColorHex; // #RRGGBB
  final String? colorPrompt;

  const EventThemeDesignDto({
    required this.picksBase64,
    required this.tintEnabled,
    this.tintColorHex,
    this.colorPrompt,
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
  final String source; // new_event | online_inquiry
  final String status; // new_event | online_inquiries | for_processing | for_post_analysis | completed

  final String eventTitle;
  final String eventType;
  final String formalityLevel;

  final String customerName;
  final String contactPerson;
  final String contactNumber;
  final String emailAddress;

  final List<EventScheduleSlotDto> scheduleSlots;
  final String address;
  final int guestCount;

  final List<EventMenuItemDto> menu;
  final EventThemeDesignDto themeDesign;
  final PostAnalysisDto? postAnalysis;

  const EventOrderDto({
    required this.id,
    required this.source,
    required this.status,
    required this.eventTitle,
    required this.eventType,
    required this.formalityLevel,
    required this.customerName,
    required this.contactPerson,
    required this.contactNumber,
    required this.emailAddress,
    required this.scheduleSlots,
    required this.address,
    required this.guestCount,
    required this.menu,
    required this.themeDesign,
    this.postAnalysis,
  });
}

