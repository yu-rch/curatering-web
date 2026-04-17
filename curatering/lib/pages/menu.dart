import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../widgets/app_scaffold.dart';
import '../models/menu_dish.dart';
import '../services/menu_store.dart';
import '../services/set_menu_store.dart';

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
  final TextEditingController _newPaxController = TextEditingController();
  final TextEditingController _newSauceController = TextEditingController();
  final TextEditingController _setMenuNameController = TextEditingController();
  final TextEditingController _typeController = TextEditingController();

  String? _pendingImageBase64;
  String? _editingImageBase64;
  String _editingType = ''; // For restaurant dish type grouping
  Map<String, String> _editingPaxPrices = {};
  Map<String, TextEditingController> _paxPriceControllers = {};
  int _activeTabIndex = 0;
  List<String> _editingPaxOptions = ['1 pax'];
  List<String> _editingSauces = [];
  MenuDish? _editingDish;
  String _editingCategory = 'catering';
  List<String> _selectedSetDishIds = [];
  String? _selectedSetMenuId;
  String? _dishCategoryFilter; // 'all', 'catering', 'restaurant'
  bool _isModifyingSet = false; // Track if we're in edit mode for set menu

  List<MenuDish> get _filteredDishes {
    final query = _searchController.text.trim().toLowerCase();
    var dishes = MenuStore.instance.activeDishes;
    
    // Apply category filter
    if (_dishCategoryFilter != null && _dishCategoryFilter != 'all') {
      dishes = dishes.where((d) => d.category == _dishCategoryFilter).toList();
    }
    
    // Apply search filter
    if (query.isEmpty) return dishes;
    return dishes.where((dish) => dish.name.toLowerCase().contains(query)).toList();
  }

  @override
  void initState() {
    super.initState();
    MenuStore.instance.addListener(_onMenuChanged);
    SetMenuStore.instance.addListener(_onSetMenusChanged);
  }

  void _onMenuChanged() {
    if (mounted) setState(() {});
  }

  void _onSetMenusChanged() {
    if (mounted) setState(() {});
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
    _typeController.dispose();
    for (var controller in _paxPriceControllers.values) {
      controller.dispose();
    }
    MenuStore.instance.removeListener(_onMenuChanged);
    SetMenuStore.instance.removeListener(_onSetMenusChanged);
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
    _editingType = '';
    _typeController.clear();
    _nameController.clear();
    _priceController.clear();
    _paxController.clear();
    _editingPaxOptions = category == 'catering' 
        ? ['10-20 pax', '25-40 pax', '50-70 pax', '80-100 pax', '100+ pax']
        : ['1 pax'];
    _editingPaxPrices = {for (var pax in _editingPaxOptions) pax: ''};
    _paxPriceControllers.clear();
    for (var pax in _editingPaxOptions) {
      _paxPriceControllers[pax] = TextEditingController(text: '');
    }
    _editingSauces = [];
    _newPaxController.clear();
    _newSauceController.clear();
  }

  void _startEditingDish(MenuDish dish) {
    _editingDish = dish;
    _editingCategory = dish.category;
    _editingImageBase64 = dish.imageBase64;
    _editingType = dish.type;
    _typeController.text = dish.type;
    _nameController.text = dish.name;
    _priceController.text = dish.price;
    _paxController.text = '';
    _editingPaxOptions = dish.paxOptions.toList();
    _editingPaxPrices = Map.fromEntries(
      dish.paxOptions.map((pax) => MapEntry(pax, dish.price)),
    );
    _paxPriceControllers.clear();
    for (var pax in _editingPaxOptions) {
      _paxPriceControllers[pax] = TextEditingController(text: dish.price);
    }
    _editingSauces = dish.sauces.toList();
    _newPaxController.clear();
    _newSauceController.clear();
  }

  void _addPaxOption() {
    final value = _newPaxController.text.trim();
    if (value.isEmpty || _editingPaxOptions.contains(value)) return;
    setState(() {
      _editingPaxOptions.add(value);
      _editingPaxPrices[value] = '';
      _paxPriceControllers[value] = TextEditingController(text: '');
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

  Future<void> _saveSetMenu() async {
    final name = _setMenuNameController.text.trim();
    if (name.isEmpty || _selectedSetDishIds.isEmpty) return;
    
    try {
      if (_selectedSetMenuId == null) {
        // Create new set menu
        await SetMenuStore.instance.addSetMenu(
          name: name,
          dishIds: _selectedSetDishIds.toList(),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Set menu created successfully')),
        );
      } else {
        // Update existing set menu
        await SetMenuStore.instance.updateSetMenu(
          id: _selectedSetMenuId!,
          name: name,
          dishIds: _selectedSetDishIds.toList(),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Set menu updated successfully')),
        );
      }
      _setMenuNameController.clear();
      _selectedSetDishIds.clear();
      _selectedSetMenuId = null;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
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
            child: SetMenuStore.instance.activeSetMenus.isEmpty
                ? const Center(child: Text('No existing set menus yet.'))
                : ListView(
                    children: SetMenuStore.instance.activeSetMenus.map((setMenu) {
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
                        const SizedBox(height: 12),
                        TextField(
                          controller: _typeController,
                          decoration: const InputDecoration(
                            labelText: 'Type (e.g., RICE MEALS, PASTA)',
                            helperText: 'Used to group dishes in restaurant menu',
                          ),
                          onChanged: (value) => dialogSetState(() => _editingType = value),
                        ),
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
                  onPressed: () async {
                    final name = _nameController.text.trim();
                    final price = _priceController.text.trim();
                    if (name.isEmpty ||
                        price.isEmpty ||
                        _editingPaxOptions.isEmpty) {
                      return;
                    }
                    try {
                      if (dish == null) {
                        await MenuStore.instance.addDish(
                          name: name,
                          price: price,
                          paxOptions: _editingPaxOptions,
                          imageBase64: _editingImageBase64,
                          category: category,
                          sauces: category == 'restaurant'
                              ? _editingSauces
                              : const [],
                          type: _editingType,
                        );
                      } else {
                        await MenuStore.instance.updateDish(
                          id: dish.id,
                          name: name,
                          price: price,
                          paxOptions: _editingPaxOptions,
                          imageBase64: _editingImageBase64,
                          category: category,
                          sauces: category == 'restaurant'
                              ? _editingSauces
                              : const [],
                          type: _editingType,
                        );
                      }
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    }
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
                    controller: _paxPriceControllers[option] ?? TextEditingController(text: ''),
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
              onPressed: () async {
                try {
                  await MenuStore.instance.archiveDish(dish.id, archived: true);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              child: const Text('ARCHIVE'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showIngredientsDialog(MenuDish dish) async {
    final ingredients = <String>[...dish.ingredients];
    final controller = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Ingredients for ${dish.name}'),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'These ingredients will be automatically added to the checklist when this dish is ordered.',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller,
                            decoration: InputDecoration(
                              hintText: 'Add ingredient (e.g., Beef, Rice)',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            final value = controller.text.trim();
                            if (value.isNotEmpty && !ingredients.contains(value)) {
                              setState(() {
                                ingredients.add(value);
                                controller.clear();
                              });
                            }
                          },
                          child: const Icon(Icons.add),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (ingredients.isEmpty)
                      Text(
                        'No ingredients added yet.',
                        style: TextStyle(color: Colors.grey.shade500),
                      )
                    else
                      Container(
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: SingleChildScrollView(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: ingredients.map((ingredient) {
                              return Chip(
                                label: Text(ingredient),
                                deleteIcon: const Icon(Icons.close, size: 18),
                                onDeleted: () {
                                  setState(() {
                                    ingredients.remove(ingredient);
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('CANCEL'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await MenuStore.instance.updateDishIngredients(dish.id, ingredients);
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('SAVE'),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
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
                  onPressed: () => _showIngredientsDialog(dish),
                  icon: const Icon(Icons.list_alt, size: 20),
                  tooltip: 'Ingredients',
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
        Expanded(
          child: cateringDishes.isEmpty
              ? const Center(child: Text('No catering dishes available'))
              : _buildMenuGrid(cateringDishes),
        ),
      ],
    );
  }

  Widget _buildRestaurantTab() {
    final restaurantDishes = _filteredDishes.where((d) => d.category == 'restaurant').toList();
    // Group dishes by type
    Map<String, List<MenuDish>> dishesByType = {};
    for (var dish in restaurantDishes) {
      final type = dish.type.isEmpty ? 'OTHERS' : dish.type;
      if (!dishesByType.containsKey(type)) {
        dishesByType[type] = [];
      }
      dishesByType[type]!.add(dish);
    }
    
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
        Expanded(
          child: dishesByType.isEmpty
              ? Center(child: Text('No restaurant dishes', style: TextStyle(color: Colors.grey.shade600)))
              : ListView(
                  children: dishesByType.entries.map((entry) {
                    final type = entry.key;
                    final dishes = entry.value;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: Text(
                            type,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                        ...dishes.map((dish) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                          child: _buildDishCard(dish),
                        )),
                        const SizedBox(height: 16),
                      ],
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildSetMenuTab(List<MenuDish> cateringDishes) {
    final setMenus = SetMenuStore.instance.activeSetMenus;
    final selectedSetName = _selectedSetMenuId != null
        ? setMenus.firstWhere((s) => s.id == _selectedSetMenuId, orElse: () => setMenus.first).name
        : null;

    return Column(
      children: [
        // Header with search and add dish button
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search dish',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.filter_list, size: 18),
                    const SizedBox(width: 4),
                    Text('Filter', style: TextStyle(color: Colors.grey.shade700)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => _openDishDialog(category: 'catering'),
                icon: const Icon(Icons.add),
                label: const Text('ADD NEW DISH'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Three-column layout
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left column: NEW MENU
              Expanded(
                flex: 1,
                child: Container(
                  margin: const EdgeInsets.only(left: 16, right: 8, bottom: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // NEW MENU header
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.yellow.shade100,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8),
                            topRight: Radius.circular(8),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.add_circle_outline, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'NEW MENU',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      // Menu Set Name input
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const Text('Menu Set Name'),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _setMenuNameController,
                                decoration: InputDecoration(
                                  hintText: 'Set Name',
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Dishes in new menu
                      Expanded(
                        child: _selectedSetDishIds.isEmpty
                            ? Center(
                                child: Text(
                                  'add dishes here for your new menu',
                                  style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(12),
                                itemCount: _selectedSetDishIds.length,
                                itemBuilder: (context, index) {
                                  final dishId = _selectedSetDishIds[index];
                                  final dish = cateringDishes.firstWhere(
                                    (d) => d.id == dishId,
                                    orElse: () => MenuDish(
                                      id: dishId,
                                      name: 'Unknown',
                                      price: '0',
                                      paxOptions: const [],
                                    ),
                                  );
                                  return _buildSetMenuDishCard(
                                    dish,
                                    isInSet: true,
                                    onRemove: _isModifyingSet ? () => _removeDishFromSet(dish.id) : null,
                                  );
                                },
                              ),
                      ),
                      // Save button
                      if (_selectedSetDishIds.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _saveSetMenu,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                              child: Text(_selectedSetMenuId == null ? 'Create Set Menu' : 'Update Set Menu'),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // Middle column: Choose from existing set menus
              Expanded(
                flex: 1,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          'Choose from existing set menus',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      // Set menu selector row
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    isExpanded: true,
                                    value: _selectedSetMenuId,
                                    hint: const Text('Select a set menu'),
                                    items: setMenus.map((setMenu) {
                                      return DropdownMenuItem(
                                        value: setMenu.id,
                                        child: Text(setMenu.name),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      if (value != null) {
                                        final setMenu = setMenus.firstWhere((s) => s.id == value);
                                        _viewSetMenu(setMenu);
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _selectedSetMenuId != null
                                  ? () => _loadSetMenuForEditing(_selectedSetMenuId!)
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('modify this set'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Dishes in selected set
                      Expanded(
                        child: selectedSetName == null
                            ? Center(
                                child: Text(
                                  'Select a set menu to view dishes',
                                  style: TextStyle(color: Colors.grey.shade400),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(12),
                                itemCount: MenuStore.instance.getDishesBySet(selectedSetName).length,
                                itemBuilder: (context, index) {
                                  final dishes = MenuStore.instance.getDishesBySet(selectedSetName);
                                  final dish = dishes[index];
                                  final isInCurrentSelection = _selectedSetDishIds.contains(dish.id);
                                  return _buildSetMenuDishCard(
                                    dish,
                                    isInSet: isInCurrentSelection,
                                    onAddToMenu: () => _addDishToCurrentSet(dish.id),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              // Right column: Select from all dishes
              Expanded(
                flex: 1,
                child: Container(
                  margin: const EdgeInsets.only(left: 8, right: 16, bottom: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          'select from all dishes',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      // All catering dishes
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: cateringDishes.length,
                          itemBuilder: (context, index) {
                            final dish = cateringDishes[index];
                            final isInCurrentSelection = _selectedSetDishIds.contains(dish.id);
                            return _buildSetMenuDishCard(
                              dish,
                              isInSet: isInCurrentSelection,
                              onAddToMenu: () => _addDishToCurrentSet(dish.id),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _addDishToCurrentSet(String dishId) {
    setState(() {
      if (!_selectedSetDishIds.contains(dishId)) {
        _selectedSetDishIds.add(dishId);
      }
    });
  }

  void _loadSetMenuForEditing(String setMenuId) {
    final setMenus = SetMenuStore.instance.activeSetMenus;
    final setMenu = setMenus.firstWhere((s) => s.id == setMenuId);
    _applySetMenu(setMenu);
    setState(() {
      _isModifyingSet = true;
    });
  }

  void _removeDishFromSet(String dishId) {
    setState(() {
      _selectedSetDishIds.remove(dishId);
    });
  }

  void _viewSetMenu(SetMenu setMenu) {
    // Only view the set menu without entering edit mode
    setState(() {
      _selectedSetMenuId = setMenu.id;
      _isModifyingSet = false;
      // Clear the editing state when just viewing
      _selectedSetDishIds = [];
      _setMenuNameController.clear();
    });
  }

  Widget _buildSetMenuDishCard(MenuDish dish, {required bool isInSet, VoidCallback? onAddToMenu, VoidCallback? onRemove}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Dish image
                Container(
                  width: 80,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: Colors.grey.shade200,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: dish.imageBase64 != null && dish.imageBase64!.isNotEmpty
                      ? Image.memory(
                          base64Decode(dish.imageBase64!),
                          fit: BoxFit.cover,
                        )
                      : const Icon(Icons.fastfood, color: Colors.grey),
                ),
                const SizedBox(width: 12),
                // Dish info
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
                        'PHP${dish.price}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Action buttons
                if (onAddToMenu != null && !isInSet)
                  ElevatedButton(
                    onPressed: onAddToMenu,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    child: const Text('add to menu'),
                  ),
                if (onRemove != null)
                  IconButton(
                    onPressed: onRemove,
                    icon: const Icon(Icons.close, color: Colors.red),
                    tooltip: 'Remove from set',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  )
                else if (isInSet)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(Icons.check, color: Colors.white, size: 16),
                  ),
              ],
            ),
            // Pax options
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: dish.paxOptions.map((pax) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    pax,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade700,
                    ),
                  ),
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
        // Show loading state
        if (MenuStore.instance.isLoading) {
          return AppScaffold(
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading menu...'),
                ],
              ),
            ),
          );
        }

        // Show error state
        if (MenuStore.instance.error != null) {
          return AppScaffold(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${MenuStore.instance.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => MenuStore.instance.loadDishes(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

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
      },
    );
  }
}