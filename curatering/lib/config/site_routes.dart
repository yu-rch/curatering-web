import 'package:flutter/foundation.dart';

import 'site_redirect_stub.dart'
    if (dart.library.html) 'site_redirect_web.dart';

/// Old bookmark path from when the customer site lived on curatering.com.
const String kLegacyCustomerPathPrefix = '/macrinas-kitchen-and-catering';

/// Production customer storefront host.
const String kCustomerWebHost = String.fromEnvironment(
  'CUSTOMER_WEB_HOST',
  defaultValue: 'macrinas-kitchen.curatering.com',
);

/// Production staff / back-office host.
const String kStaffWebHost = String.fromEnvironment(
  'STAFF_WEB_HOST',
  defaultValue: 'staff.curatering.com',
);

String get _host => Uri.base.host.toLowerCase();

bool get isCustomerSiteHost {
  if (kIsWeb) return _host == kCustomerWebHost.toLowerCase();
  return false;
}

bool get isStaffSiteHost {
  if (kIsWeb) return _host == kStaffWebHost.toLowerCase();
  return false;
}

/// Deprecated apex domain — redirect to a subdomain.
bool get isApexCurateringHost {
  if (!kIsWeb) return false;
  return _host == 'curatering.com' || _host == 'www.curatering.com';
}

String get customerSiteOrigin => 'https://$kCustomerWebHost';

String get staffSiteOrigin => 'https://$kStaffWebHost';

void redirectToSiteOrigin(String origin, String path) {
  if (!kIsWeb) return;
  var p = path.trim();
  if (p.isEmpty) p = '/';
  if (!p.startsWith('/')) p = '/$p';
  redirectBrowserTo(Uri.parse(origin).replace(path: p));
}

/// Send curatering.com / www traffic to the correct subdomain.
void redirectApexHostToSubdomain(String path) {
  if (!isApexCurateringHost) return;
  final stripped = stripLegacyCustomerPrefix(path.isEmpty ? '/' : path);
  if (isStaffRoute(stripped)) {
    final staffPath = stripped == '/' ? '/login' : stripped;
    redirectToSiteOrigin(staffSiteOrigin, staffPath);
    return;
  }
  redirectToSiteOrigin(customerSiteOrigin, stripped);
}

String resolveAppInitialRoute() {
  var path = Uri.base.path;
  if (path.length > 1 && path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  path = stripLegacyCustomerPrefix(path);
  if (path.isEmpty) path = '/';

  if (isStaffSiteHost) {
    if (path == '/') return '/login';
    return path;
  }

  if (path == '/') return '/';
  return path;
}

String stripLegacyCustomerPrefix(String path) {
  if (path == kLegacyCustomerPathPrefix) return '/';
  if (path.startsWith('$kLegacyCustomerPathPrefix/')) {
    final rest = path.substring(kLegacyCustomerPathPrefix.length);
    return rest.isEmpty ? '/' : rest;
  }
  return path;
}

/// Customer paths always use the site root (no path prefix).
String customerRoute(String path) {
  final normalized = stripLegacyCustomerPrefix(
    path.isEmpty || path == '/'
        ? '/'
        : (path.startsWith('/') ? path : '/$path'),
  );
  return normalized == '/' ? '/' : normalized;
}

bool isStaffRoute(String? routeName) {
  if (routeName == null || routeName.isEmpty) return false;
  final name = stripLegacyCustomerPrefix(routeName);
  const customerRootPaths = {
    '/',
    '/gallery',
    '/contact-us',
    '/inquire',
    '/restaurant',
    '/catering-menu',
  };
  if (customerRootPaths.contains(name)) return false;

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
    if (name == p || name.startsWith('$p/')) return true;
  }
  return false;
}

bool isCustomerContentRoute(String? routeName) {
  if (routeName == null || routeName.isEmpty) return false;
  final name = stripLegacyCustomerPrefix(routeName);
  if (name == '/') return true;
  const customerPaths = [
    '/gallery',
    '/contact-us',
    '/inquire',
    '/restaurant',
    '/catering-menu',
  ];
  return customerPaths.contains(name);
}

bool isLegacyBookmarkPath(String? path) {
  if (path == null) return false;
  return path == kLegacyCustomerPathPrefix ||
      path.startsWith('$kLegacyCustomerPathPrefix/');
}
