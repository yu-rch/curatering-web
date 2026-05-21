import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import 'cart_store.dart';
import '../models/menu_dish.dart';

/// Service for synchronizing cart between mobile and web platforms.
/// Canonical store: `customer_tray_drafts.tray_lines` + `tray_items`.
class CartSyncService {
  static CartSyncService? _instance;
  static CartSyncService get instance => _instance ??= CartSyncService._();

  CartSyncService._();

  static const String _cartKey = 'cart';
  static const String _lastSyncKey = 'cart_last_sync';

  /// Extract line items from GET /api/tray-draft (prefers non-empty
  /// `tray_items`, then `tray_lines` for web/mobile compatibility).
  static List<dynamic> _itemsListFromTrayDraftResponse(
    Map<String, dynamic> payload,
  ) {
    final itemsRaw = payload['tray_items'] ?? payload['trayItems'];
    final fromItems = _itemsListFromTrayPayload(itemsRaw);
    if (fromItems.isNotEmpty) return fromItems;

    final linesRaw = payload['tray_lines'] ?? payload['trayLines'];
    final fromLines = _itemsListFromTrayPayload(linesRaw);
    if (fromLines.isNotEmpty) return fromLines;

    final items = _itemsListFromTrayPayload(payload['items']);
    if (items.isNotEmpty) return items;

    if (itemsRaw != null) {
      return fromItems;
    }
    return fromLines;
  }

  static List<dynamic> _itemsListFromTrayPayload(dynamic payload) {
    if (payload is Map) {
      final nested =
          payload['tray_items'] ??
          payload['trayItems'] ??
          payload['tray_lines'] ??
          payload['trayLines'] ??
          payload['items'];
      return _itemsListFromTrayPayload(nested);
    }
    if (payload is List) return payload;
    if (payload is String && payload.isNotEmpty) {
      try {
        final decoded = jsonDecode(payload);
        if (decoded is List) return decoded;
      } catch (_) {}
    }
    return [];
  }

  /// JSON for `customer_tray_drafts.tray_lines` / `tray_items`.
  static Map<String, dynamic> trayLineToJson(CartItem item) {
    final sauce = item.selectedSauce?.trim();
    final sauceVal = (sauce != null && sauce.isNotEmpty) ? sauce : '';
    final priceNum = double.tryParse(item.dish.price) ?? 0;

    return {
      'dishId': item.dish.id,
      'dish_id': item.dish.id,
      'dishName': item.dish.name,
      'dish_name': item.dish.name,
      'name': item.dish.name,
      'item_name': item.dish.name,
      'dishPrice': item.dish.price,
      'dish_price': item.dish.price,
      'price': priceNum,
      'quantity': item.quantity,
      'qty': item.quantity,
      'selectedSauce': sauceVal.isEmpty ? null : sauceVal,
      'selected_sauce': sauceVal.isEmpty ? null : sauceVal,
      'dip': sauceVal,
      'dip_qty': sauceVal.isNotEmpty ? item.quantity : 0,
      'dish_category': item.dish.category,
      'dishCategory': item.dish.category,
      'dish_type': item.dish.type,
      'dishType': item.dish.type,
      'meal_type': item.dish.mealType,
      'mealType': item.dish.mealType,
      'dish': {
        'id': item.dish.id,
        'name': item.dish.name,
        'price': item.dish.price,
        'category': item.dish.category,
        'type': item.dish.type,
        'mealType': item.dish.mealType,
      },
    };
  }

  /// Cart JSON from `customer_tray_drafts.tray_lines` / `tray_items`.
  static CartItem? parseTrayLineItem(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);

    final nestedDish = map['dish'] ?? map['menu_item'] ?? map['menuItem'];
    if (nestedDish is Map) {
      try {
        return CartItem.fromJson({
          'dish': Map<String, dynamic>.from(nestedDish),
          'quantity': map['quantity'] ?? 1,
          'selectedSauce': map['selectedSauce'] ?? map['selected_sauce'],
        });
      } catch (_) {
        return null;
      }
    }

    final dishId =
        map['dish_id'] ?? map['dishId'] ?? map['id'] ?? map['menu_dish_id'];
    if (dishId == null) return null;

    final qty = map['quantity'] ?? map['qty'] ?? map['dip_qty'];
    final quantity =
        qty is num ? qty.toInt() : int.tryParse(qty?.toString() ?? '') ?? 1;

    return CartItem(
      dish: MenuDish(
        id: dishId.toString(),
        name:
            (map['dish_name'] ??
                    map['dishName'] ??
                    map['item_name'] ??
                    map['name'] ??
                    '')
                .toString(),
        price:
            (map['dish_price'] ?? map['dishPrice'] ?? map['price'] ?? '0')
                .toString(),
        category:
            (map['dish_category'] ??
                    map['dishCategory'] ??
                    map['category'] ??
                    'restaurant')
                .toString(),
        paxOptions: const [],
        type:
            (map['dish_type'] ?? map['dishType'] ?? map['type'] ?? '')
                .toString(),
        mealType: (map['meal_type'] ?? map['mealType'] ?? '').toString(),
      ),
      quantity: quantity < 1 ? 1 : quantity,
      selectedSauce:
          (map['selected_sauce'] ?? map['selectedSauce'] ?? map['dip'])
              ?.toString(),
    );
  }

  static void _applyItemsToStore(List<dynamic> rawItems) {
    CartStore.instance.replaceItemsWithoutSync(rawItems);
  }

  static Future<void> _persistLocalCart(List<dynamic> cartItems) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cartKey, jsonEncode(cartItems));
    await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
  }

  /// Sync cart from server to local storage.
  Future<void> syncFromServer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('customer_token');

      if (token == null || token.isEmpty) return;

      ApiClient.instance.setCustomerBearer(token);

      var trayItems = <dynamic>[];
      var trayLoaded = false;
      try {
        final trayResponse = await ApiClient.instance.getJson(
          '/api/tray-draft',
        );
        if (trayResponse['success'] == true) {
          trayLoaded = true;
          trayItems = _itemsListFromTrayDraftResponse(trayResponse);
        }
      } catch (_) {
        /* tray draft may be empty */
      }

      if (!trayLoaded && trayItems.isEmpty) return;

      if (trayItems.isNotEmpty) {
        await _persistLocalCart(trayItems);
        _applyItemsToStore(trayItems);
        return;
      }

      if (trayLoaded) {
        await prefs.remove(_cartKey);
        await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
        _applyItemsToStore(const []);
      }
    } catch (e) {
      print('Error syncing cart from server: $e');
    }
  }

  /// Sync local cart to `customer_tray_drafts.tray_lines` and `tray_items`.
  Future<void> syncToServer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('customer_token');

      if (token != null && token.isNotEmpty) {
        ApiClient.instance.setCustomerBearer(token);
        final cartItems = CartStore.instance.items;

        if (cartItems.isNotEmpty) {
          final trayData = cartItems.map(trayLineToJson).toList();
          await ApiClient.instance.putJson(
            '/api/tray-draft',
            body: {'tray_lines': trayData, 'tray_items': trayData},
          );

          await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
        } else {
          try {
            await ApiClient.instance.delete('/api/tray-draft');
          } catch (_) {
            /* tray may already be empty */
          }
        }
      }
    } catch (e) {
      print('Error syncing cart to server: $e');
    }
  }

  /// Check if sync is needed based on last sync time
  Future<bool> needsSync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSync = prefs.getString(_lastSyncKey);

      if (lastSync == null) return true;

      final lastSyncTime = DateTime.parse(lastSync);
      final now = DateTime.now();

      return now.difference(lastSyncTime).inMinutes > 5;
    } catch (e) {
      return true;
    }
  }

  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('customer_token');
      if (token == null || token.isEmpty) return;

      ApiClient.instance.setCustomerBearer(token);
      await syncFromServer();
    } catch (e) {
      print('Error initializing cart sync: $e');
    }
  }

  /// After login: pull mobile tray, or push pre-login web cart if server tray is empty.
  Future<void> syncAfterLogin() async {
    final prefs = await SharedPreferences.getInstance();
    List<dynamic> preLoginCart = const [];
    final localJson = prefs.getString(_cartKey);
    if (localJson != null && localJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(localJson);
        if (decoded is List && decoded.isNotEmpty) {
          preLoginCart = decoded;
        }
      } catch (_) {}
    }

    await syncFromServer();

    if (CartStore.instance.items.isEmpty && preLoginCart.isNotEmpty) {
      CartStore.instance.replaceItemsWithoutSync(preLoginCart);
      await syncToServer();
    }
  }

  Future<void> forceSync() async {
    await syncFromServer();
    await syncToServer();
  }

  Future<void> clearCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cartKey);
      await prefs.remove(_lastSyncKey);

      final token = prefs.getString('customer_token');
      if (token != null && token.isNotEmpty) {
        ApiClient.instance.setCustomerBearer(token);
        try {
          await ApiClient.instance.delete('/api/tray-draft');
        } catch (_) {
          /* tray may already be empty */
        }
      }

      CartStore.instance.clearCart(skipServerSync: true);
    } catch (e) {
      print('Error clearing cart: $e');
    }
  }
}
