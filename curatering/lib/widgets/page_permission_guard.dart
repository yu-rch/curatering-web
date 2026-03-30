import 'package:flutter/material.dart';

import '../auth/auth_session.dart';
import '../auth/page_permissions.dart';
import '../auth/roles.dart';

/// Hides [child] and redirects if the current user’s [pagePermissions] deny [route].
/// Super Admin always passes.
class PagePermissionGuard extends StatelessWidget {
  final String route;
  final Widget child;
  final String redirectRoute;

  const PagePermissionGuard({
    super.key,
    required this.route,
    required this.child,
    this.redirectRoute = '/dashboard',
  });

  @override
  Widget build(BuildContext context) {
    final user = AuthSession.instance.currentUser.value;
    final role = user?.role;

    if (role == Role.superAdmin) return child;

    final perms = user?.pagePermissions;
    if (pageRouteAllowed(route, perms)) return child;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).pushReplacementNamed(redirectRoute);
    });
    return const SizedBox.shrink();
  }
}
