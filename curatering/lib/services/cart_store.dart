import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/menu_dish.dart';
import 'api_client.dart';
import 'cart_sync_service.dart';

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
    return CartItem(
      dish: MenuDish(
        id: json['dish']['id'],
        name: json['dish']['name'],
        price: json['dish']['price'],
        additionalChargeAmount:
            (json['dish']['additionalChargeAmount'] as num?)?.toDouble() ?? 0,
        category: json['dish']['category'] ?? 'restaurant',
        paxOptions: [],
        type: json['dish']['type'] ?? '',
        mealType:
            (json['dish']['mealType'] ?? json['dish']['meal_type'] ?? '')
                .toString(),
      ),
      quantity: json['quantity'] ?? 1,
      selectedSauce: json['selectedSauce'] ?? json['dip'],
      addOnQuantity:
          (json['addOnQuantity'] as num?)?.toInt() ??
          (json['dip_qty'] as num?)?.toInt() ??
          1,
      addOns:
          (json['addOns'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .where((e) => e.trim().isNotEmpty)
              .toList() ??
          const [],
      specialInstructions:
          (json['specialInstructions'] ?? json['notes'] ?? json['line_note'])
              ?.toString(),
    );
  }
}

class CartStore extends ChangeNotifier {
  static CartStore? _instance;
  static CartStore get instance => _instance ??= CartStore._();

  CartStore._();

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

    if (existingIndex >= 0) {
      _items[existingIndex].quantity++;
    } else {
      _items.add(
        CartItem(
          dish: dish,
          selectedSauce: selectedSauce,
          addOnQuantity: normalizedAddOnQuantity,
          addOns: addOns,
          specialInstructions: specialInstructions,
        ),
      );
    }

    _saveCart();
    notifyListeners();

    // Sync to server after adding item
    CartSyncService.instance.syncToServer();
  }

  void removeItem(String dishId) {
    _items.removeWhere((item) => item.dish.id == dishId);
    _saveCart();
    notifyListeners();

    // Sync to server after removing item
    CartSyncService.instance.syncToServer();
  }

  void removeCartItem(CartItem target) {
    _items.removeWhere((item) => identical(item, target));
    _saveCart();
    notifyListeners();
    CartSyncService.instance.syncToServer();
  }

  void updateQuantity(String dishId, int quantity) {
    if (quantity <= 0) {
      removeItem(dishId);
      return;
    }

    final existingIndex = _items.indexWhere((item) => item.dish.id == dishId);
    if (existingIndex >= 0) {
      _items[existingIndex].quantity = quantity;
      _saveCart();
      notifyListeners();

      // Sync to server after updating quantity
      CartSyncService.instance.syncToServer();
    }
  }

  void updateCartItemQuantity(CartItem target, int quantity) {
    if (quantity <= 0) {
      removeCartItem(target);
      return;
    }
    final existingIndex = _items.indexWhere((item) => identical(item, target));
    if (existingIndex >= 0) {
      _items[existingIndex].quantity = quantity;
      _saveCart();
      notifyListeners();
      CartSyncService.instance.syncToServer();
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
    _items[existingIndex].selectedSauce = selectedSauce;
    _items[existingIndex].addOnQuantity =
        selectedSauce?.trim().isNotEmpty == true ? addOnQuantity : 1;
    _items[existingIndex].addOns = addOns;
    _items[existingIndex].specialInstructions = specialInstructions;
    _saveCart();
    notifyListeners();
    CartSyncService.instance.syncToServer();
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
      final parsed = CartSyncService.parseTrayLineItem(raw);
      if (parsed == null) continue;
      final existingIndex = _items.indexWhere(
        (item) =>
            item.dish.id == parsed.dish.id &&
            _sameCustomizations(
              item,
              parsed.selectedSauce,
              parsed.addOnQuantity,
              parsed.addOns,
              parsed.specialInstructions,
            ),
      );
      if (existingIndex >= 0) {
        _items[existingIndex].quantity += parsed.quantity;
      } else {
        _items.add(parsed);
      }
    }
    _saveCart();
    notifyListeners();
  }

  Future<void> _saveCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = jsonEncode(_items.map((item) => item.toJson()).toList());
      await prefs.setString('cart', cartJson);
    } catch (e) {
      debugPrint('Error saving cart: $e');
    }
  }

  Future<void> _loadCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = prefs.getString('cart');

      if (cartJson != null) {
        final List<dynamic> decoded = jsonDecode(cartJson);
        _items = decoded.map((item) => CartItem.fromJson(item)).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading cart: $e');
    }
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('customer_token');
    if (token != null && token.isNotEmpty) {
      ApiClient.instance.setCustomerBearer(token);
      await CartSyncService.instance.syncFromServer();
    } else {
      await _loadCart();
    }
  }
}
