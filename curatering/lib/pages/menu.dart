import 'package:flutter/material.dart';
import '../widgets/app_scaffold.dart';

class DishCard {
  final String name;
  final String price;
  final List<String> paxOptions;

  const DishCard({
    required this.name,
    required this.price,
    required this.paxOptions,
  });
}

class Menu extends StatefulWidget {
  const Menu({super.key});

  @override
  State<Menu> createState() => _MenuState();
}

class _MenuState extends State<Menu> {
  final TextEditingController _searchController = TextEditingController();

  static const _dishes = [
    DishCard(
      name: 'Bistek',
      price: '₱100.00',
      paxOptions: ['1 pax', '10 pax', '10-15 pax', '15-25 pax', '25-30 pax'],
    ),
    DishCard(
      name: 'Sinigang',
      price: '₱120.00',
      paxOptions: ['1 pax', '10 pax', '10-15 pax', '15-25 pax', '25-30 pax'],
    ),
    DishCard(
      name: 'Lechon Kawali',
      price: '₱250.00',
      paxOptions: ['1 pax', '10 pax', '10-15 pax', '15-25 pax', '25-30 pax'],
    ),
    DishCard(
      name: 'Kare-Kare',
      price: '₱200.00',
      paxOptions: ['1 pax', '10 pax', '10-15 pax', '15-25 pax', '25-30 pax'],
    ),
  ];

  List<DishCard> get _filteredDishes {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _dishes;
    return _dishes.where((dish) => dish.name.toLowerCase().contains(query)).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildDishCard(DishCard dish) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.grey.shade200,
                  ),
                  child: const Icon(Icons.fastfood, size: 32, color: Colors.grey),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dish.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dish.price,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.edit, size: 20),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.delete_outline, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: dish.paxOptions.map((option) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: option == '1 pax' ? Colors.green.shade100 : Colors.grey.shade100,
                  ),
                  child: Text(option),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      showSearch: true,
      searchController: _searchController,
      onSearchChanged: (_) => setState(() {}),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Menu',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'MENU',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(child: SizedBox()),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                    color: Colors.white,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.filter_list, size: 18),
                      SizedBox(width: 8),
                      Text('Filter'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  const Text('ALL DISHES', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 10),
                  const Icon(Icons.arrow_drop_down),
                  const Spacer(),
                  Text('${_filteredDishes.length} items',
                      style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.count(
                crossAxisCount: 3,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.35,
                children: _filteredDishes.map(_buildDishCard).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
