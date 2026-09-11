import 'package:flutter/material.dart';

/// Drops a second dialog/sheet when the same button is mashed before the
/// first modal barrier is up. Nested modals opened after a short delay
/// (from inside an already-open dialog) still work.
class PreventStackedDialogsObserver extends NavigatorObserver {
  PreventStackedDialogsObserver._();

  static final PreventStackedDialogsObserver instance =
      PreventStackedDialogsObserver._();

  static const _burst = Duration(milliseconds: 600);

  DateTime? _lastModalAt;
  bool _removing = false;

  bool _isModal(Route<dynamic> route) =>
      route is RawDialogRoute || route is ModalBottomSheetRoute;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_removing) return;
    if (!_isModal(route)) return;

    final now = DateTime.now();
    final stackedOnModal =
        previousRoute != null && _isModal(previousRoute);
    final rapid =
        _lastModalAt != null && now.difference(_lastModalAt!) < _burst;
    _lastModalAt = now;

    if (!stackedOnModal || !rapid) return;

    _removing = true;
    final nav = navigator;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        if (nav != null && route.isActive) {
          nav.removeRoute(route);
        }
      } finally {
        _removing = false;
      }
    });
  }
}
