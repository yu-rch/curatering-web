import 'package:flutter/material.dart';

import 'customer_home.dart' deferred as customer_home
    show CustomerWebsiteScreen, customerExtraPageFor;

/// Single shared loader for the customer site deferred chunk.
Future<void>? _loading;

Future<void> ensureCustomerPagesLoaded() {
  final pending = _loading ??= customer_home.loadLibrary().catchError((Object e) {
    _loading = null;
    throw e;
  });
  return pending;
}

Widget buildCustomerWebsiteScreen({
  bool contentEditable = false,
  bool showStaffChrome = false,
}) {
  return customer_home.CustomerWebsiteScreen(
    contentEditable: contentEditable,
    showStaffChrome: showStaffChrome,
  );
}

Widget buildCustomerExtraPage(String path) {
  return customer_home.customerExtraPageFor(path);
}
