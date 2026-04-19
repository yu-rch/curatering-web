import 'package:flutter/foundation.dart';
import 'api_client.dart';

class SetMenu {
  final String id;
  final String name;
  final List<String> dishIds;
  final bool archived;
  final DateTime? createdAt;

  SetMenu({
    required this.id,
    required this.name,
    required this.dishIds,
    this.archived = false,
    this.createdAt,
  });

  factory SetMenu.fromJson(Map<String, dynamic> json) {
    return SetMenu(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      dishIds: (json['dish_ids'] as List<dynamic>?)?.cast<String>() ?? [],
      archived: json['archived'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }
}

/// Set menu catalog that syncs with the backend database.
class SetMenuStore extends ChangeNotifier {
  SetMenuStore._internal() {
    _items = [];
    // Defer loading to avoid notifyListeners during widget build
    Future.microtask(() => loadSetMenus());
  }

  static final SetMenuStore instance = SetMenuStore._internal();

  late List<SetMenu> _items;
  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadSetMenus() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final decoded = await ApiClient.instance.getJson('/api/menu/set-menus');
      final raw = decoded['setMenus'];

      if (raw is! List) {
        _items = [];
      } else {
        _items = raw.map((json) => SetMenu.fromJson(json as Map<String, dynamic>)).toList();
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading set menus: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  List<SetMenu> get allSetMenus => List.unmodifiable(_items);
  List<SetMenu> get activeSetMenus => _items.where((s) => !s.archived).toList();

  Future<void> addSetMenu({
    required String name,
    required List<String> dishIds,
  }) async {
    try {
      final decoded = await ApiClient.instance.postJson(
        '/api/set-menus',
        body: {
          'name': name.trim(),
          'dishIds': dishIds,
        },
      );

      final newSetMenu = SetMenu.fromJson(decoded['setMenu'] as Map<String, dynamic>);
      _items = [..._items, newSetMenu];
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding set menu: $e');
      rethrow;
    }
  }

  Future<void> updateSetMenu({
    required String id,
    required String name,
    required List<String> dishIds,
  }) async {
    try {
      final decoded = await ApiClient.instance.putJson(
        '/api/set-menus/$id',
        body: {
          'name': name.trim(),
          'dishIds': dishIds,
        },
      );

      final updatedSetMenu = SetMenu.fromJson(decoded['setMenu'] as Map<String, dynamic>);
      _items = _items.map((s) => s.id == id ? updatedSetMenu : s).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating set menu: $e');
      rethrow;
    }
  }

  Future<void> archiveSetMenu(String id, {required bool archived}) async {
    try {
      final decoded = await ApiClient.instance.postJson(
        '/api/set-menus/$id/archive',
        body: {'archived': archived},
      );

      final updatedSetMenu = SetMenu.fromJson(decoded['setMenu'] as Map<String, dynamic>);
      _items = _items.map((s) => s.id == id ? updatedSetMenu : s).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error archiving set menu: $e');
      rethrow;
    }
  }
}
