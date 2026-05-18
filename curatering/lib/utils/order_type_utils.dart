/// Display labels and checks for catering vs catering + event orders.
String serviceTypeDisplayLabel(String orderType, {String eventTitle = ''}) {
  return orderTypeDisplayLabel(orderType, eventTitle: eventTitle);
}

/// Staff/customer order history: event category (Wedding, etc.) or N/A.
String historyEventTypeColumnValue({
  required String serviceKind,
  required String orderType,
  required String eventType,
}) {
  if (serviceKind == 'restaurant') return 'N/A';
  if (orderType.trim().toLowerCase() == 'catering') return 'N/A';
  final et = eventType.trim();
  return et.isEmpty ? '—' : et;
}

/// Display labels and checks for catering vs catering + event orders.
String orderTypeDisplayLabel(String orderType, {String eventTitle = ''}) {
  final t = orderType.trim().toLowerCase();
  if (t == 'catering') return 'Catering only';
  if (t == 'catering_event' || t == 'event') return 'Catering + Event';
  if (t == 'restaurant') return 'Restaurant order';
  if (eventTitle.trim().isNotEmpty) return 'Catering + Event';
  return 'Catering only';
}

bool isCateringPlusEventOrderType(String orderType, {String eventTitle = ''}) {
  final t = orderType.trim().toLowerCase();
  if (t == 'catering_event' || t == 'event') return true;
  if (t == 'catering') return false;
  return eventTitle.trim().isNotEmpty;
}
