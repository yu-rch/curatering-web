import 'package:flutter/material.dart';

import '../config/site_redirect_stub.dart'
    if (dart.library.html) '../config/site_redirect_web.dart';
import '../config/site_routes.dart';

/// Rewrites old `/macrinas-kitchen-and-catering/...` bookmarks to root paths.
class LegacyPathRedirect extends StatelessWidget {
  const LegacyPathRedirect({super.key, required this.target});

  final String target;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isStaffSiteHost) {
        final target = Uri.parse(staffSiteOrigin).replace(path: '/login');
        if (!browserLocationMatches(target)) {
          redirectToSiteOrigin(staffSiteOrigin, '/login');
        }
        return;
      }
      final route = customerRoute(target);
      if (!context.mounted) return;
      Navigator.of(context).pushReplacementNamed(route);
    });
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
