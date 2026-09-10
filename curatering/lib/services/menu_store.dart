import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/menu_dish.dart';
import '../utils/api_cache.dart';
import 'api_client.dart';

/// Used by both `Menu` and `Manage Events` pages.
class MenuStore extends ChangeNotifier {
  MenuStore._internal() {
    _items = [];
  }

  static final MenuStore instance = MenuStore._internal();

  late List<MenuDish> _items;
  bool _isLoading = false;
  bool _imagesLoaded = false;
  String? _error;

  bool get isLoading => _isLoading;
  bool get imagesLoaded => _imagesLoaded;
  String? get error => _error;

  Future<void> loadDishes() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final decoded = await ApiClient.instance.getJson(
        '/api/menu/dishes',
        cacheExpiry: const Duration(minutes: 5),
      );
      final raw = decoded['dishes'];

      if (raw is! List) {
        _items = [];
      } else {
        _items = raw.map((json) => _dishFromJson(json)).toList();
      }

      _imagesLoaded = false;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading menu dishes: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load dishes with images (slower, use when menu grids need photos).
  Future<void> loadDishesWithImages({bool silent = false}) async {
    try {
      if (!silent || _items.isEmpty) {
        _isLoading = true;
        _error = null;
        notifyListeners();
      }

      final decoded = await ApiClient.instance.getJson(
        '/api/menu/dishes/with-images',
        cacheExpiry: const Duration(minutes: 5),
      );
      final raw = decoded['dishes'];

      if (raw is! List) {
        _items = [];
      } else {
        _items = raw.map((json) => _dishFromJson(json)).toList();
      }

      _imagesLoaded = true;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading menu dishes with images: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Ensures dish photos are present (for restaurant/catering grids).
  Future<void> ensureImagesLoaded() async {
    final missingPhotos = _items.any(
      (d) => d.imageBase64 == null || d.imageBase64!.trim().isEmpty,
    );
    if (_imagesLoaded && _items.isNotEmpty && !missingPhotos) return;
    if (_items.isEmpty) {
      await loadDishesWithImages();
      return;
    }
    // Already have names/prices — refresh photos without a full-page spinner.
    await loadDishesWithImages(silent: true);
  }

  // Load single dish with image
  Future<MenuDish?> loadDishWithImage(String dishId) async {
    try {
      final decoded = await ApiClient.instance.getJson(
        '/api/menu/dishes/$dishId/with-image',
      );
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

  MenuDish _dishFromJson(dynamic raw) {
    final json = Map<String, dynamic>.from(raw as Map);
    final rawPrice = json['price'];
    final normalizedPrice =
        rawPrice == null
            ? '0.00'
            : rawPrice is String
            ? rawPrice
            : rawPrice.toString();
    double? parseDoubleField(Object? value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value.trim());
      return null;
    }

    bool parseBoolField(Object? value, {bool fallback = false}) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      final text = value?.toString().trim().toLowerCase();
      if (text == null || text.isEmpty) return fallback;
      return text == 'true' || text == '1' || text == 'yes' || text == 't';
    }

    List<String> parseStringList(Object? value) {
      if (value is List) {
        return value
            .map((item) => item.toString())
            .where((item) => item.trim().isNotEmpty)
            .toList();
      }
      if (value is String && value.trim().isNotEmpty) {
        final trimmed = value.trim();
        try {
          if (trimmed.startsWith('[')) {
            final decoded = jsonDecode(trimmed);
            if (decoded is List) return parseStringList(decoded);
          }
        } catch (_) {
          // Fall through to comma parsing below.
        }
        return trimmed
            .split(',')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList();
      }
      return const [];
    }

    final sauces = parseStringList(json['sauces']);
    final archivedAtRaw = json['archived_at'];
    DateTime? archivedAt;
    if (archivedAtRaw != null) {
      archivedAt = DateTime.tryParse(archivedAtRaw.toString());
    }

    return MenuDish(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      price: normalizedPrice,
      additionalChargeAmount:
          parseDoubleField(json['menu_dishes_additional_charge_amount']) ??
          parseDoubleField(json['additionalChargeAmount']) ??
          parseDoubleField(json['additional_charge_amount']) ??
          0,
      category: (json['category'] ?? 'catering').toString(),
      paxOptions: parseStringList(
        json['pax_options'] ?? json['paxOptions'],
      ),
      sauces: sauces,
      supportsAddOns:
          parseBoolField(json['supportsAddOns'] ?? json['supports_addons']) ||
          sauces.isNotEmpty,
      ingredients: parseStringList(json['ingredients']),
      imageBase64: () {
        final v = json['image_base64'] ?? json['imageBase64'];
        if (v == null) return null;
        final s = v.toString();
        return s.isEmpty ? null : s;
      }(),
      archived: parseBoolField(json['archived']),
      available: parseBoolField(json['available'], fallback: true),
      archivedAt: archivedAt,
      type: (json['type'] ?? '').toString(),
      mealType:
          (json['meal_type'] ?? json['mealType'] ?? json['type'] ?? '')
              .toString(),
      setMenus: parseStringList(json['set_menus'] ?? json['setMenus']),
      publicDescription:
          (json['public_description'] ?? json['publicDescription'] ?? '')
              .toString(),
      allergens: (json['allergens'] ?? '').toString(),
    );
  }

  void _invalidateMenuCaches() {
    ApiCache().invalidate('/api/menu/dishes');
  }

  /// Admin/archive: active + archived dishes (includes images).
  Future<void> loadAllDishes({bool silent = false}) async {
    try {
      if (!silent) {
        _isLoading = true;
        _error = null;
        notifyListeners();
      }
      _invalidateMenuCaches();
      final decoded = await ApiClient.instance.getJson(
        '/api/menu/dishes/all',
        useCache: false,
      );
      final raw = decoded['dishes'];
      if (raw is! List) {
        _items = [];
      } else {
        _items = raw.map(_dishFromJson).toList();
      }
      _imagesLoaded = true;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading all menu dishes: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Find a dish by ID from the local cache (returns null if not found).
  MenuDish? findDishById(String id) {
    final idx = _items.indexWhere((d) => d.id == id);
    return idx >= 0 ? _items[idx] : null;
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
    double additionalChargeAmount = 0,
    required List<String> paxOptions,
    String? imageBase64,
    String category = 'catering',
    List<String> sauces = const [],
    bool supportsAddOns = false,
    List<String> ingredients = const [],
    String type = '',
    String mealType = '',
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
          'menuDishesAdditionalChargeAmount': additionalChargeAmount,
          'additionalChargeAmount': additionalChargeAmount,
          'additional_charge': additionalChargeAmount,
          'category': category,
          'paxOptions': paxOptions,
          'sauces': sauces,
          'supportsAddOns': supportsAddOns,
          'ingredients': ingredients,
          'imageBase64': imageBase64,
          'type': type,
          'mealType': mealType,
          'available': available,
          'publicDescription': publicDescription.trim(),
          'allergens': allergens.trim(),
        },
      );

      _invalidateMenuCaches();
      final dishRaw = decoded['dish'];
      if (dishRaw is! Map) {
        throw StateError('Server did not return the created dish');
      }
      final newDish = _dishFromJson(dishRaw);
      _items = [..._items.where((d) => d.id != newDish.id), newDish];
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
    double? additionalChargeAmount,
    required List<String> paxOptions,
    String? imageBase64,
    String? category,
    List<String>? sauces,
    bool? supportsAddOns,
    List<String>? ingredients,
    String? type,
    String? mealType,
    bool? available,
    String? publicDescription,
    String? allergens,
  }) async {
    try {
      final idx = _items.indexWhere((d) => d.id == id);
      final existingDish = idx >= 0 ? _items[idx] : null;
      final setMenusToKeep = idx >= 0 ? _items[idx].setMenus : <String>[];
      final resolvedAdditionalCharge =
          additionalChargeAmount ?? existingDish?.additionalChargeAmount ?? 0;

      final decoded = await ApiClient.instance.putJson(
        '/api/menu/dishes/$id',
        body: {
          'name': name.trim(),
          'price': price.trim(),
          'menuDishesAdditionalChargeAmount': resolvedAdditionalCharge,
          'additionalChargeAmount': resolvedAdditionalCharge,
          'additional_charge': resolvedAdditionalCharge,
          'category': category,
          'paxOptions': paxOptions,
          'sauces': sauces ?? [],
          'supportsAddOns':
              supportsAddOns ?? existingDish?.supportsAddOns ?? false,
          'ingredients': ingredients ?? existingDish?.ingredients ?? [],
          // Omit null so the API keeps the existing photo (list loads omit images).
          if (imageBase64 != null) 'imageBase64': imageBase64,
          'type': type ?? '',
          // Preserve existing meal type when callers omit it (e.g. partial updates).
          'mealType': mealType ?? existingDish?.mealType ?? '',
          'available': available ?? true,
          'setMenus': setMenusToKeep,
          'publicDescription': (publicDescription ?? '').trim(),
          'allergens': (allergens ?? '').trim(),
        },
      );

      _invalidateMenuCaches();
      final dishRaw = decoded['dish'];
      if (dishRaw is! Map) {
        throw StateError('Server did not return the updated dish');
      }
      final updatedDish = _dishFromJson(dishRaw);
      _items = _items.map((d) => d.id == id ? updatedDish : d).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating dish: $e');
      rethrow;
    }
  }

  Future<void> updateDishIngredients(
    String id,
    List<String> ingredients,
  ) async {
    final dish = _items.firstWhere((d) => d.id == id);
    await updateDish(
      id: id,
      name: dish.name,
      price: dish.price,
      additionalChargeAmount: dish.additionalChargeAmount,
      paxOptions: dish.paxOptions,
      category: dish.category,
      sauces: dish.sauces,
      supportsAddOns: dish.supportsAddOns,
      ingredients: ingredients,
      imageBase64: dish.imageBase64,
      type: dish.type,
      mealType: dish.mealType,
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

      _invalidateMenuCaches();
      final dishRaw = decoded['dish'];
      if (dishRaw is! Map) {
        throw StateError('Server did not return the archived dish');
      }
      final updatedDish = _dishFromJson(dishRaw);
      _items = _items.map((d) => d.id == id ? updatedDish : d).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error archiving dish: $e');
      rethrow;
    }
  }

  /// Permanently delete an archived dish.
  Future<void> deleteDishForever(String id) async {
    try {
      await ApiClient.instance.delete('/api/menu/dishes/$id');
      _invalidateMenuCaches();
      _items = _items.where((d) => d.id != id).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting dish: $e');
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
        final updatedSets = List<String>.from(
          decoded['setMenus'] as List<dynamic>,
        );
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
        final updatedSets = List<String>.from(
          decoded['setMenus'] as List<dynamic>,
        );
        _items[dishIndex] = _items[dishIndex].copyWith(setMenus: updatedSets);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error removing dish from set: $e');
      rethrow;
    }
  }
}
