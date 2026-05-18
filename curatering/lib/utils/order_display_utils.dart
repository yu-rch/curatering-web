import '../models/event_order.dart';

/// Display label for restaurant orders (prefers `order_no` e.g. ORD-0001).
String uiOrderNo(dynamic orderNo, {dynamic id}) {
  if (orderNo != null) {
    final s = orderNo.toString().trim();
    if (s.isNotEmpty) return s;
  }
  if (id != null) {
    final s = id.toString().trim();
    if (s.length > 8) return s.substring(s.length - 8);
    if (s.isNotEmpty) return s;
  }
  return 'N/A';
}

String formatRestaurantOrderNo(Map<String, dynamic> order) {
  final orderNo = order['order_no']?.toString().trim();
  if (orderNo != null && orderNo.isNotEmpty) return orderNo;
  final id = order['id']?.toString().trim();
  if (id != null && id.isNotEmpty) return id;
  return 'N/A';
}

String formatFulfilmentDateTimeFromEvent(EventOrderDto order) {
  if (order.scheduleSlots.isNotEmpty) {
    final s = order.scheduleSlots.first;
    final date = s.date.trim();
    final time = s.startTime.trim();
    if (date.isNotEmpty && time.isNotEmpty) return '$date $time';
    if (date.isNotEmpty) return date;
    if (time.isNotEmpty) return time;
  }
  if (order.updatedAt != null) {
    return _formatIsoDateTime(order.updatedAt);
  }
  return '—';
}

String formatFulfilmentDateTimeFromRestaurant(Map<String, dynamic> order) {
  final delivery = order['delivery_time']?.toString();
  if (delivery != null && delivery.trim().isNotEmpty) {
    return _formatIsoDateTime(DateTime.tryParse(delivery));
  }
  final updated = order['updated_at']?.toString();
  if (updated != null && updated.trim().isNotEmpty) {
    return _formatIsoDateTime(DateTime.tryParse(updated));
  }
  final created = order['created_at']?.toString();
  if (created != null && created.trim().isNotEmpty) {
    return _formatIsoDateTime(DateTime.tryParse(created));
  }
  return '—';
}

String _formatIsoDateTime(DateTime? dt) {
  if (dt == null) return '—';
  final local = dt.toLocal();
  final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final ampm = local.hour >= 12 ? 'PM' : 'AM';
  final min = local.minute.toString().padLeft(2, '0');
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
      '$h:$min $ampm';
}

DateTime? fulfilmentDateOnlyFromEvent(EventOrderDto order) {
  if (order.scheduleSlots.isNotEmpty) {
    return DateTime.tryParse(order.scheduleSlots.first.date);
  }
  return order.updatedAt;
}

DateTime? fulfilmentDateOnlyFromRestaurant(Map<String, dynamic> order) {
  return DateTime.tryParse(order['delivery_time']?.toString() ?? '') ??
      DateTime.tryParse(order['updated_at']?.toString() ?? '') ??
      DateTime.tryParse(order['created_at']?.toString() ?? '');
}
