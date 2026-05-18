import 'package:flutter/material.dart';

import '../config/site_routes.dart';

/// Rewrites old `/macrinas-kitchen-and-catering/...` bookmarks to root paths.
class LegacyPathRedirect extends StatelessWidget {
  const LegacyPathRedirect({super.key, required this.target});

  final String target;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final route = customerRoute(target);
      if (!context.mounted) return;
      Navigator.of(context).pushReplacementNamed(route);
    });
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
