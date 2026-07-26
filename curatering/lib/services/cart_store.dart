import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/menu_dish.dart';
import 'api_client.dart';
import 'cart_sync_service.dart';
import 'menu_store.dart';

const double kRestaurantAddonExtraPhp = 15;

class CartItem {
  final MenuDish dish;
  int quantity;
  String? selectedSauce;
  int addOnQuantity;
  List<String> addOns;
  String? specialInstructions;

  CartItem({
    required this.dish,
    this.quantity = 1,
    this.selectedSauce,
    this.addOnQuantity = 1,
    this.addOns = const [],
    this.specialInstructions,
  });

  CartItem snapshot() => CartItem(
    dish: dish,
    quantity: quantity,
    selectedSauce: selectedSauce,
    addOnQuantity: addOnQuantity,
    addOns: List<String>.from(addOns),
    specialInstructions: specialInstructions,
  );

  double get addonExtraPerUnit {
    final configured = dish.additionalChargeAmount;
    return configured.isFinite && configured > 0
        ? configured
        : kRestaurantAddonExtraPhp;
  }

  double get addonExtraSubtotal {
    if (selectedSauce?.trim().isNotEmpty != true) return 0;
    final extraQty = addOnQuantity - 1;
    if (extraQty <= 0) return 0;
    return extraQty * addonExtraPerUnit * quantity;
  }

  double get lineSubtotal {
    final base = (double.tryParse(dish.price) ?? 0) * quantity;
    return base + addonExtraSubtotal;
  }

  Map<String, dynamic> toJson() => {
    'dish': {
      'id': dish.id,
      'name': dish.name,
      'price': dish.price,
      'additionalChargeAmount': dish.additionalChargeAmount,
      'category': dish.category,
      'type': dish.type,
      'mealType': dish.mealType,
    },
    'quantity': quantity,
    'selectedSauce': selectedSauce,
    'addOnQuantity': addOnQuantity,
    'dip': selectedSauce,
    'dip_qty': addOnQuantity,
    'addOns': addOns,
    'specialInstructions': specialInstructions,
    'notes': specialInstructions,
  };

  factory CartItem.fromJson(Map<String, dynamic> json) {
    double parseDouble(Object? value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString().trim() ?? '') ?? 0;
    }

    int parseInt(Object? value, {int fallback = 1}) {
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString().trim() ?? '') ?? fallback;
    }

    String? nonEmptyString(Object? value) {
      final text = value?.toString().trim();
      return text == null || text.isEmpty ? null : text;
    }

    final dishJson =
        json['dish'] is Map ? Map<String, dynamic>.from(json['dish']) : {};
    return CartItem(
      dish: MenuDish(
        id: (dishJson['id'] ?? json['dishId'] ?? json['id'] ?? '').toString(),
        name:
            (dishJson['name'] ??
                    json['dishName'] ??
                    json['dish_name'] ??
                    json['name'] ??
                    '')
                .toString(),
        price:
            (dishJson['price'] ??
                    json['dishPrice'] ??
                    json['dish_price'] ??
                    json['price'] ??
                    '0')
                .toString(),
        additionalChargeAmount: parseDouble(
          dishJson['additionalChargeAmount'] ??
              dishJson['menu_dishes_additional_charge_amount'] ??
              dishJson['additional_charge_amount'] ??
              json['additionalChargeAmount'] ??
              json['additional_charge_amount'],
        ),
        category:
            (dishJson['category'] ?? json['category'] ?? 'restaurant')
                .toString(),
        paxOptions: [],
        imageBase64: nonEmptyString(
          dishJson['imageBase64'] ??
              dishJson['image_base64'] ??
              json['imageBase64'] ??
              json['image_base64'],
        ),
        type:
            (dishJson['type'] ?? json['dish_type'] ?? json['type'] ?? '')
                .toString(),
        mealType:
            (dishJson['mealType'] ??
                    dishJson['meal_type'] ??
                    json['mealType'] ??
                    json['meal_type'] ??
                    '')
                .toString(),
      ),
      quantity: parseInt(json['quantity'], fallback: 1),
      selectedSauce: nonEmptyString(json['selectedSauce'] ?? json['dip']),
      addOnQuantity: parseInt(
        json['addOnQuantity'] ?? json['dip_qty'],
        fallback: 1,
      ),
      addOns:
          (json['addOns'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .where((e) => e.trim().isNotEmpty)
              .toList() ??
          const [],
      specialInstructions: nonEmptyString(
        json['specialInstructions'] ?? json['notes'] ?? json['line_note'],
      ),
    );
  }
}

class CartStore extends ChangeNotifier {
  static CartStore? _instance;
  static CartStore get instance => _instance ??= CartStore._();
  static const String _trayKey = 'tray';
  static const String _legacyCartKey = 'cart';

  CartStore._();

  bool _initInProgress = false;
  bool _initialized = false;

  List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);

  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);

  double get totalAmount =>
      _items.fold(0.0, (sum, item) => sum + item.lineSubtotal);

  bool _sameCustomizations(
    CartItem item,
    String? selectedSauce,
    int addOnQuantity,
    List<String> addOns,
    String? specialInstructions,
  ) {
    final normalizedAddOns =
        addOns.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final itemAddOns =
        item.addOns.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    return item.selectedSauce == selectedSauce &&
        item.addOnQuantity == addOnQuantity &&
        listEquals(itemAddOns, normalizedAddOns) &&
        (item.specialInstructions ?? '').trim() ==
            (specialInstructions ?? '').trim();
  }

  void addItem(
    MenuDish dish, {
    String? selectedSauce,
    int addOnQuantity = 1,
    List<String> addOns = const [],
    String? specialInstructions,
  }) {
    final normalizedAddOnQuantity =
        selectedSauce?.trim().isNotEmpty == true ? addOnQuantity : 1;
    final existingIndex = _items.indexWhere(
      (item) =>
          item.dish.id == dish.id &&
          _sameCustomizations(
            item,
            selectedSauce,
            normalizedAddOnQuantity,
            addOns,
            specialInstructions,
          ),
    );

    late final CartItem addedLine;
    if (existingIndex >= 0) {
      _items[existingIndex].quantity++;
      // Send the updated absolute line via PATCH so merge does not rely on
      // a qty=1 delta that can race with a full-cart sync.
      final previousItem = CartItem(
        dish: dish,
        quantity: _items[existingIndex].quantity - 1,
        selectedSauce: selectedSauce,
        addOnQuantity: normalizedAddOnQuantity,
        addOns: addOns,
        specialInstructions: specialInstructions,
      );
      addedLine = _items[existingIndex].snapshot();
      _saveCart();
      notifyListeners();
      unawaited(
        CartSyncService.instance.updateItemOnServer(
          previousItem: previousItem,
          updatedItem: addedLine,
        ),
      );
      return;
    }

    addedLine = CartItem(
      dish: dish,
      selectedSauce: selectedSauce,
      addOnQuantity: normalizedAddOnQuantity,
      addOns: addOns,
      specialInstructions: specialInstructions,
    );
    _items.add(addedLine);

    _saveCart();
    notifyListeners();

    unawaited(CartSyncService.instance.addItemToServer(addedLine));
  }

  void removeItem(String dishId) {
    final removedItems =
        _items
            .where((item) => item.dish.id == dishId)
            .map((item) => item.snapshot())
            .toList();
    _items.removeWhere((item) => item.dish.id == dishId);
    _saveCart();
    notifyListeners();

    unawaited(CartSyncService.instance.removeItemsFromServer(removedItems));
  }

  void removeCartItem(CartItem target) {
    final removedItem = target.snapshot();
    _items.removeWhere((item) => identical(item, target));
    _saveCart();
    notifyListeners();
    unawaited(CartSyncService.instance.removeItemFromServer(removedItem));
  }

  void updateQuantity(String dishId, int quantity) {
    if (quantity <= 0) {
      removeItem(dishId);
      return;
    }

    final existingIndex = _items.indexWhere((item) => item.dish.id == dishId);
    if (existingIndex >= 0) {
      final previousItem = _items[existingIndex].snapshot();
      _items[existingIndex].quantity = quantity;
      final updatedItem = _items[existingIndex].snapshot();
      _saveCart();
      notifyListeners();

      unawaited(
        CartSyncService.instance.updateItemOnServer(
          previousItem: previousItem,
          updatedItem: updatedItem,
        ),
      );
    }
  }

  void updateCartItemQuantity(CartItem target, int quantity) {
    if (quantity <= 0) {
      removeCartItem(target);
      return;
    }
    final existingIndex = _items.indexWhere((item) => identical(item, target));
    if (existingIndex >= 0) {
      final previousItem = _items[existingIndex].snapshot();
      _items[existingIndex].quantity = quantity;
      final updatedItem = _items[existingIndex].snapshot();
      _saveCart();
      notifyListeners();
      unawaited(
        CartSyncService.instance.updateItemOnServer(
          previousItem: previousItem,
          updatedItem: updatedItem,
        ),
      );
    }
  }

  void updateCartItemCustomizations(
    CartItem target, {
    String? selectedSauce,
    int addOnQuantity = 1,
    List<String> addOns = const [],
    String? specialInstructions,
  }) {
    final existingIndex = _items.indexWhere((item) => identical(item, target));
    if (existingIndex < 0) return;
    final previousItem = _items[existingIndex].snapshot();
    _items[existingIndex].selectedSauce = selectedSauce;
    _items[existingIndex].addOnQuantity =
        selectedSauce?.trim().isNotEmpty == true ? addOnQuantity : 1;
    _items[existingIndex].addOns = addOns;
    _items[existingIndex].specialInstructions = specialInstructions;
    final updatedItem = _items[existingIndex].snapshot();
    _saveCart();
    notifyListeners();
    unawaited(
      CartSyncService.instance.updateItemOnServer(
        previousItem: previousItem,
        updatedItem: updatedItem,
      ),
    );
  }

  void clearCart({bool skipServerSync = false}) {
    _items.clear();
    _saveCart();
    notifyListeners();

    if (!skipServerSync) {
      CartSyncService.instance.clearCart();
    }
  }

  /// Apply server tray without triggering a push back to the API.
  void replaceItemsWithoutSync(List<dynamic> rawItems) {
    _items = [];
    for (final raw in rawItems) {
      var parsed = CartSyncService.parseTrayLineItem(raw);
      if (parsed == null) continue;

      // Enrich from local menu cache if name/price/image is missing
      if (parsed.dish.name.isEmpty ||
          parsed.dish.price == '0' ||
          parsed.dish.imageBase64 == null) {
        MenuDish? cached;
        for (final dish in MenuStore.instance.allDishes) {
          if (dish.id == parsed.dish.id) {
            cached = dish;
            break;
          }
        }
        if (cached != null) {
          parsed = CartItem(
            dish: parsed.dish.copyWith(
              name: parsed.dish.name.isEmpty ? cached.name : null,
              price: parsed.dish.price == '0' ? cached.price : null,
              imageBase64: parsed.dish.imageBase64 ?? cached.imageBase64,
              category:
                  parsed.dish.category == 'restaurant' ? cached.category : null,
              additionalChargeAmount:
                  parsed.dish.additionalChargeAmount == 0
                      ? cached.additionalChargeAmount
                      : null,
            ),
            quantity: parsed.quantity,
            selectedSauce: parsed.selectedSauce,
            addOnQuantity: parsed.addOnQuantity,
            addOns: parsed.addOns,
            specialInstructions: parsed.specialInstructions,
          );
        }
      }

      final parsedItem = parsed;
      final existingIndex = _items.indexWhere(
        (item) =>
            item.dish.id == parsedItem.dish.id &&
            _sameCustomizations(
              item,
              parsedItem.selectedSauce,
              parsedItem.addOnQuantity,
              parsedItem.addOns,
              parsedItem.specialInstructions,
            ),
      );
      if (existingIndex >= 0) {
        _items[existingIndex].quantity += parsedItem.quantity;
      } else {
        _items.add(parsedItem);
      }
    }
    _saveCart();
    notifyListeners();
  }

  Future<void> _saveCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = jsonEncode(_items.map((item) => item.toJson()).toList());
      await prefs.setString(_trayKey, cartJson);
      await prefs.remove(_legacyCartKey);
    } catch (e) {
      debugPrint('Error saving cart: $e');
    }
  }

  Future<void> _loadCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson =
          prefs.getString(_trayKey) ?? prefs.getString(_legacyCartKey);

      if (cartJson != null) {
        final List<dynamic> decoded = jsonDecode(cartJson);
        _items =
            decoded
                .map((item) {
                  final parsed = CartSyncService.parseTrayLineItem(item);
                  if (parsed != null) return parsed;
                  if (item is Map) {
                    return CartItem.fromJson(Map<String, dynamic>.from(item));
                  }
                  return null;
                })
                .whereType<CartItem>()
                .toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading cart: $e');
    }
  }

  Future<void> init() async {
    if (_initInProgress) return;
    if (_initialized) return;
    _initInProgress = true;
    try {
      await _loadCart();
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('customer_token');
      if (token == null || token.isEmpty) {
        CartSyncService.instance.stopRealtimeSync();
        if (_items.isNotEmpty) {
          _items = [];
          await _saveCart();
          notifyListeners();
        }
        return;
      }
      ApiClient.instance.setCustomerBearer(token);
      await CartSyncService.instance.syncFromServer();
      CartSyncService.instance.startRealtimeSync();
    } finally {
      _initInProgress = false;
      _initialized = true;
    }
  }

  /// Call after logout so the next login re-syncs tray from the server.
  void resetInitState() {
    CartSyncService.instance.stopRealtimeSync();
    _initialized = false;
    _initInProgress = false;
  }
}
