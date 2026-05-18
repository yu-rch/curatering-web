/// Customer-facing site lives under this path prefix (staff app uses root paths).
const String kCustomerSitePrefix = '/macrinas-kitchen-and-catering';

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
