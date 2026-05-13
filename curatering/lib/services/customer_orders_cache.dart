import 'dart:convert';

/// In-memory cache so switching between My Orders / Order Tracking / My Caterings
/// does not refetch on every navigation. Use [invalidate…] after mutations (e.g. new order).
class CustomerOrdersCache {
  CustomerOrdersCache._();
  static final CustomerOrdersCache instance = CustomerOrdersCache._();

  static const Duration _ttl = Duration(minutes: 5);

  List<Map<String, dynamic>>? _restaurantOrders;
  DateTime? _restaurantFetchedAt;

  List<dynamic>? _eventOrders;
  DateTime? _eventFetchedAt;

  void invalidateRestaurant() {
    _restaurantOrders = null;
    _restaurantFetchedAt = null;
  }

  void invalidateEvents() {
    _eventOrders = null;
    _eventFetchedAt = null;
  }

  void invalidateAll() {
    invalidateRestaurant();
    invalidateEvents();
  }

  bool _fresh(DateTime? at) =>
      at != null && DateTime.now().difference(at) < _ttl;

  /// Parsed restaurant orders (same shape as [MyOrdersPage] uses), or null if stale/missing.
  List<Map<String, dynamic>>? peekRestaurantOrders() {
    if (!_fresh(_restaurantFetchedAt) || _restaurantOrders == null) return null;
    return _restaurantOrders!
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  void setRestaurantOrders(List<Map<String, dynamic>> orders) {
    _restaurantOrders = orders.map((e) => Map<String, dynamic>.from(e)).toList();
    _restaurantFetchedAt = DateTime.now();
  }

  List<dynamic>? peekEventOrders() {
    if (!_fresh(_eventFetchedAt) || _eventOrders == null) return null;
    return List<dynamic>.from(_eventOrders!);
  }

  void setEventOrders(List<dynamic> orders) {
    _eventOrders = List<dynamic>.from(orders);
    _eventFetchedAt = DateTime.now();
  }

  /// Normalize items JSON for one order map (mutates copy).
  static Map<String, dynamic> normalizeRestaurantOrder(Map<String, dynamic> order) {
    final o = Map<String, dynamic>.from(order);
    final rawItems = o['items'];
    if (rawItems is String) {
      try {
        o['items'] = jsonDecode(rawItems);
      } catch (_) {
        o['items'] = <dynamic>[];
      }
    }
    if (o['items'] is! List) {
      o['items'] = <dynamic>[];
    }
    return o;
  }
}
