import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/menu_dish.dart';
import '../services/menu_store.dart';
import '../utils/image_cache.dart';

/// Normalizes restaurant order line items from mixed API shapes.
Map<String, dynamic> normalizeOrderLineItem(dynamic raw) {
  if (raw is String && raw.trim().isNotEmpty) {
    final dish = _dishByName(raw.trim());
    return {
      'name': dish?.name ?? raw.trim(),
      'quantity': 1,
      'price': dish?.price ?? '0.00',
      'description': dish?.publicDescription ?? '',
      'imageBase64': dish?.imageBase64 ?? '',
      'sauce': '',
    };
  }
  if (raw is! Map) {
    return {'name': 'Unknown item', 'quantity': 1, 'price': '0.00'};
  }
  final map = Map<String, dynamic>.from(raw);
  final dish = map['dish'];
  Map<String, dynamic>? dishMap;
  if (dish is Map) dishMap = Map<String, dynamic>.from(dish);

  String pickId() {
    for (final key in [
      'dish_id',
      'dishId',
      'menu_dish_id',
      'menuDishId',
      'id',
    ]) {
      final v = map[key]?.toString().trim() ?? '';
      if (v.isNotEmpty) return v;
    }
    return dishMap?['id']?.toString().trim() ?? '';
  }

  String pickName() {
    for (final key in [
      'name',
      'dishName',
      'dish_name',
      'title',
      'item_name',
      'menu_item_name',
    ]) {
      final v = map[key]?.toString().trim() ?? '';
      if (v.isNotEmpty && v.toLowerCase() != 'unknown item') return v;
    }
    final nested = dishMap?['name']?.toString().trim() ?? '';
    if (nested.isNotEmpty) return nested;
    return '';
  }

  String pickImage() {
    for (final key in [
      'imageBase64',
      'image_base64',
      'image',
      'photo',
      'photoBase64',
    ]) {
      final v = map[key]?.toString().trim() ?? '';
      if (v.isNotEmpty) return v;
    }
    return dishMap?['image_base64']?.toString().trim() ??
        dishMap?['imageBase64']?.toString().trim() ??
        '';
  }

  final id = pickId();
  MenuDish? cached;
  if (id.isNotEmpty) cached = MenuStore.instance.findDishById(id);
  cached ??= _dishByName(pickName());

  var name = pickName();
  if (name.isEmpty) name = cached?.name ?? 'Unknown item';
  var image = pickImage();
  if (image.isEmpty) image = cached?.imageBase64 ?? '';

  return {
    'name': name,
    'quantity': map['quantity'] ?? map['qty'] ?? 1,
    'price':
        map['price'] ??
        map['unit_price'] ??
        map['unitPrice'] ??
        cached?.price ??
        '0.00',
    'description':
        map['description'] ??
        map['notes'] ??
        map['sauce'] ??
        cached?.publicDescription ??
        '',
    'imageBase64': image,
    'sauce': map['sauce'] ?? map['addOn'] ?? map['dip'] ?? '',
    'dish_id': id,
  };
}

MenuDish? _dishByName(String name) {
  if (name.trim().isEmpty) return null;
  final needle = name.trim().toLowerCase();
  for (final d in MenuStore.instance.allDishes) {
    if (d.name.trim().toLowerCase() == needle) return d;
  }
  return null;
}

List<Map<String, dynamic>> orderLineItemsFrom(Map<String, dynamic> order) {
  dynamic raw =
      order['items'] ??
      order['order_items'] ??
      order['orderItems'] ??
      order['line_items'] ??
      order['tray_items'] ??
      order['trayItems'] ??
      order['dishes'];
  if (raw is String && raw.trim().isNotEmpty) {
    try {
      raw = jsonDecode(raw);
    } catch (_) {
      return [normalizeOrderLineItem(raw)];
    }
  }
  if (raw is! List) return const [];
  return raw.map(normalizeOrderLineItem).toList();
}

Widget orderItemThumb(String? imageBase64, {double size = 48}) {
  final img = imageBase64?.trim() ?? '';
  if (img.isEmpty) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.restaurant, color: Colors.grey.shade600),
    );
  }
  return ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: SizedBox(
      width: size,
      height: size,
      child: CachedBase64Image(
        base64String: img,
        fit: BoxFit.cover,
        placeholder: Container(
          color: Colors.grey.shade200,
          child: Icon(Icons.restaurant, color: Colors.grey.shade600),
        ),
      ),
    ),
  );
}
