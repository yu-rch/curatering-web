import 'api_client.dart';

/// Custom allergen labels saved in DB (from menu "Other" entries and manager edits).
class AllergenPresetsStore {
  AllergenPresetsStore._();
  static final AllergenPresetsStore instance = AllergenPresetsStore._();

  List<String> _custom = const [];
  bool _loaded = false;

  List<String> get customPresets => List.unmodifiable(_custom);

  Future<List<String>> load({bool force = false}) async {
    if (_loaded && !force) return _custom;
    try {
      final decoded = await ApiClient.instance.getJson('/api/menu/allergen-presets');
      final raw = decoded['presets'];
      if (raw is List) {
        _custom = raw.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
      }
      _loaded = true;
    } catch (_) {
      _custom = const [];
    }
    return _custom;
  }
}
