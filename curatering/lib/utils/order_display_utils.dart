/// Display label for restaurant orders (prefers `order_no` e.g. ORD-0001).
String formatRestaurantOrderNo(Map<String, dynamic> order) {
  final orderNo = order['order_no']?.toString().trim();
  if (orderNo != null && orderNo.isNotEmpty) return orderNo;
  final id = order['id']?.toString().trim();
  if (id != null && id.isNotEmpty) return id;
  return 'N/A';
}
