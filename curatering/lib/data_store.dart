// simple shared data repository for demo purposes
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A lightweight data model used in sample pages.
class InventoryItem {
  final String sku;
  final String category;
  final String name;
  final String description;
  final String uom;
  final int unitPrice;
  final int inStock;
  final int ordered;
  final int delivered;
  final String imageUrl;

  InventoryItem({
    required this.sku,
    required this.category,
    required this.name,
    required this.description,
    required this.uom,
    required this.unitPrice,
    required this.inStock,
    required this.ordered,
    required this.delivered,
    required this.imageUrl,
  });
}

class ArchivedItem {
  final InventoryItem item;
  final DateTime archiveDate;

  ArchivedItem(this.item, this.archiveDate);
}

class DataStore {
  /// active inventory items (read/write from inventory page)
  static final List<InventoryItem> items = [
    // keep the same sample entry so startup looks similar
    InventoryItem(
      sku: '000001',
      category: 'Canned good',
      name: 'Century Tuna - Flakes in Oil',
      description: '155g',
      uom: 'can',
      unitPrice: 37,
      inStock: 27,
      ordered: 20,
      delivered: 20,
      imageUrl: 'https://via.placeholder.com/80',
    ),
  ];

  /// archived items with a timestamp
  static final List<ArchivedItem> archivedItems = [];

  /// simple theme control — light is the staff default
  static final ValueNotifier<bool> isDarkMode = ValueNotifier(false);
  static const _darkModeKey = 'curatering_theme_is_dark';

  static Future<void> loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // New key so a leftover "dark" value from before light-as-default
      // is not restored. Dark mode is opt-in from Settings.
      isDarkMode.value = prefs.getBool(_darkModeKey) ?? false;
    } catch (_) {}
  }

  static Future<void> setDarkMode(bool value) async {
    isDarkMode.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_darkModeKey, value);
    } catch (_) {}
  }
}
