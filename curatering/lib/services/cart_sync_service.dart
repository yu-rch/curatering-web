import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import 'cart_store.dart';
import '../models/menu_dish.dart';

/// Service for synchronizing cart between mobile and web platforms.
/// Canonical store: `customer_tray_drafts.tray_items`.
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

  /// Canonical JSON persisted in `customer_tray_drafts.tray_items`.
  static Map<String, dynamic> trayLineToJson(CartItem item) {
    final sauce = item.selectedSauce?.trim();
    final sauceVal = (sauce != null && sauce.isNotEmpty) ? sauce : '';
    final priceNum = double.tryParse(item.dish.price) ?? 0;

    return {
      'dishId': item.dish.id,
      'dishName': item.dish.name,
      'price': priceNum,
      'quantity': item.quantity,
      'selectedSauce': sauceVal.isEmpty ? null : sauceVal,
      'addOnQuantity': sauceVal.isNotEmpty ? item.addOnQuantity : 1,
      'addOns': item.addOns,
      'specialInstructions': item.specialInstructions,
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
          'selectedSauce':
              map['selectedSauce'] ?? map['selected_sauce'] ?? map['dip'],
          'addOnQuantity': map['addOnQuantity'] ?? map['dip_qty'],
          'addOns': map['addOns'] ?? map['add_ons'],
          'specialInstructions':
              map['specialInstructions'] ??
              map['special_instructions'] ??
              map['notes'],
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
    final rawDipQty = map['addOnQuantity'] ?? map['dip_qty'];
    final dipQty =
        rawDipQty is num
            ? rawDipQty.toInt()
            : int.tryParse(rawDipQty?.toString() ?? '') ?? 1;

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
        additionalChargeAmount:
            (map['additionalChargeAmount'] as num?)?.toDouble() ??
            (map['menu_dishes_additional_charge_amount'] as num?)?.toDouble() ??
            0,
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
      addOnQuantity: dipQty < 0 ? 0 : dipQty,
      addOns:
          ((map['add_ons'] ?? map['addOns']) as List<dynamic>?)
              ?.map((e) => e.toString())
              .where((e) => e.trim().isNotEmpty)
              .toList() ??
          const [],
      specialInstructions:
          (map['special_instructions'] ??
                  map['specialInstructions'] ??
                  map['notes'])
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

      // Don't clear local tray if server is empty — local is source of truth
      // Only sync TO server if local has items and server is empty
      if (trayLoaded && CartStore.instance.items.isNotEmpty) {
        // Local has items but server is empty — push local to server
        CartSyncService.instance.syncToServer();
      }
    } catch (e) {
      print('Error syncing cart from server: $e');
    }
  }

  Timer? _syncDebounce;
  bool _syncing = false;

  /// Sync local cart to `customer_tray_drafts.tray_lines` and `tray_items`.
  /// Debounced to avoid rapid-fire duplicate writes.
  Future<void> syncToServer() async {
    _syncDebounce?.cancel();
    _syncDebounce = Timer(const Duration(milliseconds: 500), _doSyncToServer);
  }

  Future<void> _doSyncToServer() async {
    if (_syncing) return;
    _syncing = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('customer_token');

      if (token != null && token.isNotEmpty) {
        ApiClient.instance.setCustomerBearer(token);
        final cartItems = CartStore.instance.items;

        if (cartItems.isNotEmpty) {
          // Deduplicate by dishId+customizations before sending
          final deduped = <Map<String, dynamic>>[];
          for (final item in cartItems) {
            final json = trayLineToJson(item);
            final key = '${json['dish_id']}_${json['selectedSauce'] ?? ''}_${json['specialInstructions'] ?? ''}';
            final existing = deduped.indexWhere((d) =>
                '${d['dish_id']}_${d['selectedSauce'] ?? ''}_${d['specialInstructions'] ?? ''}' == key);
            if (existing >= 0) {
              deduped[existing]['quantity'] = (deduped[existing]['quantity'] as int) + (json['quantity'] as int);
              deduped[existing]['qty'] = deduped[existing]['quantity'];
            } else {
              deduped.add(json);
            }
          }
          await ApiClient.instance.putJson(
            '/api/tray-draft',
            body: {'tray_items': deduped},
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
    } finally {
      _syncing = false;
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
