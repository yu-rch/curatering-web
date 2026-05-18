import 'package:flutter/material.dart';

import 'auth_session.dart';
import 'roles.dart';

class RoleGuard extends StatelessWidget {
  final Role requiredRole;
  final Set<Role>? allowedRoles;
  final Widget child;
  final String redirectRoute;

  const RoleGuard({
    super.key,
    required this.requiredRole,
    this.allowedRoles,
    required this.child,
    this.redirectRoute = '/dashboard',
  });

  @override
  Widget build(BuildContext context) {
    final session = AuthSession.instance;
    final user = session.currentUser.value;
    final role = user?.role;

    if (!session.hasToken || user == null || role == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final current = ModalRoute.of(context)?.settings.name;
        if (current == '/login' || current == '/') return;
        Navigator.of(context).pushReplacementNamed('/login');
      });
      return const SizedBox.shrink();
    }

    final allowed = allowedRoles ?? {requiredRole};

    // Super Admin can access anything.
    if (role != Role.superAdmin && !allowed.contains(role)) {
      // Only requiredRole (or super admin) is allowed.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed(redirectRoute);
      });
      return const SizedBox.shrink();
    }

    // Super Admin can access anything; otherwise check exact requiredRole.
    if (role == Role.superAdmin) return child;
    return allowed.contains(role) ? child : const SizedBox.shrink();
  }
}

