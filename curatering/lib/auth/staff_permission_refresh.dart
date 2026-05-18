import 'dart:async';

import 'package:flutter/material.dart';

import 'auth_session.dart';
import '../services/auth_api.dart';
import 'roles.dart';

/// Refreshes staff [pagePermissions] from the server on navigation (not Super Admin).
class StaffPermissionRefreshObserver extends NavigatorObserver {
  StaffPermissionRefreshObserver._();
  static final StaffPermissionRefreshObserver instance =
      StaffPermissionRefreshObserver._();

  Timer? _debounce;

  void _scheduleRefresh() {
    if (!AuthSession.instance.hasToken) return;
    final role = AuthSession.instance.currentRole;
    if (role == null || role == Role.superAdmin) return;

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        await AuthSession.instance.refreshFromServer();
      } catch (_) {
        // Ignore — stale permissions until next navigation or sign-in.
      }
    });
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _scheduleRefresh();
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _scheduleRefresh();
    super.didPop(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _scheduleRefresh();
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}
