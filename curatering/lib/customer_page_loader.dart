import 'package:flutter/material.dart';

import 'config/site_routes.dart';
import 'customer_home.dart';
import 'services/website_content_store.dart';

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

/// When staff are editing a CMS draft, keep secondary pages editable on the
/// staff host instead of redirecting to the live customer site.
bool get isCmsDraftPreviewOnStaff =>
    isStaffSiteHost && WebsiteContentStore.instance.isDraftMode;

Widget buildCustomerExtraPage(String path) {
  final route = stripLegacyCustomerPrefix(normalizeRoutePath(path));
  final editable = isCmsDraftPreviewOnStaff;
  return customerExtraPageFor(
    route,
    contentEditable: editable,
    showStaffChrome: editable,
  );
}
