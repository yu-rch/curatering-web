import 'package:flutter/material.dart';

import '../config/site_routes.dart';
import '../pages/customer_website.dart';
import '../pages/login.dart';

/// Host-aware `/` entry.
class AppRootRoute extends StatelessWidget {
  const AppRootRoute({super.key});

  @override
  Widget build(BuildContext context) {
    if (isStaffSiteHost) {
      return const Login();
    }
    return const CustomerWebsiteScreen(
      contentEditable: false,
      showStaffChrome: false,
    );
  }
}
