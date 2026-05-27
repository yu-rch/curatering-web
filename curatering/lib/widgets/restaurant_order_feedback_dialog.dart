import 'package:flutter/material.dart';
import 'customer_order_feedback_dialog.dart';

/// Rating dialog for delivered restaurant orders (mobile parity).
Future<bool> showRestaurantOrderFeedbackDialog(
  BuildContext context, {
  required String orderId,
  required String orderLabel,
  required Future<String?> Function() getToken,
}) {
  return showCustomerOrderFeedbackDialog(
    context,
    kind: 'restaurant_order',
    reference: orderId,
    label: orderLabel,
    getToken: getToken,
  );
}
