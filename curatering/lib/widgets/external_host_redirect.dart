import 'package:flutter/material.dart';

import '../config/site_routes.dart';

/// Sends the browser to another subdomain (e.g. staff → customer site).
class ExternalHostRedirect extends StatefulWidget {
  const ExternalHostRedirect({
    super.key,
    required this.origin,
    required this.path,
  });

  final String origin;
  final String path;

  @override
  State<ExternalHostRedirect> createState() => _ExternalHostRedirectState();
}

class _ExternalHostRedirectState extends State<ExternalHostRedirect> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      redirectToSiteOrigin(widget.origin, widget.path);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

/// Staff UI only on [kStaffWebHost]; customer UI only on [kCustomerWebHost].
class HostRouteGuard extends StatelessWidget {
  const HostRouteGuard({
    super.key,
    required this.child,
    required this.routePath,
  });

  final Widget child;
  final String routePath;

  @override
  Widget build(BuildContext context) {
    if (isCustomerSiteHost && isStaffRoute(routePath)) {
      return ExternalHostRedirect(
        origin: staffSiteOrigin,
        path: routePath,
      );
    }
    if (isStaffSiteHost && isCustomerContentRoute(routePath)) {
      return ExternalHostRedirect(
        origin: customerSiteOrigin,
        path: customerRoute(routePath),
      );
    }
    return child;
  }
}
