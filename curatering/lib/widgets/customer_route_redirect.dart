import 'package:flutter/material.dart';
import '../config/site_routes.dart';

/// Sends `/` and legacy flat customer paths to the prefixed customer URL.
class CustomerRouteRedirect extends StatelessWidget {
  const CustomerRouteRedirect({super.key, required this.target});

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
