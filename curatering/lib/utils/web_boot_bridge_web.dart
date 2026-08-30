import 'dart:html' as html;

void signalCurateringUiReadyImpl() {
  html.window.dispatchEvent(html.CustomEvent('curatering-ui-ready'));
}
