import 'package:flutter/material.dart';

import '../config/site_redirect_stub.dart'
    if (dart.library.js_interop) '../config/site_redirect_web.dart'
    if (dart.library.html) '../config/site_redirect_web.dart';
import '../config/site_routes.dart';
import '../utils/browser_tab_title.dart';

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
  bool _redirectAttempted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_redirectAttempted) return;
      _redirectAttempted = true;
      final target = Uri.parse(widget.origin).replace(
        path: normalizeRoutePath(widget.path),
      );
      if (browserLocationMatches(target)) return;
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
class HostRouteGuard extends StatefulWidget {
  const HostRouteGuard({
    super.key,
    required this.child,
    required this.routePath,
  });

  final Widget child;
  final String routePath;

  @override
  State<HostRouteGuard> createState() => _HostRouteGuardState();
}

class _HostRouteGuardState extends State<HostRouteGuard> {
  @override
  void initState() {
    super.initState();
    _applyTabTitle();
  }

  @override
  void didUpdateWidget(covariant HostRouteGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.routePath != widget.routePath) {
      _applyTabTitle();
    }
  }

  void _applyTabTitle() {
    final path = normalizeTabPath(widget.routePath);
    final staff = isStaffSiteHost || isStaffRoute(path);
    final label =
        staff ? staffTabTitleForRoute(path) : customerTabTitleForRoute(path);
    // Fire-and-forget; tab title is best-effort on web.
    setBrowserTabTitle(label, staff: staff);
  }

  @override
  Widget build(BuildContext context) {
    if (needsRedirectToStaffSite(widget.routePath)) {
      return ExternalHostRedirect(
        origin: staffSiteOrigin,
        path: widget.routePath,
      );
    }
    if (needsRedirectToCustomerSite(widget.routePath)) {
      return ExternalHostRedirect(
        origin: customerSiteOrigin,
        path: customerRoute(widget.routePath),
      );
    }
    return widget.child;
  }
}
