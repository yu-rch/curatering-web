import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/menu_dish.dart';
import 'api_client.dart';
import 'cart_sync_service.dart';

class CartItem {
  final MenuDish dish;
  int quantity;
  String? selectedSauce;

  CartItem({required this.dish, this.quantity = 1, this.selectedSauce});

  Map<String, dynamic> toJson() => {
    'dish': {
      'id': dish.id,
      'name': dish.name,
      'price': dish.price,
      'category': dish.category,
      'type': dish.type,
      'mealType': dish.mealType,
    },
    'quantity': quantity,
    'selectedSauce': selectedSauce,
  };

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      dish: MenuDish(
        id: json['dish']['id'],
        name: json['dish']['name'],
        price: json['dish']['price'],
        category: json['dish']['category'] ?? 'restaurant',
        paxOptions: [],
        type: json['dish']['type'] ?? '',
        mealType:
            (json['dish']['mealType'] ?? json['dish']['meal_type'] ?? '')
                .toString(),
      ),
      quantity: json['quantity'] ?? 1,
      selectedSauce: json['selectedSauce'],
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

  double get totalAmount => _items.fold(0.0, (sum, item) {
    try {
      return sum + (double.parse(item.dish.price) * item.quantity);
    } catch (e) {
      return sum;
    }
  });

  void addItem(MenuDish dish, {String? selectedSauce}) {
    final existingIndex = _items.indexWhere(
      (item) => item.dish.id == dish.id && item.selectedSauce == selectedSauce,
    );

    if (existingIndex >= 0) {
      _items[existingIndex].quantity++;
    } else {
      _items.add(CartItem(dish: dish, selectedSauce: selectedSauce));
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
            item.selectedSauce == parsed.selectedSauce,
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
