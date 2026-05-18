import 'dart:html' as html;

void redirectBrowserTo(Uri uri) {
  html.window.location.href = uri.toString();
}

/// Avoid reload loops when the browser is already on [target].
bool browserLocationMatches(Uri target) {
  final current = Uri.parse(html.window.location.href);
  final normalize = (String p) {
    var path = p.trim();
    if (path.isEmpty) return '/';
    if (!path.startsWith('/')) path = '/$path';
    if (path.length > 1 && path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    return path;
  };
  return current.origin == target.origin &&
      normalize(current.path) == normalize(target.path);
}
