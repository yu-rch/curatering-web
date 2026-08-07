import 'package:flutter/material.dart';

import '../config/site_routes.dart';
import '../pages/customer_website.dart';
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
  }

  @override
  Widget build(BuildContext context) {
    if (isStaffSiteHost) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return const CustomerWebsiteScreen(
      contentEditable: false,
      showStaffChrome: false,
    );
  }
}
