import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart';

void signalCurateringUiReadyImpl() {
  window.dispatchEvent(CustomEvent('curatering-ui-ready'));
}

@JS('typeof window.requestIdleCallback === "function"')
external bool get _hasRequestIdleCallback;

@JS('window.requestIdleCallback')
external void _requestIdleCallback(JSFunction callback, JSAny options);

void scheduleWhenIdleImpl(
  void Function() callback,
  Duration fallbackDelay,
) {
  if (_hasRequestIdleCallback) {
    _requestIdleCallback(
      callback.toJS,
      {'timeout': fallbackDelay.inMilliseconds}.jsify()!,
    );
    return;
  }
  Timer(fallbackDelay, callback);
}
