import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import '../models/menu_dish.dart';
import '../services/menu_store.dart';
import '../services/cart_store.dart';
import '../widgets/antd_message.dart';
import 'cart_page.dart';

class RestaurantOrderingPage extends StatefulWidget {
  const RestaurantOrderingPage({super.key});

  @override
  State<RestaurantOrderingPage> createState() => _RestaurantOrderingPageState();
}

class _RestaurantOrderingPageState extends State<RestaurantOrderingPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    unawaited(CartStore.instance.init());
    CartStore.instance.addListener(_onCartChanged);
  }

  @override
  void dispose() {
    CartStore.instance.removeListener(_onCartChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onCartChanged() {
    if (mounted) setState(() {});
  }

  List<MenuDish> get _filteredDishes {
    final query = _searchController.text.toLowerCase();
    final dishes =
        MenuStore.instance.activeDishes
            .where((d) => d.category == 'restaurant')
            .toList();

    if (query.isEmpty) return dishes;

    return dishes.where((d) => d.name.toLowerCase().contains(query)).toList();
  }

  void _addToCart(MenuDish dish) {
    if (!dish.available) {
      showAntdMessage(
        context,
        '${dish.name} is currently not available',
        type: AntdMessageType.error,
        duration: const Duration(seconds: 2),
      );
      return;
    }
    CartStore.instance.addItem(dish);
    showAntdMessage(
      context,
      '${dish.name} added to tray',
      duration: const Duration(seconds: 2),
    );
  }

  void _navigateToCart() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const CartPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Restaurant Menu'),
        backgroundColor: const Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_bag_outlined),
                onPressed: _navigateToCart,
              ),
              if (CartStore.instance.itemCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      '${CartStore.instance.itemCount}',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search dishes...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(child: _buildRestaurantTab()),
        ],
      ),
    );
  }

  Widget _buildRestaurantTab() {
    final restaurantDishes = _filteredDishes;
    // Group dishes by type
    Map<String, List<MenuDish>> dishesByType = {};
    for (var dish in restaurantDishes) {
      final mt = dish.effectiveMealType;
      final type = mt.isEmpty ? 'OTHERS' : mt;
      if (!dishesByType.containsKey(type)) {
        dishesByType[type] = [];
      }
      dishesByType[type]!.add(dish);
    }

    return dishesByType.isEmpty
        ? Center(
          child: Text(
            'No restaurant dishes',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        )
        : ListView(
          children:
              dishesByType.entries.map((entry) {
                final type = entry.key;
                final dishes = entry.value;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: Text(
                        type,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    ...dishes.map(
                      (dish) => Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 4.0,
                        ),
                        child: _buildDishCard(dish),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              }).toList(),
        );
  }

  Widget _buildDishCard(MenuDish dish) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            if (dish.imageBase64 != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  base64Decode(dish.imageBase64!),
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.restaurant,
                  size: 40,
                  color: Colors.grey,
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dish.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₱${dish.price}',
                    style: TextStyle(
                      color: Colors.amber.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (dish.sauces.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Sauces: ${dish.sauces.join(", ")}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: dish.available ? () => _addToCart(dish) : null,
              icon: Icon(dish.available ? Icons.add : Icons.block, size: 18),
              label: Text(dish.available ? 'Add' : 'N/A'),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    dish.available
                        ? const Color(0xFF1E1E1E)
                        : Colors.grey.shade500,
                foregroundColor: Colors.white,
                minimumSize: const Size(70, 36),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
