import 'package:web/web.dart';

String _normalizePath(String p) {
  var path = p.trim();
  if (path.isEmpty) return '/';
  if (!path.startsWith('/')) path = '/$path';
  if (path.length > 1 && path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  return path;
}

/// Avoid reload loops when the browser is already on [target].
bool browserLocationMatches(Uri target) {
  final current = Uri.parse(window.location.href);
  return current.origin == target.origin &&
      _normalizePath(current.path) == _normalizePath(target.path);
}

/// Same-origin path change without a full document reload.
void replaceBrowserPath(Uri target) {
  final path = _normalizePath(target.path);
  final query = target.hasQuery ? '?${target.query}' : '';
  final fragment = target.hasFragment ? '#${target.fragment}' : '';
  window.history.replaceState(null, '', '$path$query$fragment');
}

/// Navigates to [uri]. Returns `true` when a full page load was started
/// (caller should not call [runApp]).
bool redirectBrowserTo(Uri uri) {
  if (browserLocationMatches(uri)) return false;

  final current = Uri.parse(window.location.href);
  if (current.origin == uri.origin) {
    replaceBrowserPath(uri);
    return false;
  }

  window.location.href = uri.toString();
  return true;
}
