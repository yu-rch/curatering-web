import 'dart:html' as html;

String getWebHostname() =>
    (html.window.location.hostname ?? '').toLowerCase();

String getWebPathname() {
  var path = html.window.location.pathname ?? '/';
  if (path.isEmpty) return '/';
  if (path.length > 1 && path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  return path;
}
