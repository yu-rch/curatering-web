import 'package:flutter/foundation.dart';

import '../models/menu_dish.dart';
import 'api_client.dart';

/// Used by both `Menu` and `Manage Events` pages.
class MenuStore extends ChangeNotifier {
  MenuStore._internal() {
    _items = [];
    // Defer loading to avoid notifyListeners during widget build
    Future.microtask(() => loadDishes());
  }

  static final MenuStore instance = MenuStore._internal();

  late List<MenuDish> _items;
  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadDishes() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final decoded = await ApiClient.instance.getJson('/api/menu/dishes');
      final raw = decoded['dishes'];

      if (raw is! List) {
        _items = [];
      } else {
        _items = raw.map((json) => _dishFromJson(json)).toList();
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading menu dishes: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load dishes with images (slower, use when needed)
  Future<void> loadDishesWithImages() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final decoded = await ApiClient.instance.getJson('/api/menu/dishes/with-images');
      final raw = decoded['dishes'];

      if (raw is! List) {
        _items = [];
      } else {
        _items = raw.map((json) => _dishFromJson(json)).toList();
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading menu dishes with images: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load single dish with image
  Future<MenuDish?> loadDishWithImage(String dishId) async {
    try {
      final decoded = await ApiClient.instance.getJson('/api/menu/dishes/$dishId/with-image');
      final dishData = decoded['dish'];
      
      if (dishData is! Map<String, dynamic>) {
        return null;
      }
      
      final dish = _dishFromJson(dishData);
      
      // Update the dish in the items list
      final index = _items.indexWhere((item) => item.id == dishId);
      if (index != -1) {
        _items[index] = dish;
        notifyListeners();
      }
      
      return dish;
    } catch (e) {
      debugPrint('Error loading dish with image: $e');
      return null;
    }
  }

  MenuDish _dishFromJson(Map<String, dynamic> json) {
    final rawPrice = json['price'];
    final normalizedPrice = rawPrice == null
        ? '0.00'
        : rawPrice is String
        ? rawPrice
        : rawPrice.toString();

    return MenuDish(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      price: normalizedPrice,
      category: json['category'] as String? ?? 'catering',
      paxOptions: (json['pax_options'] as List<dynamic>?)?.cast<String>() ?? [],
      sauces: (json['sauces'] as List<dynamic>?)?.cast<String>() ?? [],
      ingredients: (json['ingredients'] as List<dynamic>?)?.cast<String>() ?? [],
      imageBase64: json['image_base64'] as String?,
      archived: json['archived'] as bool? ?? false,
      available: json['available'] as bool? ?? true,
      archivedAt: json['archived_at'] != null
          ? DateTime.tryParse(json['archived_at'] as String)
          : null,
      type: json['type'] as String? ?? '',
      setMenus: (json['set_menus'] as List<dynamic>?)?.cast<String>() ?? [],
      publicDescription: json['public_description'] as String? ?? '',
      allergens: json['allergens'] as String? ?? '',
    );
  }

  /// Get dishes that belong to a specific set menu
  List<MenuDish> getDishesBySet(String setName) {
    return _items.where((d) => d.setMenus.contains(setName)).toList();
  }

  List<MenuDish> get allDishes => List.unmodifiable(_items);
  List<MenuDish> get activeDishes => _items.where((d) => !d.archived).toList();
  List<MenuDish> get archivedDishes => _items.where((d) => d.archived).toList();

  Future<void> addDish({
    required String name,
    required String price,
    required List<String> paxOptions,
    String? imageBase64,
    String category = 'catering',
    List<String> sauces = const [],
    List<String> ingredients = const [],
    String type = '',
    bool available = true,
    String publicDescription = '',
    String allergens = '',
  }) async {
    try {
      final decoded = await ApiClient.instance.postJson(
        '/api/menu/dishes',
        body: {
          'name': name.trim(),
          'price': price.trim(),
          'category': category,
          'paxOptions': paxOptions,
          'sauces': sauces,
          'ingredients': ingredients,
          'imageBase64': imageBase64,
          'type': type,
          'available': available,
          'publicDescription': publicDescription.trim(),
          'allergens': allergens.trim(),
        },
      );
      
      final newDish = _dishFromJson(decoded['dish'] as Map<String, dynamic>);
      _items = [..._items, newDish];
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding dish: $e');
      rethrow;
    }
  }

  Future<void> updateDish({
    required String id,
    required String name,
    required String price,
    required List<String> paxOptions,
    String? imageBase64,
    String? category,
    List<String>? sauces,
    List<String>? ingredients,
    String? type,
    bool? available,
    String? publicDescription,
    String? allergens,
  }) async {
    try {
      final idx = _items.indexWhere((d) => d.id == id);
      final setMenusToKeep = idx >= 0 ? _items[idx].setMenus : <String>[];

      final decoded = await ApiClient.instance.putJson(
        '/api/menu/dishes/$id',
        body: {
          'name': name.trim(),
          'price': price.trim(),
          'category': category,
          'paxOptions': paxOptions,
          'sauces': sauces ?? [],
          'ingredients': ingredients ?? [],
          'imageBase64': imageBase64,
          'type': type ?? '',
          'available': available ?? true,
          'setMenus': setMenusToKeep,
          'publicDescription': (publicDescription ?? '').trim(),
          'allergens': (allergens ?? '').trim(),
        },
      );
      
      final updatedDish = _dishFromJson(decoded['dish'] as Map<String, dynamic>);
      _items = _items.map((d) => d.id == id ? updatedDish : d).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating dish: $e');
      rethrow;
    }
  }

  Future<void> updateDishIngredients(String id, List<String> ingredients) async {
    final dish = _items.firstWhere((d) => d.id == id);
    await updateDish(
      id: id,
      name: dish.name,
      price: dish.price,
      paxOptions: dish.paxOptions,
      category: dish.category,
      sauces: dish.sauces,
      ingredients: ingredients,
      imageBase64: dish.imageBase64,
      type: dish.type,
      available: dish.available,
      publicDescription: dish.publicDescription,
      allergens: dish.allergens,
    );
  }

  Future<void> archiveDish(String id, {required bool archived}) async {
    try {
      final decoded = await ApiClient.instance.postJson(
        '/api/menu/dishes/$id/archive',
        body: {'archived': archived},
      );
      
      final updatedDish = _dishFromJson(decoded['dish'] as Map<String, dynamic>);
      _items = _items.map((d) => d.id == id ? updatedDish : d).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error archiving dish: $e');
      rethrow;
    }
  }

  /// Add a dish to a set menu
  Future<void> addDishToSet(String dishId, String setName) async {
    try {
      final decoded = await ApiClient.instance.postJson(
        '/api/menu/dishes/$dishId/add-to-set',
        body: {'setName': setName},
      );
      
      // Update local dish
      final dishIndex = _items.indexWhere((d) => d.id == dishId);
      if (dishIndex != -1) {
        final updatedSets = List<String>.from(decoded['setMenus'] as List<dynamic>);
        _items[dishIndex] = _items[dishIndex].copyWith(setMenus: updatedSets);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error adding dish to set: $e');
      rethrow;
    }
  }

  /// Remove a dish from a set menu
  Future<void> removeDishFromSet(String dishId, String setName) async {
    try {
      final decoded = await ApiClient.instance.postJson(
        '/api/menu/dishes/$dishId/remove-from-set',
        body: {'setName': setName},
      );
      
      // Update local dish
      final dishIndex = _items.indexWhere((d) => d.id == dishId);
      if (dishIndex != -1) {
        final updatedSets = List<String>.from(decoded['setMenus'] as List<dynamic>);
        _items[dishIndex] = _items[dishIndex].copyWith(setMenus: updatedSets);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error removing dish from set: $e');
      rethrow;
    }
  }
}

