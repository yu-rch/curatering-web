/// Display labels and checks for catering vs catering + event orders.
String orderTypeDisplayLabel(String orderType, {String eventTitle = ''}) {
  final t = orderType.trim().toLowerCase();
  if (t == 'catering') return 'Catering only';
  if (t == 'catering_event' || t == 'event') return 'Catering + Event';
  if (eventTitle.trim().isNotEmpty) return 'Catering + Event';
  return 'Catering only';
}

bool isCateringPlusEventOrderType(String orderType, {String eventTitle = ''}) {
  final t = orderType.trim().toLowerCase();
  if (t == 'catering_event' || t == 'event') return true;
  if (t == 'catering') return false;
  return eventTitle.trim().isNotEmpty;
}
