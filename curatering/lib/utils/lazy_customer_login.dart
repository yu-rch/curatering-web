import 'package:flutter/material.dart';

import '../pages/customer_login.dart' deferred as customer_login;

/// Opens the customer login dialog after loading its deferred chunk.
Future<void> showLazyCustomerLoginDialog(
  BuildContext context, {
  bool redirectToCheckout = false,
}) async {
  await customer_login.loadLibrary();
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (context) => customer_login.CustomerLoginPage(
      redirectToCheckout: redirectToCheckout,
    ),
  );
}
