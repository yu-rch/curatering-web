import 'dart:convert';
import 'dart:io';

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

  String? _pendingImageBase64;
  Map<String, String> _editingPaxPrices = {};

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

  List<String> _parsePaxOptions(String raw) {
    return raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  int _activeTabIndex = 0;
  final TextEditingController _newPaxController = TextEditingController();
  final TextEditingController _newSauceController = TextEditingController();
  final TextEditingController _setMenuNameController = TextEditingController();
  List<String> _editingPaxOptions = ['1 pax'];
  List<String> _editingSauces = [];
  String? _editingImageBase64;
  MenuDish? _editingDish;
  String _editingCategory = 'catering';
  List<String> _selectedSetDishIds = [];
  List<SetMenu> _setMenus = [];
  String? _selectedSetMenuId;

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

  Future<void> _importMenuFromCSV() async {
    try {
      final String csvData = await rootBundle.loadString('assets/sads.csv');
      final List<String> lines = csvData.split('\n');
      
      bool isCateringSection = false;
      bool isRestaurantSection = false;
      String currentSet = '';
      
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;
        
        // Check for section headers
        if (line.contains('CATERING AND EVENTS MENU')) {
          isCateringSection = true;
          isRestaurantSection = false;
          continue;
        }
        if (line.contains('RESTAURANT MENU')) {
          isRestaurantSection = true;
          isCateringSection = false;
          continue;
        }
        
        // Process catering sets
        if (isCateringSection && line.startsWith('SET ')) {
          currentSet = line.split(',')[0].trim();
          continue;
        }
        
        if (isCateringSection && line.startsWith(',') && !line.startsWith(',,,')) {
          final parts = line.split(',');
          if (parts.length >= 2) {
            final dishName = parts[1].trim();
            if (dishName.isNotEmpty && !dishName.contains('INGREDIENTS')) {
              final ingredients = parts.length > 2 ? parts[2].trim() : '';
              
              // Add dish to catering menu
              MenuStore.instance.addDish(
                name: '$currentSet - $dishName',
                price: '0', // Price to be set individually
                paxOptions: ['1 pax', '10-20 pax', '21-30 pax', '31-40 pax'],
                imageBase64: null,
                category: 'catering',
                sauces: [],
              );
            }
          }
        }
        
        // Process restaurant menu
        if (isRestaurantSection && line.startsWith(',,') && !line.contains('SIZE')) {
          final parts = line.split(',');
          if (parts.length >= 4) {
            final dishName = parts[2].trim();
            final size = parts[3].trim();
            final price = parts.length > 4 ? parts[4].trim() : '0';
            final sauces = parts.length > 5 ? parts[5].trim() : '';
            
            if (dishName.isNotEmpty && size.isNotEmpty && price.isNotEmpty) {
              final List<String> sauceList = sauces.isNotEmpty 
                  ? sauces.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
                  : [];
              
              // Add dish to restaurant menu
              MenuStore.instance.addDish(
                name: dishName,
                price: price,
                paxOptions: [size],
                imageBase64: null,
                category: 'restaurant',
                sauces: sauceList,
              );
            }
          }
        }
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Menu data imported successfully from sads.csv'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error importing menu data: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
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
                        '₱${dish.price}',
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
                        ? Colors.green.shade100
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
                      color: Colors.orange.shade50,
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
                            subtitle: Text('₱${dish.price}'),
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
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _saveSetMenu,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1DB954),
                          ),
                          child: const Text('CREATE SET'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _openSetMenuSelector,
                          icon: const Icon(Icons.folder_open, size: 16),
                          label: const Text('LOAD'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade200,
                            foregroundColor: Colors.black,
                          ),
                        ),
                      ),
                    ],
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
                    'AVAILABLE DISHES',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 0.8,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: MenuStore.instance.activeDishes.length,
                      itemBuilder: (context, index) {
                        final dish = MenuStore.instance.activeDishes[index];
                        final isSelected = _selectedSetDishIds.contains(dish.id);
                        return GestureDetector(
                          onTap: () => _toggleSetDish(dish.id),
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: isSelected ? Colors.blue : Colors.grey.shade300,
                                width: isSelected ? 2 : 1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              color: isSelected ? Colors.blue.withOpacity(0.1) : null,
                            ),
                            child: Column(
                              children: [
                                Expanded(
                                  child: dish.imageBase64 != null && dish.imageBase64!.isNotEmpty
                                      ? Image.memory(
                                          base64Decode(dish.imageBase64!),
                                          fit: BoxFit.cover,
                                        )
                                      : const Icon(Icons.fastfood, size: 40),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Text(
                                    dish.name,
                                    style: const TextStyle(fontSize: 12),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
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

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      showSearch: true,
      searchController: _searchController,
      onSearchChanged: (query) => setState(() {}),
      child: Column(
        children: [
          // Tab buttons and import button
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                _buildTabButton('Catering Menu', 0),
                _buildTabButton('Restaurant Menu', 1),
                _buildTabButton('New Set Menu', 2),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _importMenuFromCSV,
                  icon: const Icon(Icons.upload_file, size: 16),
                  label: const Text('IMPORT CSV'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          // Tab content
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: [
                _buildMenuGrid(_filteredDishes.where((d) => d.category == 'catering').toList()),
                _buildMenuGrid(_filteredDishes.where((d) => d.category == 'restaurant').toList()),
                _buildSetMenuTab(_filteredDishes.where((d) => d.category == 'catering').toList()),
              ][_activeTabIndex],
            ),
          ),
        ],
      ),
    );
  }
}