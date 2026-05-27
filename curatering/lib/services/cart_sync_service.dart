import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import 'cart_store.dart';
import 'menu_store.dart';
import '../models/menu_dish.dart';

/// Service for synchronizing cart between mobile and web platforms.
/// Canonical store: `customer_tray_drafts.tray_items`.
class CartSyncService {
  static CartSyncService? _instance;
  static CartSyncService get instance => _instance ??= CartSyncService._();

  CartSyncService._();

  static const String _trayKey = 'tray';
  static const String _legacyCartKey = 'cart';
  static const String _lastSyncKey = 'tray_last_sync';
  static const String _legacyLastSyncKey = 'cart_last_sync';
  static const Duration _realtimePollInterval = Duration(seconds: 2);

  Timer? _realtimeTimer;
  bool _realtimePulling = false;
  Timer? _syncDebounce;
  bool _syncing = false;
  int _localWriteDepth = 0;
  Future<void> _mutationQueue = Future<void>.value();
  String? _lastServerUpdatedAt;

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

  /// Canonical JSON for `customer_tray_drafts.tray_items`.
  ///
  /// Keep this intentionally small so web and mobile share the same tray line
  /// contract. Dish details are hydrated from the menu catalog when displayed.
  static Map<String, dynamic> trayLineToJson(CartItem item) {
    final sauce = item.selectedSauce?.trim();
    final sauceVal = (sauce != null && sauce.isNotEmpty) ? sauce : '';
    final priceNum = double.tryParse(item.dish.price) ?? 0;
    final addOnQty = sauceVal.isNotEmpty ? item.addOnQuantity : 1;
    final category =
        item.dish.category.trim().isNotEmpty
            ? item.dish.category.trim()
            : 'restaurant';
    final dishType =
        item.dish.effectiveMealType.trim().isNotEmpty
            ? item.dish.effectiveMealType.trim()
            : item.dish.type.trim();
    final mealType = item.dish.effectiveMealType.trim();
    final imageBase64 = item.dish.imageBase64;

    return {
      'id': item.dish.id,
      'dishId': item.dish.id,
      'dish_id': item.dish.id,
      'dishName': item.dish.name,
      'dish_name': item.dish.name,
      'name': item.dish.name,
      'item_name': item.dish.name,
      'dishPrice': item.dish.price,
      'dish_price': item.dish.price,
      'price': priceNum,
      'dip': sauceVal,
      'qty': item.quantity,
      'quantity': item.quantity,
      'category': category,
      'dish_type': dishType,
      'dishType': dishType,
      'meal_type': mealType,
      'mealType': mealType,
      'image_base64': imageBase64,
      'imageBase64': imageBase64,
      'selectedSauce': sauceVal.isEmpty ? null : sauceVal,
      'selected_sauce': sauceVal.isEmpty ? null : sauceVal,
      'notes': item.specialInstructions?.trim() ?? '',
      'specialInstructions': item.specialInstructions,
      'special_instructions': item.specialInstructions,
      'dip_qty': addOnQty,
      'addOnQuantity': addOnQty,
      'addOns': item.addOns,
      'dish': {
        'id': item.dish.id,
        'name': item.dish.name,
        'price': item.dish.price,
        'additionalChargeAmount': item.dish.additionalChargeAmount,
        'category': category,
        'type': dishType,
        'mealType': mealType,
        'meal_type': mealType,
        'image_base64': imageBase64,
        'imageBase64': imageBase64,
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
        final dish = Map<String, dynamic>.from(nestedDish);
        dish.putIfAbsent('category', () => map['category']);
        dish.putIfAbsent('type', () => map['dish_type'] ?? map['dishType']);
        dish.putIfAbsent('mealType', () => map['meal_type'] ?? map['mealType']);
        dish.putIfAbsent(
          'image_base64',
          () => map['image_base64'] ?? map['imageBase64'],
        );
        return CartItem.fromJson({
          'dish': dish,
          'quantity': map['quantity'] ?? map['qty'] ?? 1,
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
    MenuDish? catalogDish;
    for (final dish in MenuStore.instance.activeDishes) {
      if (dish.id == dishId.toString()) {
        catalogDish = dish;
        break;
      }
    }

    final qty = map['quantity'] ?? map['qty'] ?? map['dip_qty'];
    final quantity =
        qty is num ? qty.toInt() : int.tryParse(qty?.toString() ?? '') ?? 1;
    final rawDipQty = map['addOnQuantity'] ?? map['dip_qty'];
    final dipQty =
        rawDipQty is num
            ? rawDipQty.toInt()
            : int.tryParse(rawDipQty?.toString() ?? '') ?? 1;

    double parseDouble(Object? value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString().trim() ?? '') ?? 0;
    }

    String? nonEmptyString(Object? value) {
      final text = value?.toString().trim();
      return text == null || text.isEmpty ? null : text;
    }

    return CartItem(
      dish: MenuDish(
        id: dishId.toString(),
        name:
            (map['dish_name'] ??
                    map['dishName'] ??
                    map['item_name'] ??
                    map['name'] ??
                    catalogDish?.name ??
                    '')
                .toString(),
        price:
            (map['dish_price'] ??
                    map['dishPrice'] ??
                    map['price'] ??
                    catalogDish?.price ??
                    '0')
                .toString(),
        additionalChargeAmount: parseDouble(
          map['additionalChargeAmount'] ??
              map['menu_dishes_additional_charge_amount'] ??
              map['additional_charge_amount'] ??
              catalogDish?.additionalChargeAmount,
        ),
        category:
            (map['dish_category'] ??
                    map['dishCategory'] ??
                    map['category'] ??
                    catalogDish?.category ??
                    'restaurant')
                .toString(),
        paxOptions: const [],
        type:
            (map['dish_type'] ??
                    map['dishType'] ??
                    map['type'] ??
                    catalogDish?.type ??
                    '')
                .toString(),
        mealType:
            (map['meal_type'] ?? map['mealType'] ?? catalogDish?.mealType ?? '')
                .toString(),
        imageBase64: catalogDish?.imageBase64,
        sauces: catalogDish?.sauces ?? const [],
        supportsAddOns: catalogDish?.supportsAddOns ?? false,
        ingredients: catalogDish?.ingredients ?? const [],
        publicDescription: catalogDish?.publicDescription ?? '',
        allergens: catalogDish?.allergens ?? '',
      ),
      quantity: quantity < 1 ? 1 : quantity,
      selectedSauce: nonEmptyString(
        map['selected_sauce'] ?? map['selectedSauce'] ?? map['dip'],
      ),
      addOnQuantity: dipQty < 0 ? 0 : dipQty,
      addOns:
          ((map['add_ons'] ?? map['addOns']) as List<dynamic>?)
              ?.map((e) => e.toString())
              .where((e) => e.trim().isNotEmpty)
              .toList() ??
          const [],
      specialInstructions: nonEmptyString(
        map['special_instructions'] ??
            map['specialInstructions'] ??
            map['notes'],
      ),
    );
  }

  static void _applyItemsToStore(List<dynamic> rawItems) {
    CartStore.instance.replaceItemsWithoutSync(rawItems);
  }

  static Future<void> _persistLocalCart(List<dynamic> cartItems) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_trayKey, jsonEncode(cartItems));
    await prefs.remove(_legacyCartKey);
    await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
    await prefs.remove(_legacyLastSyncKey);
  }

  Future<void> _applyMutationResponse(Map<String, dynamic> response) async {
    _lastServerUpdatedAt = response['updatedAt']?.toString();
    if (response.containsKey('tray_items') ||
        response.containsKey('trayItems') ||
        response.containsKey('items')) {
      final savedItems = _itemsListFromTrayDraftResponse(response);
      await _persistLocalCart(savedItems);
      _applyItemsToStore(savedItems);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
  }

  Future<void> _enqueueServerMutation(Future<void> Function() mutation) {
    final next = _mutationQueue.then((_) async {
      _localWriteDepth++;
      try {
        await mutation();
      } finally {
        _localWriteDepth--;
      }
    });
    _mutationQueue = next.catchError((_) {});
    return next;
  }

  /// Sync cart from server to local storage.
  Future<void> syncFromServer({
    bool onlyIfChanged = false,
    bool pushLocalWhenServerEmpty = true,
  }) async {
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
          final updatedAt = trayResponse['updatedAt']?.toString();
          if (onlyIfChanged &&
              updatedAt != null &&
              updatedAt.isNotEmpty &&
              updatedAt == _lastServerUpdatedAt) {
            return;
          }
          _lastServerUpdatedAt = updatedAt;
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
        if (pushLocalWhenServerEmpty && CartStore.instance.items.isNotEmpty) {
          unawaited(syncToServer());
          return;
        }
        await prefs.remove(_trayKey);
        await prefs.remove(_legacyCartKey);
        await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
        await prefs.remove(_legacyLastSyncKey);
        _applyItemsToStore(const []);
      }
    } catch (e) {
      print('Error syncing cart from server: $e');
    }
  }

  /// Sync local cart to `customer_tray_drafts.tray_items`.
  Future<void> syncToServer() async {
    _syncDebounce?.cancel();
    _syncDebounce = Timer(const Duration(milliseconds: 500), _doSyncToServer);
  }

  Future<void> _doSyncToServer() async {
    if (_syncing) return;
    _syncing = true;
    _localWriteDepth++;
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
            final key =
                '${json['id']}_${json['dip'] ?? ''}_${json['notes'] ?? ''}_${json['dip_qty'] ?? 1}';
            final existing = deduped.indexWhere(
              (d) =>
                  '${d['id']}_${d['dip'] ?? ''}_${d['notes'] ?? ''}_${d['dip_qty'] ?? 1}' ==
                  key,
            );
            if (existing >= 0) {
              deduped[existing]['quantity'] =
                  (deduped[existing]['quantity'] as int) +
                  (json['quantity'] as int);
              deduped[existing]['qty'] = deduped[existing]['quantity'];
            } else {
              deduped.add(json);
            }
          }
          final response = await ApiClient.instance.putJson(
            '/api/tray-draft',
            body: {'tray_items': deduped, 'merge': true},
          );
          _lastServerUpdatedAt = response['updatedAt']?.toString();

          await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
        } else {
          try {
            final response = await ApiClient.instance.delete('/api/tray-draft');
            _lastServerUpdatedAt = response['updatedAt']?.toString();
          } catch (_) {
            /* tray may already be empty */
          }
        }
      }
    } catch (e) {
      print('Error syncing cart to server: $e');
    } finally {
      _syncing = false;
      _localWriteDepth--;
    }
  }

  Future<void> addItemToServer(CartItem item) {
    return _enqueueServerMutation(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('customer_token');
        if (token == null || token.isEmpty) return;

        ApiClient.instance.setCustomerBearer(token);
        final response = await ApiClient.instance.putJson(
          '/api/tray-draft',
          body: {
            'tray_items': [trayLineToJson(item)],
            'merge': true,
          },
        );
        await _applyMutationResponse(response);
      } catch (e) {
        print('Error adding item to server tray: $e');
      }
    });
  }

  Future<void> updateItemOnServer({
    required CartItem previousItem,
    required CartItem updatedItem,
  }) {
    return _enqueueServerMutation(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('customer_token');
        if (token == null || token.isEmpty) return;

        ApiClient.instance.setCustomerBearer(token);
        final response = await ApiClient.instance.patchJson(
          '/api/tray-draft/line',
          body: {
            'match': trayLineToJson(previousItem),
            'item': trayLineToJson(updatedItem),
          },
        );
        await _applyMutationResponse(response);
      } catch (e) {
        print('Error updating server tray item: $e');
      }
    });
  }

  Future<void> removeItemFromServer(CartItem item) {
    return removeItemsFromServer([item]);
  }

  Future<void> removeItemsFromServer(List<CartItem> items) {
    if (items.isEmpty) return Future<void>.value();
    return _enqueueServerMutation(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('customer_token');
        if (token == null || token.isEmpty) return;

        ApiClient.instance.setCustomerBearer(token);
        final response = await ApiClient.instance.delete(
          '/api/tray-draft/line',
          body: {'matches': items.map(trayLineToJson).toList()},
        );
        await _applyMutationResponse(response);
      } catch (e) {
        print('Error removing server tray item: $e');
      }
    });
  }

  /// Check if sync is needed based on last sync time
  Future<bool> needsSync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSync =
          prefs.getString(_lastSyncKey) ?? prefs.getString(_legacyLastSyncKey);

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
      startRealtimeSync();
    } catch (e) {
      print('Error initializing cart sync: $e');
    }
  }

  /// After login: pull mobile tray, or push pre-login web cart if server tray is empty.
  Future<void> syncAfterLogin() async {
    final prefs = await SharedPreferences.getInstance();
    List<dynamic> preLoginCart = const [];
    final localJson =
        prefs.getString(_trayKey) ?? prefs.getString(_legacyCartKey);
    if (localJson != null && localJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(localJson);
        if (decoded is List && decoded.isNotEmpty) {
          preLoginCart = decoded;
        }
      } catch (_) {}
    }

    await syncFromServer();
    startRealtimeSync();

    if (CartStore.instance.items.isEmpty && preLoginCart.isNotEmpty) {
      CartStore.instance.replaceItemsWithoutSync(preLoginCart);
      await syncToServer();
    }
  }

  void startRealtimeSync() {
    _realtimeTimer?.cancel();
    _realtimeTimer = Timer.periodic(
      _realtimePollInterval,
      (_) => _pullRealtimeChanges(),
    );
  }

  void stopRealtimeSync() {
    _realtimeTimer?.cancel();
    _realtimeTimer = null;
    _lastServerUpdatedAt = null;
  }

  Future<void> _pullRealtimeChanges() async {
    if (_realtimePulling) return;
    if (_localWriteDepth > 0) return;
    _realtimePulling = true;
    try {
      await syncFromServer(
        onlyIfChanged: true,
        pushLocalWhenServerEmpty: false,
      );
    } finally {
      _realtimePulling = false;
    }
  }

  Future<void> forceSync() async {
    await syncFromServer();
    await syncToServer();
  }

  Future<void> clearCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_trayKey);
      await prefs.remove(_legacyCartKey);
      await prefs.remove(_lastSyncKey);
      await prefs.remove(_legacyLastSyncKey);

      final token = prefs.getString('customer_token');
      if (token != null && token.isNotEmpty) {
        ApiClient.instance.setCustomerBearer(token);
        try {
          final response = await ApiClient.instance.delete('/api/tray-draft');
          _lastServerUpdatedAt = response['updatedAt']?.toString();
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
