import 'package:flutter/foundation.dart';

import '../models/menu_dish.dart';

/// In-memory menu catalog used by both `Menu` and `Manage Events`.
///
/// Right now the backend doesn't have a dedicated menu table yet, so we keep
/// this as a shared frontend store for dev/testing and to remove duplicated
/// hardcoded dish lists across pages.
class MenuStore extends ChangeNotifier {
  MenuStore._internal() {
    // Seed with the prototype dishes that were previously hardcoded in pages.
    _items = <MenuDish>[
      const MenuDish(
        id: 'dish_bistek',
        name: 'Bistek',
        price: '100.00',
        paxOptions: ['1 pax', '10 pax', '10-15 pax', '15-25 pax', '25-30 pax'],
      ),
      const MenuDish(
        id: 'dish_sinigang',
        name: 'Sinigang',
        price: '120.00',
        paxOptions: ['1 pax', '10 pax', '10-15 pax', '15-25 pax', '25-30 pax'],
      ),
      const MenuDish(
        id: 'dish_lechon_kawali',
        name: 'Lechon Kawali',
        price: '250.00',
        paxOptions: ['1 pax', '10 pax', '10-15 pax', '15-25 pax', '25-30 pax'],
      ),
      const MenuDish(
        id: 'dish_kare_kare',
        name: 'Kare-Kare',
        price: '200.00',
        paxOptions: ['1 pax', '10 pax', '10-15 pax', '15-25 pax', '25-30 pax'],
      ),
    ];
  }

  static final MenuStore instance = MenuStore._internal();

  late List<MenuDish> _items;

  List<MenuDish> get allDishes => List.unmodifiable(_items);
  List<MenuDish> get activeDishes => _items.where((d) => !d.archived).toList();
  List<MenuDish> get archivedDishes => _items.where((d) => d.archived).toList();

  void addDish({
    required String name,
    required String price,
    required List<String> paxOptions,
    String? imageBase64,
  }) {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    _items = [
      ..._items,
      MenuDish(
        id: id,
        name: name.trim(),
        price: price.trim(),
        paxOptions: paxOptions,
        imageBase64: imageBase64,
      ),
    ];
    notifyListeners();
  }

  void updateDish({
    required String id,
    required String name,
    required String price,
    required List<String> paxOptions,
    String? imageBase64,
  }) {
    _items = _items
        .map(
          (d) => d.id == id
              ? d.copyWith(
                  name: name.trim(),
                  price: price.trim(),
                  paxOptions: paxOptions,
                  imageBase64: imageBase64 ?? d.imageBase64,
                )
              : d,
        )
        .toList();
    notifyListeners();
  }

  void archiveDish(String id, {required bool archived}) {
    final now = DateTime.now();
    _items = _items
        .map(
          (d) => d.id == id
              ? d.copyWith(
                  archived: archived,
                  archivedAt: archived ? now : null,
                )
              : d,
        )
        .toList();
    notifyListeners();
  }
}

