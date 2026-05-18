/// Customer-facing site lives under this path prefix (staff app uses root paths).
const String kCustomerSitePrefix = '/macrinas-kitchen-and-catering';

/// Web cold-start route from the browser URL (PathUrlStrategy).
/// Without this, a hardcoded [initialRoute] ignores `/login` and similar deep links.
String resolveAppInitialRoute() {
  var path = Uri.base.path;
  if (path.length > 1 && path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  if (path.isEmpty) {
    return '/';
  }
  return path;
}

/// Build a customer website route (e.g. `/macrinas-kitchen-and-catering/gallery`).
String customerRoute(String path) {
  if (path.isEmpty || path == '/') {
    return kCustomerSitePrefix;
  }
  final segment = path.startsWith('/') ? path : '/$path';
  if (segment == kCustomerSitePrefix || segment.startsWith('$kCustomerSitePrefix/')) {
    return segment;
  }
  return '$kCustomerSitePrefix$segment';
}

/// True when [routeName] is a staff/back-office route (not customer prefix).
bool isStaffRoute(String? routeName) {
  if (routeName == null || routeName.isEmpty) return false;
  if (routeName.startsWith(kCustomerSitePrefix)) return false;
  const staffPrefixes = [
    '/login',
    '/dashboard',
    '/manage-',
    '/loyalty',
    '/catering-restaurant-menu',
    '/inventory',
    '/restaurant-orders',
    '/reports',
    '/order-history',
    '/archive',
    '/website',
    '/website-admin',
    '/settings',
    '/help-requests',
    '/action-logs',
    '/customer-management',
  ];
  for (final p in staffPrefixes) {
    if (routeName == p || routeName.startsWith('$p/')) return true;
  }
  return false;
}
