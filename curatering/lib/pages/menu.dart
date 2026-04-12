import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../widgets/app_scaffold.dart';
import '../models/menu_dish.dart';
import '../services/menu_store.dart';

class Menu extends StatefulWidget {
  const Menu({super.key});

  @override
  State<Menu> createState() => _MenuState();
}

class SetMenu {
  final String id;
  final String name;
  final List<String> dishIds;

  SetMenu({required this.id, required this.name, required this.dishIds});
}

class _MenuState extends State<Menu> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _paxController = TextEditingController();
  final TextEditingController _newPaxController = TextEditingController();
  final TextEditingController _newSauceController = TextEditingController();
  final TextEditingController _setMenuNameController = TextEditingController();

  String? _pendingImageBase64;
  String? _editingImageBase64;
  Map<String, String> _editingPaxPrices = {};
  int _activeTabIndex = 0;
  List<String> _editingPaxOptions = ['1 pax'];
  List<String> _editingSauces = [];
  MenuDish? _editingDish;
  String _editingCategory = 'catering';
  List<String> _selectedSetDishIds = [];
  List<SetMenu> _setMenus = [];
  String? _selectedSetMenuId;

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
    _newPaxController.dispose();
    _newSauceController.dispose();
    _setMenuNameController.dispose();
    super.dispose();
  }

  Future<String?> _pickImageBase64() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return null;
    final bytes = await picked.readAsBytes();
    final base64 = base64Encode(bytes);
    setState(() {
      _pendingImageBase64 = base64;
    });
    return base64;
  }

  
  void _resetEditorState({String category = 'catering'}) {
    _editingDish = null;
    _editingCategory = category;
    _editingImageBase64 = null;
    _nameController.clear();
    _priceController.clear();
    _paxController.clear();
    _editingPaxOptions = ['1 pax'];
    _editingPaxPrices = {'1 pax': ''};
    _editingSauces = [];
    _newPaxController.clear();
    _newSauceController.clear();
  }

  void _startEditingDish(MenuDish dish) {
    _editingDish = dish;
    _editingCategory = dish.category;
    _editingImageBase64 = dish.imageBase64;
    _nameController.text = dish.name;
    _priceController.text = dish.price;
    _paxController.text = '';
    _editingPaxOptions = dish.paxOptions.toList();
    _editingPaxPrices = Map.fromEntries(
      dish.paxOptions.map((pax) => MapEntry(pax, dish.price)),
    );
    _editingSauces = dish.sauces.toList();
    _newPaxController.clear();
    _newSauceController.clear();
  }

  void _addPaxOption() {
    final value = _newPaxController.text.trim();
    if (value.isEmpty || _editingPaxOptions.contains(value)) return;
    setState(() {
      _editingPaxOptions.add(value);
      _editingPaxPrices[value] = ''; // Initialize with empty price
      _newPaxController.clear();
    });
  }

  void _addSauceOption() {
    final value = _newSauceController.text.trim();
    if (value.isEmpty || _editingSauces.contains(value)) return;
    setState(() {
      _editingSauces.add(value);
      _newSauceController.clear();
    });
  }

  void _toggleSetDish(String dishId) {
    setState(() {
      if (_selectedSetDishIds.contains(dishId)) {
        _selectedSetDishIds.remove(dishId);
      } else {
        _selectedSetDishIds.add(dishId);
      }
    });
  }

  void _applySetMenu(SetMenu setMenu) {
    final dishes = MenuStore.instance.activeDishes;
    setState(() {
      _selectedSetMenuId = setMenu.id;
      _setMenuNameController.text = setMenu.name;
      _selectedSetDishIds = setMenu.dishIds.where((id) {
        return dishes.any(
          (dish) => dish.id == id && dish.category == 'catering',
        );
      }).toList();
    });
  }

  void _saveSetMenu() {
    final name = _setMenuNameController.text.trim();
    if (name.isEmpty || _selectedSetDishIds.isEmpty) return;
    if (_selectedSetMenuId == null) {
      final id = DateTime.now().microsecondsSinceEpoch.toString();
      setState(() {
        _setMenus.add(
          SetMenu(id: id, name: name, dishIds: _selectedSetDishIds.toList()),
        );
        _selectedSetMenuId = id;
      });
    } else {
      setState(() {
        _setMenus = _setMenus.map((setMenu) {
          if (setMenu.id == _selectedSetMenuId) {
            return SetMenu(
              id: setMenu.id,
              name: name,
              dishIds: _selectedSetDishIds.toList(),
            );
          }
          return setMenu;
        }).toList();
      });
    }
  }

  
  Future<void> _openSetMenuSelector() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Existing Set Menus'),
          content: SizedBox(
            width: 420,
            height: 320,
            child: _setMenus.isEmpty
                ? const Center(child: Text('No existing set menus yet.'))
                : ListView(
                    children: _setMenus.map((setMenu) {
                      return ListTile(
                        title: Text(setMenu.name),
                        subtitle: Text('${setMenu.dishIds.length} dishes'),
                        trailing: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _applySetMenu(setMenu);
                          },
                          child: const Text('Use'),
                        ),
                      );
                    }).toList(),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openDishDialog({
    MenuDish? dish,
    required String category,
  }) async {
    if (dish == null) {
      _resetEditorState(category: category);
    } else {
      _startEditingDish(dish);
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            Widget buildPhotoArea() {
              if (_editingImageBase64 == null) {
                return const SizedBox.shrink();
              }
              return Column(
                children: [
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      base64Decode(_editingImageBase64!),
                      height: 140,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              );
            }

            return AlertDialog(
              title: Text(dish == null ? 'Add Dish' : 'Edit ${dish.name}'),
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
                          dialogSetState(() => _editingImageBase64 = b64);
                        },
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: Text(
                          dish == null ? 'Upload photo' : 'Change photo',
                        ),
                      ),
                      buildPhotoArea(),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Dish name',
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildPaxEditor(dialogSetState),
                      if (category == 'restaurant') ...[
                        const SizedBox(height: 16),
                        _buildSauceEditor(dialogSetState),
                      ],
                      const SizedBox(height: 16),
                      TextField(
                        controller: _priceController,
                        decoration: const InputDecoration(labelText: 'Price'),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
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
                    if (name.isEmpty ||
                        price.isEmpty ||
                        _editingPaxOptions.isEmpty) {
                      return;
                    }
                    if (dish == null) {
                      MenuStore.instance.addDish(
                        name: name,
                        price: price,
                        paxOptions: _editingPaxOptions,
                        imageBase64: _editingImageBase64,
                        category: category,
                        sauces: category == 'restaurant'
                            ? _editingSauces
                            : const [],
                      );
                    } else {
                      MenuStore.instance.updateDish(
                        id: dish.id,
                        name: name,
                        price: price,
                        paxOptions: _editingPaxOptions,
                        imageBase64: _editingImageBase64,
                        category: category,
                        sauces: category == 'restaurant'
                            ? _editingSauces
                            : const [],
                      );
                    }
                    Navigator.of(context).pop();
                  },
                  child: Text(dish == null ? 'ADD' : 'SAVE'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPaxEditor(void Function(VoidCallback fn) dialogSetState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PAX OPTIONS & PRICES',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        // Individual pax options with prices
        ..._editingPaxOptions.map((option) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                // Pax option chip
                InputChip(
                  label: Text(option),
                  onDeleted: () {
                    dialogSetState(() {
                      _editingPaxOptions.remove(option);
                      _editingPaxPrices.remove(option);
                    });
                  },
                ),
                const SizedBox(width: 12),
                // Price input for this pax
                Expanded(
                  flex: 2,
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: 'Price for $option',
                      border: const OutlineInputBorder(),
                      prefixText: '\$',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    controller: TextEditingController(
                      text: _editingPaxPrices[option] ?? '',
                    ),
                    onChanged: (value) {
                      dialogSetState(() {
                        _editingPaxPrices[option] = value;
                      });
                    },
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _newPaxController,
                decoration: const InputDecoration(
                  labelText: 'Add PAX option',
                  hintText: 'e.g. 20-30 pax',
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                dialogSetState(_addPaxOption);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSauceEditor(void Function(VoidCallback fn) dialogSetState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('SAUCES', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _editingSauces.map((sauce) {
            return InputChip(
              label: Text(sauce),
              onDeleted: () {
                dialogSetState(() {
                  _editingSauces.remove(sauce);
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _newSauceController,
                decoration: const InputDecoration(
                  labelText: 'Add sauce',
                  hintText: 'e.g. gravy',
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                dialogSetState(_addSauceOption);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ],
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
                MenuStore.instance.archiveDish(dish.id, archived: true);
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
                  child:
                      dish.imageBase64 != null && dish.imageBase64!.isNotEmpty
                      ? Image.memory(
                          base64Decode(dish.imageBase64!),
                          fit: BoxFit.cover,
                        )
                      : const Icon(
                          Icons.fastfood,
                          size: 32,
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
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'PHP${dish.price}',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () =>
                      _openDishDialog(dish: dish, category: dish.category),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: option == '1 pax'
                        ? Color(0xFFFFC107)
                        : Colors.grey.shade100,
                  ),
                  child: Text(option),
                );
              }).toList(),
            ),
            if (dish.sauces.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Sauces',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: dish.sauces.map((sauce) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Color(0xFFFFC107)
                    ),
                    child: Text(sauce),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String title, int index) {
    final selected = _activeTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTabIndex = index),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF1DB954) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? const Color(0xFF1DB954) : Colors.grey.shade300,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: selected ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuGrid(List<MenuDish> dishes) {
    if (dishes.isEmpty) {
      return Center(
        child: Text(
          'No dishes available.',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 3,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.35,
      children: dishes.map(_buildDishCard).toList(),
    );
  }

  Widget _buildSetMenuTab(List<MenuDish> cateringDishes) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SELECTED DISHES',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (_selectedSetDishIds.isEmpty)
                    Expanded(
                      child: Center(
                        child: Text(
                          'Select dishes from the right to build a new set.',
                          style: TextStyle(color: Colors.grey.shade600),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView(
                        children: _selectedSetDishIds.map((dishId) {
                          final dish = cateringDishes.firstWhere(
                            (d) => d.id == dishId,
                            orElse: () => MenuDish(
                              id: dishId,
                              name: 'Unknown dish',
                              price: '0',
                              paxOptions: const [],
                            ),
                          );
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 2,
                              horizontal: 0,
                            ),
                            title: Text(dish.name),
                            subtitle: Text('PHP${dish.price}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () => setState(() {
                                _selectedSetDishIds.remove(dishId);
                              }),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          flex: 3,
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SET MENU CONTROLS',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _setMenuNameController,
                    decoration: const InputDecoration(
                      labelText: 'Set menu name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: _saveSetMenu,
                        child: const Text('Save Set'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _openSetMenuSelector,
                        child: const Text('Load Set'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'AVAILABLE CATERING DISHES',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView(
                      children: cateringDishes.map((dish) {
                        final isSelected = _selectedSetDishIds.contains(dish.id);
                        return CheckboxListTile(
                          title: Text(dish.name),
                          subtitle: Text('PHP${dish.price}'),
                          value: isSelected,
                          onChanged: (value) {
                            _toggleSetDish(dish.id);
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCateringTab() {
    final cateringDishes = _filteredDishes.where((d) => d.category == 'catering').toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search catering dishes...',
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
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => _openDishDialog(category: 'catering'),
                icon: const Icon(Icons.add),
                label: const Text('Add Dish'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(child: _buildMenuGrid(cateringDishes)),
      ],
    );
  }

  Widget _buildRestaurantTab() {
    final restaurantDishes = _filteredDishes.where((d) => d.category == 'restaurant').toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search restaurant dishes...',
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
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => _openDishDialog(category: 'restaurant'),
                icon: const Icon(Icons.add),
                label: const Text('Add Dish'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(child: _buildMenuGrid(restaurantDishes)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: Column(
        children: [
          // Tab buttons
          Row(
            children: [
              _buildTabButton('CATERING', 0),
              const SizedBox(width: 8),
              _buildTabButton('RESTAURANT', 1),
              const SizedBox(width: 8),
              _buildTabButton('SET MENUS', 2),
            ],
          ),
          const SizedBox(height: 16),
          // Content based on active tab
          Expanded(
            child: _activeTabIndex == 0
                ? _buildCateringTab()
                : _activeTabIndex == 1
                    ? _buildRestaurantTab()
                    : _buildSetMenuTab(_filteredDishes.where((d) => d.category == 'catering').toList()),
          ),
        ],
      ),
    );
  }
}
