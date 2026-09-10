import 'package:flutter/material.dart';

import 'config/site_routes.dart';
import 'customer_extra_pages.dart' deferred as customer_pages;
import 'pages/customer_website.dart' deferred as customer_home;
import 'services/cms_draft_flag.dart';
import 'utils/web_boot_bridge.dart';

/// Ensures secondary customer routes (/gallery, /checkout, …) are loaded.
/// Homepage does not need this — extras live in a deferred JS chunk.
Future<void>? _customerExtrasLoading;
Future<void>? _customerHomeLoading;

Future<void> ensureCustomerPagesLoaded() {
  return _customerExtrasLoading ??= customer_pages.loadLibrary();
}

/// Loads the deferred homepage library (kept out of the initial main.dart.js).
Future<void> ensureCustomerHomeLoaded() {
  return _customerHomeLoading ??= customer_home.loadLibrary();
}

Widget buildCustomerWebsiteScreen({
  bool contentEditable = false,
  bool showStaffChrome = false,
  bool staffThemeStudioMode = false,
  String? returnRoute,
}) {
  return _DeferredCustomerHome(
    contentEditable: contentEditable,
    showStaffChrome: showStaffChrome,
    staffThemeStudioMode: staffThemeStudioMode,
    returnRoute: returnRoute,
  );
}

class _DeferredCustomerHome extends StatefulWidget {
  const _DeferredCustomerHome({
    required this.contentEditable,
    required this.showStaffChrome,
    required this.staffThemeStudioMode,
    this.returnRoute,
  });

  final bool contentEditable;
  final bool showStaffChrome;
  final bool staffThemeStudioMode;
  final String? returnRoute;

  @override
  State<_DeferredCustomerHome> createState() => _DeferredCustomerHomeState();
}

class _DeferredCustomerHomeState extends State<_DeferredCustomerHome> {
  bool _ready = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    ensureCustomerHomeLoaded()
        .then((_) {
          if (!mounted) return;
          setState(() => _ready = true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            signalCurateringUiReady();
          });
        })
        .catchError((Object e) {
          if (mounted) setState(() => _error = e);
        });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null || !_ready) {
      // HTML shell covers the viewport while the deferred home chunk loads.
      return const ColoredBox(
        color: Color(0xFF000000),
        child: SizedBox.expand(),
      );
    }
    return customer_home.CustomerWebsiteScreen(
      contentEditable: widget.contentEditable,
      showStaffChrome: widget.showStaffChrome,
      staffThemeStudioMode: widget.staffThemeStudioMode,
      returnRoute: widget.returnRoute,
    );
  }
}

/// When staff are editing a CMS draft, keep secondary pages editable on the
/// staff host instead of redirecting to the live customer site.
bool get isCmsDraftPreviewOnStaff =>
    isStaffSiteHost && cmsDraftModeActive;

Widget buildCustomerExtraPage(String path) {
  final route = stripLegacyCustomerPrefix(normalizeRoutePath(path));
  final editable = isCmsDraftPreviewOnStaff;
  return customer_pages.customerExtraPageFor(
    route,
    contentEditable: editable,
    showStaffChrome: editable,
  );
}
