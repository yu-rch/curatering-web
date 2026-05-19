import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import 'cart_store.dart';
import '../models/menu_dish.dart';

/// Service for synchronizing cart between mobile and web platforms
class CartSyncService {
  static CartSyncService? _instance;
  static CartSyncService get instance => _instance ??= CartSyncService._();

  CartSyncService._();

  static const String _cartKey = 'cart';
  static const String _lastSyncKey = 'cart_last_sync';
  static const String _deviceIdKey = 'device_id';

  /// Server returns `{ cart: { items: [...] } }` or legacy `{ cart: [...] }`.
  static List<dynamic> _itemsListFromCartPayload(dynamic cartPayload) {
    if (cartPayload is List) return cartPayload;
    if (cartPayload is Map) {
      final items = cartPayload['items'];
      if (items is List) return items;
      if (items is String && items.isNotEmpty) {
        try {
          final decoded = jsonDecode(items);
          if (decoded is List) return decoded;
        } catch (_) {}
      }
    }
    return [];
  }

  static List<dynamic> _itemsListFromTrayPayload(dynamic itemsPayload) {
    if (itemsPayload is List) return itemsPayload;
    if (itemsPayload is String && itemsPayload.isNotEmpty) {
      try {
        final decoded = jsonDecode(itemsPayload);
        if (decoded is List) return decoded;
      } catch (_) {}
    }
    return [];
  }

  /// Cart JSON from tray draft (`dish` nested) or cart_sessions rows (flat columns).
  static CartItem? _parseCartItem(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);

    if (map['dish'] is Map) {
      try {
        return CartItem.fromJson(map);
      } catch (_) {
        return null;
      }
    }

    final dishId = map['dish_id'] ?? map['dishId'];
    if (dishId == null) return null;

    final qty = map['quantity'];
    final quantity = qty is num
        ? qty.toInt()
        : int.tryParse(qty?.toString() ?? '') ?? 1;

    return CartItem(
      dish: MenuDish(
        id: dishId.toString(),
        name: (map['dish_name'] ?? map['dishName'] ?? '').toString(),
        price: (map['dish_price'] ?? map['dishPrice'] ?? '0').toString(),
        category:
            (map['dish_category'] ?? map['dishCategory'] ?? 'restaurant')
                .toString(),
        paxOptions: const [],
        type: (map['dish_type'] ?? map['dishType'] ?? '').toString(),
        mealType:
            (map['meal_type'] ?? map['mealType'] ?? '').toString(),
      ),
      quantity: quantity < 1 ? 1 : quantity,
      selectedSauce:
          (map['selected_sauce'] ?? map['selectedSauce'])?.toString(),
    );
  }

  static void _applyItemsToStore(List<dynamic> rawItems) {
    CartStore.instance.clearCart();
    for (final raw in rawItems) {
      final parsed = _parseCartItem(raw);
      if (parsed == null) continue;
      CartStore.instance.addItem(
        parsed.dish,
        selectedSauce: parsed.selectedSauce,
      );
      if (parsed.quantity > 1) {
        CartStore.instance.updateQuantity(
          parsed.dish.id,
          parsed.quantity,
        );
      }
    }
  }

  /// Sync cart from server to local storage
  Future<void> syncFromServer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('customer_token');

      if (token == null || token.isEmpty) return;

      ApiClient.instance.setCustomerBearer(token);

      var cartItems = <dynamic>[];
      try {
        final trayResponse = await ApiClient.instance.getJson('/api/tray-draft');
        if (trayResponse['success'] == true) {
          cartItems = _itemsListFromTrayPayload(trayResponse['items']);
        }
      } catch (_) {
        /* tray draft may be empty */
      }

      final response = await ApiClient.instance.getJson('/api/cart');
      if (cartItems.isEmpty) {
        cartItems = _itemsListFromCartPayload(response['cart']);
      }

      if (cartItems.isNotEmpty || response['success'] == true) {
        final cartJson = jsonEncode(cartItems);
        await prefs.setString(_cartKey, cartJson);
        await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());

        final localCount = CartStore.instance.items.length;
        if (cartItems.isEmpty && localCount > 0) {
          await syncToServer();
          return;
        }

        if (cartItems.isNotEmpty) {
          _applyItemsToStore(cartItems);
        }
      }
    } catch (e) {
      print('Error syncing cart from server: $e');
    }
  }

  /// Sync local cart to server
  Future<void> syncToServer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('customer_token');

      if (token != null && token.isNotEmpty) {
        ApiClient.instance.setCustomerBearer(token);
        final cartItems = CartStore.instance.items;

        if (cartItems.isNotEmpty) {
          final cartData = cartItems.map((item) => item.toJson()).toList();
          await ApiClient.instance.postJson(
            '/api/cart/sync',
            body: {
              'cart': cartData,
              'deviceId': await _getDeviceId(),
              'timestamp': DateTime.now().toIso8601String(),
            },
          );
          await ApiClient.instance.putJson(
            '/api/tray-draft',
            body: {'items': cartData},
          );

          await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
        }
      }
    } catch (e) {
      print('Error syncing cart to server: $e');
    }
  }

  /// Get or generate device ID for tracking
  Future<String> _getDeviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? deviceId = prefs.getString(_deviceIdKey);

      if (deviceId == null || deviceId.isEmpty) {
        deviceId = 'device_${DateTime.now().millisecondsSinceEpoch}';
        await prefs.setString(_deviceIdKey, deviceId);
      }

      return deviceId;
    } catch (e) {
      return 'device_${DateTime.now().millisecondsSinceEpoch}';
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
      if (await needsSync()) {
        await syncFromServer();
        await syncToServer();
      }
    } catch (e) {
      print('Error initializing cart sync: $e');
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
        await ApiClient.instance.postJson('/api/cart/clear');
        try {
          await ApiClient.instance.delete('/api/tray-draft');
        } catch (_) {
          /* tray may already be empty */
        }
      }

      CartStore.instance.clearCart();
    } catch (e) {
      print('Error clearing cart: $e');
    }
  }
}
