import 'package:flutter/foundation.dart';

import 'web_boot_bridge_stub.dart'
    if (dart.library.html) 'web_boot_bridge_web.dart' as impl;

/// Signals HTML boot.js that Flutter UI is ready (end black post-splash hold).
void signalCurateringUiReady() {
  if (!kIsWeb) return;
  impl.signalCurateringUiReadyImpl();
}

/// Runs [callback] when the browser is idle (or after [fallbackDelay]).
void scheduleWhenIdle(
  void Function() callback, {
  Duration fallbackDelay = const Duration(milliseconds: 1200),
}) {
  if (!kIsWeb) {
    Future<void>.delayed(fallbackDelay, callback);
    return;
  }
  impl.scheduleWhenIdleImpl(callback, fallbackDelay);
}
