import 'dart:html' as html;

void openAppRouteInNewTab(String origin, String path) {
  var p = path.trim();
  if (p.isEmpty) p = '/';
  if (!p.startsWith('/')) p = '/$p';
  html.window.open('$origin$p', '_blank');
}
