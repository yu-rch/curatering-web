import 'dart:html' as html;

void redirectBrowserTo(Uri uri) {
  html.window.location.href = uri.toString();
}
