import 'api_client.dart';

class MealTypesStore {
  MealTypesStore._();
  static final MealTypesStore instance = MealTypesStore._();

  List<String> _types = const [];
  bool _loaded = false;

  List<String> get types => List.unmodifiable(_types);

  Future<List<String>> load({bool force = false}) async {
    if (_loaded && !force) return _types;
    try {
      final decoded = await ApiClient.instance.getJson('/api/menu/meal-types');
      final raw = decoded['mealTypes'];
      if (raw is List) {
        _types = raw.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
      }
      _loaded = true;
    } catch (_) {
      _types = const [
        'Appetizer',
        'Main Course',
        'Dessert',
        'Beverage',
        'Salad',
        'Soup',
      ];
    }
    return _types;
  }
}
