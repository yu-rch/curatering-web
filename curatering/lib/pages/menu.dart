import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../widgets/app_scaffold.dart';
import '../models/menu_dish.dart';
import '../services/menu_store.dart';

class Menu extends StatefulWidget {
  const Menu({super.key});

  @override
  State<Menu> createState() => _MenuState();
}

class _MenuState extends State<Menu> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _paxController = TextEditingController();

  String? _pendingImageBase64;

  List<MenuDish> get _filteredDishes {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return MenuStore.instance.activeDishes;
    return MenuStore.instance.activeDishes
        .where((dish) => dish.name.toLowerCase().contains(query))
        .toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _priceController.dispose();
    _paxController.dispose();
    super.dispose();
  }

  Future<String?> _pickImageBase64() async {
    final xFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (xFile == null) return null;
    final bytes = await xFile.readAsBytes();
    return base64Encode(bytes);
  }

  List<String> _parsePaxOptions(String raw) {
    return raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Future<void> _openAddDishDialog() async {
    _nameController.text = '';
    _priceController.text = '';
    _paxController.text = '1 pax,10 pax,10-15 pax,15-25 pax,25-30 pax';
    _pendingImageBase64 = null;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add New Dish'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          final b64 = await _pickImageBase64();
                          if (b64 == null) return;
                          setDialogState(() => _pendingImageBase64 = b64);
                        },
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: const Text('Choose photo'),
                      ),
                      if (_pendingImageBase64 != null) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            base64Decode(_pendingImageBase64!),
                            height: 120,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ],
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Dish name'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _priceController,
                        decoration: const InputDecoration(labelText: 'Price (e.g. 100.00)'),
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _paxController,
                        decoration: const InputDecoration(
                          labelText: 'PAX options (comma separated)',
                          hintText: '1 pax, 10 pax, 10-15 pax, ...',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('CANCEL'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name = _nameController.text.trim();
                    final price = _priceController.text.trim();
                    final paxOptions = _parsePaxOptions(_paxController.text);
                    if (name.isEmpty || price.isEmpty || paxOptions.isEmpty) {
                      return;
                    }
                    MenuStore.instance.addDish(
                      name: name,
                      price: price,
                      paxOptions: paxOptions,
                      imageBase64: _pendingImageBase64,
                    );
                    Navigator.of(context).pop();
                  },
                  child: const Text('ADD'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openEditDishDialog(MenuDish dish) async {
    _nameController.text = dish.name;
    _priceController.text = dish.price;
    _paxController.text = dish.paxOptions.join(', ');
    _pendingImageBase64 = dish.imageBase64;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Edit ${dish.name}'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          final b64 = await _pickImageBase64();
                          if (b64 == null) return;
                          setDialogState(() => _pendingImageBase64 = b64);
                        },
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: const Text('Change photo'),
                      ),
                      if (_pendingImageBase64 != null) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            base64Decode(_pendingImageBase64!),
                            height: 120,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ],
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Dish name'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _priceController,
                        decoration: const InputDecoration(labelText: 'Price (e.g. 100.00)'),
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _paxController,
                        decoration: const InputDecoration(
                          labelText: 'PAX options (comma separated)',
                          hintText: '1 pax, 10 pax, 10-15 pax, ...',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('CANCEL'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name = _nameController.text.trim();
                    final price = _priceController.text.trim();
                    final paxOptions = _parsePaxOptions(_paxController.text);
                    if (name.isEmpty || price.isEmpty || paxOptions.isEmpty) {
                      return;
                    }
                    MenuStore.instance.updateDish(
                      id: dish.id,
                      name: name,
                      price: price,
                      paxOptions: paxOptions,
                      imageBase64: _pendingImageBase64,
                    );
                    Navigator.of(context).pop();
                  },
                  child: const Text('SAVE'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmArchiveDish(MenuDish dish) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Archive ${dish.name}?'),
          content: const Text('This dish will be hidden from the active menu.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () {
                MenuStore.instance.archiveDish(
                  dish.id,
                  archived: true,
                );
                Navigator.of(context).pop();
              },
              child: const Text('ARCHIVE'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDishCard(MenuDish dish) {
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
                  clipBehavior: Clip.antiAlias,
                  child: dish.imageBase64 != null && dish.imageBase64!.isNotEmpty
                      ? Image.memory(
                          base64Decode(dish.imageBase64!),
                          fit: BoxFit.cover,
                        )
                      : const Icon(Icons.fastfood, size: 32, color: Colors.grey),
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
                        '₱${dish.price}',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _openEditDishDialog(dish),
                  icon: const Icon(Icons.edit, size: 20),
                ),
                IconButton(
                  onPressed: () => _confirmArchiveDish(dish),
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
                    color: option == '1 pax'
                        ? Colors.green.shade100
                        : Colors.grey.shade100,
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
    return AnimatedBuilder(
      animation: MenuStore.instance,
      builder: (context, _) {
        final filtered = _filteredDishes;
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
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
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
                    Expanded(child: SizedBox()),
                    ElevatedButton.icon(
                      onPressed: _openAddDishDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('ADD NEW DISH'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1DB954),
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'ALL DISHES',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.arrow_drop_down),
                      const Spacer(),
                      Text(
                        '${filtered.length} items',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
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
                    children: filtered.map(_buildDishCard).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
