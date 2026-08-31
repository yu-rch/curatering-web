import 'package:web/web.dart';

String getWebHostname() => window.location.hostname.toLowerCase();

String getWebPathname() {
  var path = window.location.pathname;
  if (path.isEmpty) return '/';
  if (path.length > 1 && path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  return path;
}
