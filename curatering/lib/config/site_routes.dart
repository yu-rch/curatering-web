import 'package:flutter/foundation.dart';

import 'site_location_stub.dart'
    if (dart.library.html) 'site_location_web.dart';
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

String get _host {
  if (kIsWeb) return getWebHostname();
  return '';
}

/// Strips leading `www.` so `www.staff.curatering.com` → `staff.curatering.com`.
String normalizeWebHost(String host) {
  var h = host.toLowerCase().trim();
  while (h.startsWith('www.')) {
    h = h.substring(4);
  }
  return h;
}

String get _normalizedHost {
  if (!kIsWeb) return '';
  return normalizeWebHost(_host);
}

bool get isCustomerSiteHost {
  if (!kIsWeb) return false;
  final h = _normalizedHost;
  if (h == kCustomerWebHost.toLowerCase()) return true;
  final parts = h.split('.');
  if (parts.isEmpty) return false;
  return parts.first == 'macrinas-kitchen';
}

bool get isStaffSiteHost {
  if (!kIsWeb) return false;
  final h = _normalizedHost;
  if (h == kStaffWebHost.toLowerCase()) return true;
  final parts = h.split('.');
  if (parts.isEmpty) return false;
  return parts.first == 'staff';
}

/// Deprecated apex domain — redirect to a subdomain.
bool get isApexCurateringHost {
  if (!kIsWeb) return false;
  return _normalizedHost == 'curatering.com';
}

String get customerSiteOrigin => 'https://$kCustomerWebHost';

String get staffSiteOrigin => 'https://$kStaffWebHost';

void redirectToSiteOrigin(String origin, String path) {
  if (!kIsWeb) return;
  final target = Uri.parse(origin).replace(path: normalizeRoutePath(path));
  if (browserLocationMatches(target)) return;
  redirectBrowserTo(target);
}

/// Staff routes (e.g. `/login`) belong on the staff host only.
bool needsRedirectToStaffSite(String? routeName) {
  if (!isStaffRoute(routeName)) return false;
  return !isStaffSiteHost;
}

/// Customer storefront routes belong on the customer host only.
bool needsRedirectToCustomerSite(String? routeName) {
  if (!isCustomerContentRoute(routeName)) return false;
  return !isCustomerSiteHost;
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

String normalizeRoutePath(String path) {
  var p = path.trim();
  if (p.isEmpty) return '/';
  if (!p.startsWith('/')) p = '/$p';
  return p;
}

/// Unstripped browser path.
String rawWebPath() {
  if (!kIsWeb) return '/';
  return normalizeRoutePath(getWebPathname());
}

/// Browser URL path with legacy prefix removed.
String currentWebPath() {
  return stripLegacyCustomerPrefix(rawWebPath());
}

String resolveAppInitialRoute() {
  var path = normalizeRoutePath(currentWebPath());

  if (isStaffSiteHost) {
    if (path == '/' || isLegacyBookmarkPath(rawWebPath())) return '/login';
    return path;
  }

  if (isCustomerSiteHost) {
    return path;
  }

  return path;
}

/// Run before [runApp] to fix www staff host, legacy bookmarks, and staff `/`.
void bootstrapWebRouting() {
  if (!kIsWeb) return;

  final host = _host.toLowerCase();
  final rawPath = rawWebPath();
  final staffCanonical = kStaffWebHost.toLowerCase();
  final customerCanonical = kCustomerWebHost.toLowerCase();

  if (host == 'www.$staffCanonical') {
    var target = rawPath;
    if (target == '/' || isLegacyBookmarkPath(rawPath)) target = '/login';
    redirectBrowserTo(Uri.parse('https://$staffCanonical$target'));
    return;
  }

  if (host == 'www.$customerCanonical') {
    redirectBrowserTo(Uri.parse('https://$customerCanonical$rawPath'));
    return;
  }

  if (!isStaffSiteHost) return;

  if (isLegacyBookmarkPath(rawPath)) {
    redirectToSiteOrigin(staffSiteOrigin, '/login');
    return;
  }

  if (rawPath == '/' && currentWebPath() == '/') {
    redirectToSiteOrigin(staffSiteOrigin, '/login');
    return;
  }
}

String stripLegacyCustomerPrefix(String path) {
  final p = normalizeRoutePath(path);
  if (p == kLegacyCustomerPathPrefix) return '/';
  if (p.startsWith('$kLegacyCustomerPathPrefix/')) {
    final rest = p.substring(kLegacyCustomerPathPrefix.length);
    return rest.isEmpty ? '/' : rest;
  }
  return p;
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
  final name = stripLegacyCustomerPrefix(normalizeRoutePath(routeName));
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
    '/customer-feedback',
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
  final name = stripLegacyCustomerPrefix(normalizeRoutePath(routeName));
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
  final p = normalizeRoutePath(path);
  return p == kLegacyCustomerPathPrefix ||
      p.startsWith('$kLegacyCustomerPathPrefix/');
}
