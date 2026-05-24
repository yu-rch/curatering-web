/// Route keys match [AppScaffold] sidebar `route` values and [main.dart] named routes.
class PagePermissionRoutes {
  PagePermissionRoutes._();

  static const String dashboard = '/dashboard';
  static const String livePerformance = '/live-performance';
  static const String manageEvents = '/manage-events';
  static const String eventDesignOptions = '/event-design-options';
  static const String loyalty = '/loyalty';
  static const String menu = '/menu';
  static const String restaurantOrders = '/restaurant-orders';
  static const String reports = '/reports';
  static const String orderHistory = '/order-history';
  static const String archive = '/archive';
  static const String inventory = '/inventory';
  static const String settings = '/settings';
  static const String helpRequests = '/help-requests';

  static const List<(String label, String route)> togglesForStaff = [
    ('Dashboard', dashboard),
    ('Live performance', livePerformance),
    ('Manage Events', manageEvents),
    ('Event Design Options', eventDesignOptions),
    ('Loyalty Rewards', loyalty),
    ('Menu', menu),
    ('Restaurant Orders', restaurantOrders),
    ('Reports', reports),
    ('Order History', orderHistory),
    ('Archive', archive),
    ('Inventory', inventory),
    ('Help Requests', helpRequests),
    ('Settings', settings),
  ];
}

bool pageRouteAllowed(String route, Map<String, dynamic>? pagePermissions) {
  if (pagePermissions == null || pagePermissions.isEmpty) return true;
  final v = pagePermissions[route];
  if (v == null) return true;
  if (v is bool) return v;
  return true;
}
