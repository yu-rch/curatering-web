import 'package:flutter/material.dart';

import '../config/site_routes.dart';
import '../customer_page_loader.dart';
import '../utils/browser_tab_title.dart';

/// Host-aware `/` entry.
class AppRootRoute extends StatefulWidget {
  const AppRootRoute({super.key});

  @override
  State<AppRootRoute> createState() => _AppRootRouteState();
}

class _AppRootRouteState extends State<AppRootRoute> {
  @override
  void initState() {
    super.initState();
    if (isStaffSiteHost) {
      setBrowserTabTitle('Login', staff: true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/login');
      });
      return;
    }
    setBrowserTabTitle('Home', staff: false);
    // Extras warm-up removed: deferred checkout/maps JS must not load on `/`.
  }

  @override
  Widget build(BuildContext context) {
    if (isStaffSiteHost) {
      return const SizedBox.shrink();
    }
    return buildCustomerWebsiteScreen(
      contentEditable: false,
      showStaffChrome: false,
    );
  }
}
