import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../widgets/app_scaffold.dart';
import '../models/menu_dish.dart';
import '../services/menu_store.dart';
import '../services/set_menu_store.dart';
import '../utils/debouncer.dart';
import '../utils/image_cache.dart';

// Lazy loading image widget for dish images
class LazyDishImage extends StatefulWidget {
  final String dishId;
  final double? height;
  final double? width;
  final BoxFit fit;
  final Widget? placeholder;

  const LazyDishImage({
    super.key,
    required this.dishId,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
    this.placeholder,
  });

  @override
  State<LazyDishImage> createState() => _LazyDishImageState();
}

class _LazyDishImageState extends State<LazyDishImage> {
  String? _imageBase64;
  bool _isLoading = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadImageIfNeeded();
  }

  void _loadImageIfNeeded() {
    final dish = MenuStore.instance.activeDishes.firstWhere(
      (d) => d.id == widget.dishId,
      orElse:
          () => MenuDish(
            id: widget.dishId,
            name: '',
            price: '0',
            paxOptions: [],
            category: 'restaurant',
          ),
    );

    if (dish.imageBase64 != null && dish.imageBase64!.isNotEmpty) {
      setState(() {
        _imageBase64 = dish.imageBase64;
      });
    } else {
      _loadImageFromServer();
    }
  }

  Future<void> _loadImageFromServer() async {
    if (_isLoading || _hasError) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final dishWithImage = await MenuStore.instance.loadDishWithImage(
        widget.dishId,
      );
      if (dishWithImage?.imageBase64 != null &&
          dishWithImage!.imageBase64!.isNotEmpty) {
        setState(() {
          _imageBase64 = dishWithImage.imageBase64;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_imageBase64 != null && _imageBase64!.isNotEmpty) {
      return CachedBase64Image(
        base64String: _imageBase64!,
        height: widget.height,
        width: widget.width,
        fit: widget.fit,
        placeholder: widget.placeholder ?? _buildPlaceholder(),
      );
    }

    if (_hasError) {
      return widget.placeholder ?? _buildErrorPlaceholder();
    }

    return widget.placeholder ?? _buildLoadingPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      height: widget.height,
      width: widget.width,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.fastfood, size: 32, color: Colors.grey),
    );
  }

  Widget _buildLoadingPlaceholder() {
    return Container(
      height: widget.height,
      width: widget.width,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }

  Widget _buildErrorPlaceholder() {
    return Container(
      height: widget.height,
      width: widget.width,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.broken_image, size: 32, color: Colors.grey),
    );
  }
}

class Menu extends StatefulWidget {
  const Menu({super.key});

  @override
  State<Menu> createState() => _MenuState();
}

class _MenuState extends State<Menu> {
  static const List<String> _restaurantMealTypes = [
    'rice meals',
    'silog meals',
    'pasta',
    'sandwiches',
    'others',
    'drinks',
  ];

  final TextEditingController _searchController = TextEditingController();
  final _debouncer = Debouncer(delay: const Duration(milliseconds: 300));
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _paxController = TextEditingController();
  final TextEditingController _newPaxController = TextEditingController();
  final TextEditingController _newSauceController = TextEditingController();
  final TextEditingController _setMenuNameController = TextEditingController();
  final TextEditingController _typeController = TextEditingController();

  String? _editingImageBase64;
  String _editingType = ''; // For restaurant dish type grouping
  Map<String, String> _editingPaxPrices = {};
  Map<String, TextEditingController> _paxPriceControllers = {};
  int _activeTabIndex = 0;
  bool _isRestaurantGridView = true;
  List<String> _editingPaxOptions = ['1 pax'];
  List<String> _editingSauces = [];
  bool _editingAvailable = true;
  List<String> _selectedSetDishIds = [];
  String? _selectedSetMenuId;
  bool _isModifyingSet = false;
  bool _isGridView = true; // Default to grid view

  bool _matchesSearch(MenuDish dish) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return true;
    return dish.name.toLowerCase().contains(query);
  }

  String _normalizeRestaurantMealType(String raw) {
    final value = raw.trim().toLowerCase();
    if (value.isEmpty) return '';
    if (_restaurantMealTypes.contains(value)) return value;

    // Backward compatibility for older labels saved in DB.
    switch (value) {
      case 'rice meal':
        return 'rice meals';
      case 'silog meal':
        return 'silog meals';
      case 'sandwich':
        return 'sandwiches';
      case 'drink':
        return 'drinks';
      case 'other':
        return 'others';
      default:
        return 'others';
    }
  }

  @override
  void initState() {
    super.initState();
    MenuStore.instance.addListener(_onMenuChanged);
    SetMenuStore.instance.addListener(_onSetMenusChanged);
  }

  void _onMenuChanged() {
    if (mounted) {
      // Defer setState to avoid calling during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
  }

  void _onSetMenusChanged() {
    if (mounted) {
      // Defer setState to avoid calling during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _debouncer.dispose();
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
    return base64Encode(bytes);
  }

  void _resetEditorState({String category = 'catering'}) {
    _editingAvailable = true;
    _editingImageBase64 = null;
    _editingType = '';
    _typeController.clear();
    _nameController.clear();
    _priceController.clear();
    _paxController.clear();
    _editingPaxOptions =
        category == 'catering'
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
    _editingAvailable = dish.available;
    _editingImageBase64 = dish.imageBase64;
    _editingType = _normalizeRestaurantMealType(dish.type);
    _typeController.text = _editingType;
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

  void _applySetMenu(SetMenu setMenu) {
    final dishes = MenuStore.instance.activeDishes;
    setState(() {
      _selectedSetMenuId = setMenu.id;
      _setMenuNameController.text = setMenu.name;
      _selectedSetDishIds =
          setMenu.dishIds.where((id) {
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
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
                    child: CachedBase64Image(
                      base64String: _editingImageBase64,
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
                      if (category != 'catering')
                        _buildPaxEditor(dialogSetState),
                      if (category == 'catering')
                        Text(
                          'PAX options are disabled for catering dishes. Pricing is guest-count based.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      if (category == 'restaurant') ...[
                        const SizedBox(height: 16),
                        _buildSauceEditor(dialogSetState),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value:
                              _restaurantMealTypes.contains(_editingType)
                                  ? _editingType
                                  : null,
                          decoration: const InputDecoration(
                            labelText: 'Meal Type',
                            helperText: 'Select the meal type for grouping',
                          ),
                          items:
                              _restaurantMealTypes
                                  .map(
                                    (type) => DropdownMenuItem(
                                      value: type,
                                      child: Text(
                                        type
                                            .split(' ')
                                            .map(
                                              (word) =>
                                                  word.isEmpty
                                                      ? word
                                                      : '${word[0].toUpperCase()}${word.substring(1)}',
                                            )
                                            .join(' '),
                                      ),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              dialogSetState(() {
                                _editingType = _normalizeRestaurantMealType(
                                  value,
                                );
                                _typeController.text = _editingType;
                              });
                            }
                          },
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
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Available for ordering'),
                        subtitle: const Text(
                          'Unavailable dishes are visible but cannot be added to cart.',
                        ),
                        value: _editingAvailable,
                        onChanged: (value) {
                          dialogSetState(() {
                            _editingAvailable = value;
                          });
                        },
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
                          sauces:
                              category == 'restaurant'
                                  ? _editingSauces
                                  : const [],
                          type: _editingType,
                          available: _editingAvailable,
                        );
                      } else {
                        await MenuStore.instance.updateDish(
                          id: dish.id,
                          name: name,
                          price: price,
                          paxOptions: _editingPaxOptions,
                          imageBase64: _editingImageBase64,
                          category: category,
                          sauces:
                              category == 'restaurant'
                                  ? _editingSauces
                                  : const [],
                          type: _editingType,
                          available: _editingAvailable,
                        );
                      }
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('Error: $e')));
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
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    controller:
                        _paxPriceControllers[option] ??
                        TextEditingController(text: ''),
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
          children:
              _editingSauces.map((sauce) {
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

  Future<void> _toggleDishAvailability(MenuDish dish) async {
    try {
      await MenuStore.instance.updateDish(
        id: dish.id,
        name: dish.name,
        price: dish.price,
        paxOptions: dish.paxOptions,
        imageBase64: dish.imageBase64,
        category: dish.category,
        sauces: dish.sauces,
        ingredients: dish.ingredients,
        type: dish.type,
        available: !dish.available,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              dish.available
                  ? 'Dish marked as unavailable'
                  : 'Dish marked as available',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update dish: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _confirmArchiveDish(MenuDish dish) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Close button
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.black),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),
                const SizedBox(height: 8),
                // Title
                Text(
                  'ARCHIVE ${dish.name.toUpperCase()}?',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'This dish will be hidden from the active menu.',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 24),
                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          try {
                            await MenuStore.instance.archiveDish(
                              dish.id,
                              archived: true,
                            );
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
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFC024),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'ARCHIVE',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade300,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'CANCEL',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 420),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Close button
                    Align(
                      alignment: Alignment.topRight,
                      child: IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.black),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Title
                    Text(
                      'INGREDIENTS FOR ${dish.name.toUpperCase()}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'These ingredients will be automatically added to the checklist when this dish is ordered.',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller,
                            decoration: InputDecoration(
                              isDense: true,
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
                            if (value.isNotEmpty &&
                                !ingredients.contains(value)) {
                              setState(() {
                                ingredients.add(value);
                                controller.clear();
                              });
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFC024),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Icon(Icons.add, size: 20),
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
                            children:
                                ingredients.map((ingredient) {
                                  return Chip(
                                    label: Text(ingredient),
                                    deleteIcon: const Icon(
                                      Icons.close,
                                      size: 18,
                                    ),
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
                    const SizedBox(height: 24),
                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              try {
                                await MenuStore.instance.updateDishIngredients(
                                  dish.id,
                                  ingredients,
                                );
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
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFC024),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'SAVE',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.shade300,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'CANCEL',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
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
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey.shade200,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: LazyDishImage(
                    dishId: dish.id,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    placeholder: Container(
                      color: Colors.grey.shade200,
                      child: const Icon(
                        Icons.fastfood,
                        size: 28,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        dish.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'PHP${dish.price}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        dish.available ? 'Available' : 'Not Available',
                        style: TextStyle(
                          color:
                              dish.available
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _buildIconLabelButton(
                  icon: Icons.list_alt,
                  label: 'Ingredients',
                  onPressed: () => _showIngredientsDialog(dish),
                ),
                _buildIconLabelButton(
                  icon: Icons.edit,
                  label: 'Edit',
                  onPressed:
                      () =>
                          _openDishDialog(dish: dish, category: dish.category),
                ),
                _buildIconLabelButton(
                  icon:
                      dish.available ? Icons.visibility_off : Icons.visibility,
                  label: dish.available ? 'Not Available' : 'Available',
                  onPressed: () async {
                    try {
                      await MenuStore.instance.updateDish(
                        id: dish.id,
                        name: dish.name,
                        price: dish.price,
                        paxOptions: dish.paxOptions,
                        imageBase64: dish.imageBase64,
                        category: dish.category,
                        sauces: dish.sauces,
                        ingredients: dish.ingredients,
                        type: dish.type,
                        available: !dish.available,
                      );
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    }
                  },
                ),
                _buildIconLabelButton(
                  icon: Icons.delete_outline,
                  label: 'Archive',
                  onPressed: () => _confirmArchiveDish(dish),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children:
                  dish.paxOptions.map((option) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color:
                            option == '1 pax'
                                ? Color(0xFFFFC107)
                                : Colors.grey.shade100,
                      ),
                      child: Text(option, style: const TextStyle(fontSize: 11)),
                    );
                  }).toList(),
            ),
            if (dish.sauces.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Sauces',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children:
                    dish.sauces.map((sauce) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color: Color(0xFFFFC107),
                        ),
                        child: Text(
                          sauce,
                          style: const TextStyle(fontSize: 11),
                        ),
                      );
                    }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIconLabelButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        constraints: const BoxConstraints(minWidth: 64, maxWidth: 82),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: Colors.grey.shade700),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 9, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _viewToggleButton(String label, bool isGrid, VoidCallback onTap) {
    final isSelected = (_isGridView && isGrid) || (!_isGridView && !isGrid);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isGrid ? Icons.grid_view : Icons.table_view,
              size: 16,
              color: isSelected ? Colors.black : Colors.grey.shade600,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.grey.shade600,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
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
          height: 44,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFFFC024) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected ? const Color(0xFFFFC024) : Colors.grey.shade300,
              width: 1,
            ),
            boxShadow: [
              if (selected)
                BoxShadow(
                  color: const Color(0xFFFFC024).withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              else
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
            ],
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 12,
                letterSpacing: 0.4,
                color: selected ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuGrid(
    List<MenuDish> dishes, {
    bool shrinkWrap = false,
    ScrollPhysics? physics,
  }) {
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
      childAspectRatio: 1.5,
      shrinkWrap: shrinkWrap,
      physics: physics,
      children: dishes.map(_buildDishCard).toList(),
    );
  }

  Widget _buildMenuTable(List<MenuDish> dishes) {
    if (dishes.isEmpty) {
      return Center(
        child: Text(
          'No dishes available.',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Price')),
            DataColumn(label: Text('Pax Options')),
            DataColumn(label: Text('Sauces')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Actions')),
          ],
          rows:
              dishes.map((dish) {
                return DataRow(
                  cells: [
                    DataCell(
                      Row(
                        children: [
                          if (dish.imageBase64 != null &&
                              dish.imageBase64!.isNotEmpty)
                            Container(
                              width: 40,
                              height: 40,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                color: Colors.grey.shade200,
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: CachedBase64Image(
                                base64String: dish.imageBase64,
                                fit: BoxFit.cover,
                                placeholder: Container(
                                  color: Colors.grey.shade200,
                                  child: const Icon(
                                    Icons.fastfood,
                                    color: Colors.grey,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          Expanded(
                            child: Text(
                              dish.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    DataCell(Text('PHP${dish.price}')),
                    DataCell(
                      Wrap(
                        spacing: 4,
                        children:
                            dish.paxOptions.map((pax) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      pax == '1 pax'
                                          ? const Color(0xFFFFC107)
                                          : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  pax,
                                  style: const TextStyle(fontSize: 10),
                                ),
                              );
                            }).toList(),
                      ),
                    ),
                    DataCell(
                      dish.sauces.isEmpty
                          ? const Text(
                            'None',
                            style: TextStyle(color: Colors.grey),
                          )
                          : Wrap(
                            spacing: 4,
                            children:
                                dish.sauces.take(2).map((sauce) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFC107),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      sauce,
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  );
                                }).toList(),
                          ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              dish.available
                                  ? Colors.green.shade100
                                  : Colors.red.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          dish.available ? 'Available' : 'Unavailable',
                          style: TextStyle(
                            color:
                                dish.available
                                    ? Colors.green.shade700
                                    : Colors.red.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed:
                                () => _openDishDialog(
                                  dish: dish,
                                  category: dish.category,
                                ),
                            icon: const Icon(Icons.edit, size: 16),
                            tooltip: 'Edit dish',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                          ),
                          IconButton(
                            onPressed: () => _toggleDishAvailability(dish),
                            icon: Icon(
                              dish.available
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              size: 16,
                            ),
                            tooltip:
                                dish.available
                                    ? 'Make unavailable'
                                    : 'Make available',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
        ),
      ),
    );
  }

  Widget _buildCateringTab() {
    final cateringDishes =
        MenuStore.instance.activeDishes
            .where((d) => d.category == 'catering')
            .where(_matchesSearch)
            .toList();

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search catering dishes...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                  ),
                  onChanged: (_) => _debouncer.debounce(() => setState(() {})),
                ),
              ),
              const SizedBox(width: 12),
              // View toggle buttons
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _viewToggleButton(
                      'Grid',
                      true,
                      () => setState(() => _isGridView = true),
                    ),
                    _viewToggleButton(
                      'Table',
                      false,
                      () => setState(() => _isGridView = false),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => _openDishDialog(category: 'catering'),
                icon: const Icon(Icons.add),
                label: const Text('Add Dish'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC024),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child:
              cateringDishes.isEmpty
                  ? const Center(child: Text('No catering dishes available'))
                  : _isGridView
                  ? _buildMenuGrid(cateringDishes)
                  : _buildMenuTable(cateringDishes),
        ),
      ],
    );
  }

  Widget _buildRestaurantTab() {
    final restaurantDishes =
        MenuStore.instance.activeDishes
            .where((d) => d.category == 'restaurant')
            .where(_matchesSearch)
            .toList();

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search restaurant dishes...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                  ),
                  onChanged: (_) => _debouncer.debounce(() => setState(() {})),
                ),
              ),
              const SizedBox(width: 12),
              // View toggle buttons
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _viewToggleButton(
                      'Grid',
                      true,
                      () => setState(() => _isRestaurantGridView = true),
                    ),
                    _viewToggleButton(
                      'Table',
                      false,
                      () => setState(() => _isRestaurantGridView = false),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => _openDishDialog(category: 'restaurant'),
                icon: const Icon(Icons.add),
                label: const Text('Add Dish'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC024),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child:
              restaurantDishes.isEmpty
                  ? Center(
                    child: Text(
                      'No restaurant dishes',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  )
                  : _isRestaurantGridView
                  ? _buildRestaurantMenuGrid(restaurantDishes)
                  : _buildMenuTable(restaurantDishes),
        ),
      ],
    );
  }

  Widget _buildRestaurantMenuGrid(List<MenuDish> restaurantDishes) {
    // Group dishes by meal type
    final mealTypes = _restaurantMealTypes;
    final groupedDishes = <String, List<MenuDish>>{};

    // Initialize all meal types with empty lists
    for (final mealType in mealTypes) {
      groupedDishes[mealType] = [];
    }

    // Group dishes by their type
    for (final dish in restaurantDishes) {
      if (dish.type.isEmpty || !mealTypes.contains(dish.type)) {
        // Add dishes with no type or unrecognized type to 'others'
        groupedDishes['others']!.add(dish);
      } else {
        groupedDishes[dish.type]!.add(dish);
      }
    }

    return ListView(
      children:
          mealTypes.map((mealType) {
            final dishes = groupedDishes[mealType]!;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Text(
                    mealType.toUpperCase(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                if (dishes.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 16.0,
                    ),
                    child: Text(
                      'No dishes in this category',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                else
                  _buildMenuGrid(
                    dishes,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                  ),
                const SizedBox(height: 24),
              ],
            );
          }).toList(),
    );
  }

  Widget _buildSetMenuTab(List<MenuDish> cateringDishes) {
    final setMenus = SetMenuStore.instance.activeSetMenus;
    final selectedSetName =
        _selectedSetMenuId != null
            ? setMenus
                .firstWhere(
                  (s) => s.id == _selectedSetMenuId,
                  orElse: () => setMenus.first,
                )
                .name
            : null;

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search dish',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                  ),
                  onChanged: (_) => _debouncer.debounce(() => setState(() {})),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.filter_list, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      'Filter',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => _openDishDialog(category: 'catering'),
                icon: const Icon(Icons.add),
                label: const Text('ADD NEW DISH'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC024),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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
                    color: Colors.white,
                    border: Border.all(color: Colors.black.withOpacity(0.08)),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // NEW MENU header
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3D0),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
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
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Dishes in new menu
                      Expanded(
                        child:
                            _selectedSetDishIds.isEmpty
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
                                      orElse:
                                          () => MenuDish(
                                            id: dishId,
                                            name: 'Unknown',
                                            price: '0',
                                            paxOptions: const [],
                                          ),
                                    );
                                    return _buildSetMenuDishCard(
                                      dish,
                                      isInSet: true,
                                      onRemove:
                                          _isModifyingSet
                                              ? () =>
                                                  _removeDishFromSet(dish.id)
                                              : null,
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
                                backgroundColor: const Color(0xFF1DB954),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(
                                _selectedSetMenuId == null
                                    ? 'Create Set Menu'
                                    : 'Update Set Menu',
                              ),
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
                  margin: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 0,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.black.withOpacity(0.08)),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    isExpanded: true,
                                    value: _selectedSetMenuId,
                                    hint: const Text('Select a set menu'),
                                    items:
                                        setMenus.map((setMenu) {
                                          return DropdownMenuItem(
                                            value: setMenu.id,
                                            child: Text(setMenu.name),
                                          );
                                        }).toList(),
                                    onChanged: (value) {
                                      if (value != null) {
                                        final setMenu = setMenus.firstWhere(
                                          (s) => s.id == value,
                                        );
                                        _viewSetMenu(setMenu);
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed:
                                  _selectedSetMenuId != null
                                      ? () => _loadSetMenuForEditing(
                                        _selectedSetMenuId!,
                                      )
                                      : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF4511E),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text('modify this set'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Dishes in selected set
                      Expanded(
                        child:
                            selectedSetName == null
                                ? Center(
                                  child: Text(
                                    'Select a set menu to view dishes',
                                    style: TextStyle(
                                      color: Colors.grey.shade400,
                                    ),
                                  ),
                                )
                                : ListView.builder(
                                  padding: const EdgeInsets.all(12),
                                  itemCount:
                                      MenuStore.instance
                                          .getDishesBySet(selectedSetName)
                                          .length,
                                  itemBuilder: (context, index) {
                                    final dishes = MenuStore.instance
                                        .getDishesBySet(selectedSetName);
                                    final dish = dishes[index];
                                    final isInCurrentSelection =
                                        _selectedSetDishIds.contains(dish.id);
                                    return _buildSetMenuDishCard(
                                      dish,
                                      isInSet: isInCurrentSelection,
                                      onAddToMenu:
                                          () => _addDishToCurrentSet(dish.id),
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
                    color: Colors.white,
                    border: Border.all(color: Colors.black.withOpacity(0.08)),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
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
                            final isInCurrentSelection = _selectedSetDishIds
                                .contains(dish.id);
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

  Widget _buildSetMenuDishCard(
    MenuDish dish, {
    required bool isInSet,
    VoidCallback? onAddToMenu,
    VoidCallback? onRemove,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
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
                  child: CachedBase64Image(
                    base64String: dish.imageBase64,
                    fit: BoxFit.cover,
                    placeholder: Container(
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.fastfood, color: Colors.grey),
                    ),
                  ),
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
                      backgroundColor: const Color(0xFFFFC024),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
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
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
              ],
            ),
            // Pax options
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children:
                  dish.paxOptions.map((pax) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
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
          child: Container(
            color: const Color(0xFFF7F8FA),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  'Catering and Restaurant Menu',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Manage catering, restaurant, and set menu content.',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ),
                const SizedBox(height: 12),
                // Tab buttons
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      _buildTabButton('CATERING', 0),
                      const SizedBox(width: 2),
                      _buildTabButton('RESTAURANT', 1),
                      const SizedBox(width: 2),
                      _buildTabButton('SET MENUS', 2),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Content based on active tab
                Expanded(
                  child:
                      _activeTabIndex == 0
                          ? _buildCateringTab()
                          : _activeTabIndex == 1
                          ? _buildRestaurantTab()
                          : _buildSetMenuTab(
                            MenuStore.instance.activeDishes
                                .where((d) => d.category == 'catering')
                                .where(_matchesSearch)
                                .toList(),
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
