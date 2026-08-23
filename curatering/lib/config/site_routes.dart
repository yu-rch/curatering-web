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

/// Returns `true` when a full cross-origin navigation was started.
bool redirectToSiteOrigin(String origin, String path) {
  if (!kIsWeb) return false;
  final target = Uri.parse(origin).replace(path: normalizeRoutePath(path));
  if (browserLocationMatches(target)) return false;
  return redirectBrowserTo(target);
}

/// Same host as the browser (preserves `www.` vs apex). Updates the path only.
void redirectOnCurrentHost(String path) {
  if (!kIsWeb) return;
  final scheme = Uri.base.scheme.isEmpty ? 'https' : Uri.base.scheme;
  final target = Uri(
    scheme: scheme,
    host: getWebHostname(),
    path: normalizeRoutePath(path),
  );
  if (browserLocationMatches(target)) return;
  replaceBrowserPath(target);
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
/// Returns `true` when a full page navigation was started.
bool redirectApexHostToSubdomain(String path) {
  if (!isApexCurateringHost) return false;
  final stripped = stripLegacyCustomerPrefix(path.isEmpty ? '/' : path);
  if (isStaffRoute(stripped)) {
    final staffPath = stripped == '/' ? '/login' : stripped;
    return redirectToSiteOrigin(staffSiteOrigin, staffPath);
  }
  return redirectToSiteOrigin(customerSiteOrigin, stripped);
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

/// Run before [runApp] for legacy bookmarks and staff `/` → `/login`.
/// Does not strip `www.` — Vercel often redirects apex ↔ www; cross-host
/// redirects here caused ERR_TOO_MANY_REDIRECTS on www.staff.curatering.com.
bool bootstrapWebRouting() {
  if (!kIsWeb) return false;

  final rawPath = rawWebPath();

  if (!isStaffSiteHost) return false;

  if (isLegacyBookmarkPath(rawPath)) {
    redirectOnCurrentHost('/login');
    return false;
  }

  if (rawPath == '/' && currentWebPath() == '/') {
    redirectOnCurrentHost('/login');
    return false;
  }

  return false;
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
    '/my-inquiries',
    '/my-orders',
    '/my-profile',
    '/my-tracking',
    '/track-order',
    '/restaurant',
    '/restaurant-feedback',
    '/catering-menu',
    '/checkout',
  };
  if (customerRootPaths.contains(name)) return false;

  const staffPrefixes = [
    '/login',
    '/dashboard',
    '/super-admin-dashboard',
    '/manager-dashboard',
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
    // Exact match, nested path (/p/...), or prefix without requiring a trailing slash
    // so `/manage-events` matches `/manage-`.
    if (name == p || name.startsWith('$p/') || name.startsWith(p)) {
      return true;
    }
  }
  return false;
}

bool isCustomerContentRoute(String? routeName) {
  if (routeName == null || routeName.isEmpty) return false;
  final name = stripLegacyCustomerPrefix(normalizeRoutePath(routeName));
  if (name == '/') return true;
  if (name.startsWith('/p/') && name.length > 3) return true;
  const customerPaths = [
    '/gallery',
    '/contact-us',
    '/inquire',
    '/my-inquiries',
    '/my-orders',
    '/my-profile',
    '/my-tracking',
    '/track-order',
    '/restaurant',
    '/restaurant-feedback',
    '/catering-menu',
    '/checkout',
  ];
  return customerPaths.contains(name);
}

bool isLegacyBookmarkPath(String? path) {
  if (path == null) return false;
  final p = normalizeRoutePath(path);
  return p == kLegacyCustomerPathPrefix ||
      p.startsWith('$kLegacyCustomerPathPrefix/');
}
