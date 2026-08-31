import 'dart:async';
import 'dart:html' as html;
import 'dart:js_util' as js_util;

void signalCurateringUiReadyImpl() {
  html.window.dispatchEvent(html.CustomEvent('curatering-ui-ready'));
}

void scheduleWhenIdleImpl(
  void Function() callback,
  Duration fallbackDelay,
) {
  if (js_util.hasProperty(html.window, 'requestIdleCallback')) {
    js_util.callMethod(html.window, 'requestIdleCallback', [
      js_util.allowInterop((_) => callback()),
      js_util.jsify({'timeout': fallbackDelay.inMilliseconds}),
    ]);
    return;
  }
  Timer(fallbackDelay, callback);
}
