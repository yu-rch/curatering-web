import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Customer-saved inspiration photos (e.g. from homepage latest event collage).
class CustomerDesignBoardStore extends ChangeNotifier {
  CustomerDesignBoardStore._();
  static final CustomerDesignBoardStore instance = CustomerDesignBoardStore._();

  static const _prefsKey = 'customer_design_board_v1';

  final List<String> photoBase64 = <String>[];

  bool _loaded = false;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final list = jsonDecode(raw);
      if (list is List) {
        photoBase64
          ..clear()
          ..addAll(list.map((e) => e.toString()).where((s) => s.isNotEmpty));
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> addPhotos(Iterable<String> base64Images) async {
    await ensureLoaded();
    for (final img in base64Images) {
      final trimmed = img.trim();
      if (trimmed.isEmpty) continue;
      if (!photoBase64.contains(trimmed)) {
        photoBase64.add(trimmed);
      }
    }
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(photoBase64));
  }
}
