import 'package:flutter/foundation.dart';

import 'web_boot_bridge_stub.dart'
    if (dart.library.html) 'web_boot_bridge_web.dart' as impl;

/// Signals HTML boot.js that Flutter UI is ready (end black post-splash hold).
void signalCurateringUiReady() {
  if (!kIsWeb) return;
  impl.signalCurateringUiReadyImpl();
}
