import 'package:flutter/material.dart';

import 'config/site_routes.dart';
import 'customer_home.dart';

/// Customer pages are bundled in the main web app for reliable direct routes
/// (/gallery, /restaurant, etc.). Inner widgets still lazy-load heavy tabs.
Future<void> ensureCustomerPagesLoaded() async {}

Widget buildCustomerWebsiteScreen({
  bool contentEditable = false,
  bool showStaffChrome = false,
}) {
  return CustomerWebsiteScreen(
    contentEditable: contentEditable,
    showStaffChrome: showStaffChrome,
  );
}

Widget buildCustomerExtraPage(String path) {
  final route = stripLegacyCustomerPrefix(normalizeRoutePath(path));
  return customerExtraPageFor(route);
}
