import 'package:flutter/material.dart';

import 'config/site_routes.dart';
import 'customer_extra_pages.dart' deferred as customer_pages;
import 'pages/customer_website.dart';
import 'services/website_content_store.dart';

/// Ensures secondary customer routes (/gallery, /checkout, …) are loaded.
/// Homepage does not need this — extras live in a deferred JS chunk.
Future<void>? _customerExtrasLoading;

Future<void> ensureCustomerPagesLoaded() {
  return _customerExtrasLoading ??= customer_pages.loadLibrary();
}

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
  return customer_pages.customerExtraPageFor(
    route,
    contentEditable: editable,
    showStaffChrome: editable,
  );
}
