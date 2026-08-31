import 'package:web/web.dart';

void openAppRouteInNewTab(String origin, String path) {
  var p = path.trim();
  if (p.isEmpty) p = '/';
  if (!p.startsWith('/')) p = '/$p';
  window.open('$origin$p', '_blank');
}
