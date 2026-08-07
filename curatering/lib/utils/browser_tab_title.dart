import 'package:flutter/services.dart';

const String kCustomerSiteBrand = "Macrina's Kitchen and Catering";
const String kStaffSiteBrand = 'Curatering';

/// Sets the browser / app switcher title to `Page - Brand`.
Future<void> setBrowserTabTitle(String pageLabel, {required bool staff}) async {
  final page = pageLabel.trim().isEmpty ? (staff ? 'App' : 'Home') : pageLabel.trim();
  final brand = staff ? kStaffSiteBrand : kCustomerSiteBrand;
  final title = '$page - $brand';
  try {
    await SystemChrome.setApplicationSwitcherDescription(
      ApplicationSwitcherDescription(
        label: title,
        primaryColor: 0xFF1E1E1E,
      ),
    );
  } catch (_) {
    /* web / desktop may ignore */
  }
}

String customerTabTitleForRoute(String path) {
  switch (normalizeTabPath(path)) {
    case '/':
    case '/home':
      return 'Home';
    case '/gallery':
      return 'Gallery';
    case '/catering-menu':
      return 'Catering Menu';
    case '/restaurant':
      return 'Restaurant';
    case '/inquire':
      return 'Inquire Now';
    case '/contact-us':
      return 'Contact Us';
    case '/checkout':
      return 'Checkout';
    case '/payment':
      return 'Payment';
    case '/track-order':
      return 'Track Order';
    case '/my-inquiries':
      return 'My Inquiries';
    case '/my-orders':
      return 'My Orders';
    case '/login':
    case '/customer-login':
      return 'Login';
    default:
      return 'Home';
  }
}

String staffTabTitleForRoute(String path) {
  switch (normalizeTabPath(path)) {
    case '/':
    case '/login':
      return 'Login';
    case '/dashboard':
    case '/super-admin-dashboard':
    case '/manager-dashboard':
      return 'Dashboard';
    case '/live-performance':
      return 'Live Performance';
    case '/manage-events':
      return 'Manage Events';
    case '/loyalty':
      return 'Loyalty Rewards';
    case '/menu':
      return 'Menu';
    case '/restaurant-orders':
      return 'Restaurant Orders';
    case '/reports':
      return 'Reports';
    case '/order-history':
      return 'Order History';
    case '/archive':
      return 'Archive';
    case '/inventory':
      return 'Inventory';
    case '/help-requests':
      return 'Help Requests';
    case '/settings':
      return 'Settings';
    case '/manage-accounts':
      return 'Manage Accounts';
    case '/website-admin':
    case '/website':
      return 'Website';
    case '/cashier':
    case '/pos':
      return 'POS';
    default:
      final cleaned = normalizeTabPath(path).replaceAll('/', ' ').trim();
      if (cleaned.isEmpty) return 'Dashboard';
      return cleaned
          .split(RegExp(r'\s+'))
          .map(
            (w) =>
                w.isEmpty
                    ? w
                    : '${w[0].toUpperCase()}${w.substring(1)}',
          )
          .join(' ');
  }
}

String normalizeTabPath(String path) {
  var p = path.trim();
  if (p.isEmpty) return '/';
  final q = p.indexOf('?');
  if (q >= 0) p = p.substring(0, q);
  final h = p.indexOf('#');
  if (h >= 0) p = p.substring(0, h);
  if (!p.startsWith('/')) p = '/$p';
  if (p.length > 1 && p.endsWith('/')) p = p.substring(0, p.length - 1);
  return p;
}
