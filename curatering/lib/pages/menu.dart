import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../widgets/app_scaffold.dart';
import '../widgets/antd_staff.dart';
import '../widgets/antd_buttons.dart';
import '../widgets/antd_tokens.dart';
import '../widgets/paginated_data_table.dart';
import '../models/menu_dish.dart';
import '../constants/catering_meal_types.dart';
import '../services/api_client.dart';
import '../services/menu_store.dart';
import '../services/set_menu_store.dart';
import '../utils/debouncer.dart';
import '../utils/image_cache.dart';
import '../widgets/antd_message.dart';
import '../widgets/allergen_selector_field.dart';

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
  final TextEditingController _additionalChargeController =
      TextEditingController();
  final TextEditingController _paxController = TextEditingController();
  final TextEditingController _newPaxController = TextEditingController();
  final TextEditingController _newSauceController = TextEditingController();
  final TextEditingController _newIngredientController = TextEditingController();
  final TextEditingController _setMenuNameController = TextEditingController();
  final TextEditingController _typeController = TextEditingController();
  final TextEditingController _publicDescriptionController =
      TextEditingController();
  final TextEditingController _allergensController = TextEditingController();
  String _ingredientFilter = 'all';
  String _allergenFilter = 'all';
  String _mealTypeFilter = 'all';

  String? _editingImageBase64;
  String _editingType = ''; // For restaurant dish type grouping
  String _editingMealType = ''; // Catering meal type (menu_dishes.meal_type)
  int _activeTabIndex = 0;
  bool _isRestaurantGridView = false;
  List<String> _editingPaxOptions = ['1 pax'];
  List<String> _editingSauces = [];
  List<String> _editingIngredients = [];
  bool _editingSupportsAddOns = false;
  bool _editingAvailable = true;
  List<String> _selectedSetDishIds = [];
  String? _selectedSetMenuId;
  bool _isGridView = false; // Default to table view
  bool _isSavingSetMenu = false;
  String? _setMenuError;

  bool _matchesSearch(MenuDish dish) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return true;
    return dish.name.toLowerCase().contains(query);
  }

  List<String> _splitFilterTokens(String raw) {
    return raw
        .split(RegExp(r'[,;|]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  String _dishMealTypeFilterValue(MenuDish dish) {
    if (dish.category == 'restaurant') {
      return _normalizeRestaurantMealType(dish.effectiveMealType);
    }
    return normalizeCateringMealType(dish.effectiveMealType);
  }

  bool _matchesMenuFilters(MenuDish dish) {
    if (_ingredientFilter != 'all' &&
        !dish.ingredients.any(
          (item) => item.toLowerCase() == _ingredientFilter,
        )) {
      return false;
    }
    if (_allergenFilter != 'all' &&
        !_splitFilterTokens(
          dish.allergens,
        ).any((item) => item.toLowerCase() == _allergenFilter)) {
      return false;
    }
    if (_mealTypeFilter != 'all' &&
        _dishMealTypeFilterValue(dish).toLowerCase() != _mealTypeFilter) {
      return false;
    }
    return true;
  }

  List<String> _distinctIngredients(String category) {
    final values = <String>{};
    for (final dish in MenuStore.instance.activeDishes.where(
      (d) => d.category == category,
    )) {
      for (final ingredient in dish.ingredients) {
        final value = ingredient.trim();
        if (value.isNotEmpty) values.add(value);
      }
    }
    return values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  List<String> _distinctAllergens(String category) {
    final values = <String>{};
    for (final dish in MenuStore.instance.activeDishes.where(
      (d) => d.category == category,
    )) {
      values.addAll(_splitFilterTokens(dish.allergens));
    }
    return values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
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
    // Always ensure dishes are loading so the page never looks empty.
    if (MenuStore.instance.activeDishes.isEmpty) {
      unawaited(MenuStore.instance.loadDishes());
    }
    unawaited(MenuStore.instance.ensureImagesLoaded());
    unawaited(SetMenuStore.instance.loadSetMenus());
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
    _additionalChargeController.dispose();
    _paxController.dispose();
    _newPaxController.dispose();
    _newSauceController.dispose();
    _newIngredientController.dispose();
    _setMenuNameController.dispose();
    _typeController.dispose();
    _publicDescriptionController.dispose();
    _allergensController.dispose();
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
    _editingMealType = category == 'catering' ? 'main' : '';
    _typeController.clear();
    _nameController.clear();
    _priceController.clear();
    _additionalChargeController.text = '0.00';
    _editingPaxOptions = category == 'catering' ? const [] : ['1 pax'];
    if (category == 'restaurant') {
      _editingType = 'others';
      _typeController.text = 'others';
    }
    _editingSauces = [];
    _editingIngredients = [];
    _editingSupportsAddOns = false;
    _newPaxController.clear();
    _newSauceController.clear();
    _newIngredientController.clear();
    _publicDescriptionController.clear();
    _allergensController.clear();
  }

  void _startEditingDish(MenuDish dish) {
    _editingAvailable = dish.available;
    _editingImageBase64 = dish.imageBase64;
    if (dish.category == 'restaurant') {
      _editingType = _normalizeRestaurantMealType(dish.effectiveMealType);
      if (_editingType.isEmpty ||
          !_restaurantMealTypes.contains(_editingType)) {
        _editingType = 'others';
      }
    } else {
      _editingType = '';
    }
    _typeController.text = _editingType;
    _nameController.text = dish.name;
    _priceController.text = dish.price;
    _additionalChargeController.text =
        dish.additionalChargeAmount > 0
            ? dish.additionalChargeAmount.toStringAsFixed(2)
            : '0.00';
    _paxController.text = '';
    _editingPaxOptions = dish.paxOptions.toList();
    _editingSauces = dish.sauces.toList();
    _editingIngredients = dish.ingredients.toList();
    _editingSupportsAddOns = dish.supportsAddOns || dish.sauces.isNotEmpty;
    _newPaxController.clear();
    _newSauceController.clear();
    _newIngredientController.clear();
    _publicDescriptionController.text = dish.publicDescription;
    _allergensController.text = dish.allergens;
    if (dish.category == 'catering') {
      _editingMealType = normalizeCateringMealType(dish.mealType);
      // Do not silently coerce invalid/legacy values (e.g. "others") to Main.
      if (!kCateringMealTypes.contains(_editingMealType)) {
        _editingMealType = '';
      }
    } else {
      _editingMealType = '';
    }
  }

  void _addSauceOption() {
    final value = _newSauceController.text.trim();
    if (value.isEmpty || _editingSauces.contains(value)) return;
    setState(() {
      _editingSauces.add(value);
      _newSauceController.clear();
    });
  }

  void _addIngredientOption() {
    final value = _newIngredientController.text.trim();
    if (value.isEmpty ||
        _editingIngredients.any(
          (item) => item.toLowerCase() == value.toLowerCase(),
        )) {
      return;
    }
    setState(() {
      _editingIngredients.add(value);
      _newIngredientController.clear();
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
    if (_isSavingSetMenu) return;
    if (name.isEmpty || _selectedSetDishIds.isEmpty) {
      setState(() {
        _setMenuError =
            name.isEmpty
                ? 'Enter a set menu name.'
                : 'Add at least one dish to this set menu.';
      });
      return;
    }

    setState(() {
      _isSavingSetMenu = true;
      _setMenuError = null;
    });
    try {
      if (_selectedSetMenuId == null) {
        // Create new set menu
        await SetMenuStore.instance.addSetMenu(
          name: name,
          dishIds: _selectedSetDishIds.toList(),
        );
        if (mounted) {
          showAntdMessage(context, 'Set menu created successfully');
        }
      } else {
        // Update existing set menu
        await SetMenuStore.instance.updateSetMenu(
          id: _selectedSetMenuId!,
          name: name,
          dishIds: _selectedSetDishIds.toList(),
        );
        if (mounted) {
          showAntdMessage(context, 'Set menu updated successfully');
        }
      }
      _setMenuNameController.clear();
      _selectedSetDishIds.clear();
      _selectedSetMenuId = null;
    } catch (e) {
      if (mounted) {
        showAntdMessage(
          context,
          'Set menu save failed: $e',
          type: AntdMessageType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingSetMenu = false);
    }
  }

  Future<void> _openDishDialog({
    MenuDish? dish,
    required String category,
  }) async {
    var isSaving = false;
    String? formError;
    if (dish == null) {
      _resetEditorState(category: category);
    } else {
      _startEditingDish(dish);
      // List endpoint omits photos — fetch before edit so Save won't clear them.
      if (_editingImageBase64 == null || _editingImageBase64!.trim().isEmpty) {
        final withImage = await MenuStore.instance.loadDishWithImage(dish.id);
        if (withImage != null &&
            withImage.imageBase64 != null &&
            withImage.imageBase64!.trim().isNotEmpty) {
          _editingImageBase64 = withImage.imageBase64;
        }
      }
    }

    if (!mounted) return;

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
                        onPressed:
                            isSaving
                                ? null
                                : () async {
                                  final b64 = await _pickImageBase64();
                                  if (b64 == null) return;
                                  dialogSetState(
                                    () => _editingImageBase64 = b64,
                                  );
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
                      if (category == 'restaurant') ...[
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          key: ValueKey('restaurant_meal_$_editingType'),
                          value:
                              _restaurantMealTypes.contains(_editingType)
                                  ? _editingType
                                  : 'others',
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
                        const SizedBox(height: 12),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Dish has add-ons'),
                          subtitle: const Text(
                            'Enable sauce/add-on selection in the customer tray dialog.',
                          ),
                          value: _editingSupportsAddOns,
                          onChanged: (value) {
                            dialogSetState(() {
                              _editingSupportsAddOns = value;
                              if (!value) _editingSauces.clear();
                            });
                          },
                        ),
                        if (_editingSupportsAddOns) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final sauce in _editingSauces)
                                Chip(
                                  label: Text(sauce),
                                  onDeleted:
                                      () => dialogSetState(
                                        () => _editingSauces.remove(sauce),
                                      ),
                                ),
                            ],
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _newSauceController,
                                  decoration: const InputDecoration(
                                    labelText: 'Add-on / sauce option',
                                    hintText: 'e.g. Garlic sauce, extra gravy',
                                  ),
                                  onSubmitted: (_) {
                                    _addSauceOption();
                                    dialogSetState(() {});
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: () {
                                  _addSauceOption();
                                  dialogSetState(() {});
                                },
                                icon: const Icon(Icons.add),
                                label: const Text('Add'),
                              ),
                            ],
                          ),
                        ],
                      ],
                      TextField(
                        controller: _priceController,
                        decoration: const InputDecoration(labelText: 'Price'),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _additionalChargeController,
                        decoration: const InputDecoration(
                          labelText: 'Additional charge fee',
                          helperText:
                              'Used when customers add extra dishes beyond a set menu.',
                          prefixText: '₱ ',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                      if (category == 'catering') ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          key: ValueKey(
                            'catering_meal_${_editingMealType.isEmpty ? 'unset' : _editingMealType}',
                          ),
                          value:
                              kCateringMealTypes.contains(_editingMealType)
                                  ? _editingMealType
                                  : null,
                          decoration: const InputDecoration(
                            labelText: 'Meal type',
                            helperText:
                                'Used by the catering menu category filters',
                          ),
                          hint: const Text('Select meal type'),
                          items:
                              kCateringMealTypes
                                  .map(
                                    (t) => DropdownMenuItem(
                                      value: t,
                                      child: Text(mealTypeDisplayLabel(t)),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (v) {
                            if (v != null) {
                              dialogSetState(() {
                                _editingMealType = v;
                              });
                            }
                          },
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextField(
                        controller: _publicDescriptionController,
                        decoration: InputDecoration(
                          labelText: 'Dish description',
                          alignLabelWithHint: true,
                          hintText:
                              category == 'restaurant'
                                  ? 'Shown when customers tap the dish on the restaurant menu'
                                  : 'Shown when customers tap the dish on the catering menu',
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                      AllergenSelectorField(
                        key: ValueKey(
                          'allergens_${dish?.id ?? 'new'}_$category',
                        ),
                        initialSerialized: _allergensController.text,
                        onChanged: (s) => _allergensController.text = s,
                      ),
                      if (category == 'catering') ...[
                        const SizedBox(height: 12),
                        Text(
                          'Ingredients',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Shown on the catering menu and added to order checklists.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final ingredient in _editingIngredients)
                              Chip(
                                label: Text(ingredient),
                                onDeleted:
                                    () => dialogSetState(
                                      () => _editingIngredients.remove(
                                        ingredient,
                                      ),
                                    ),
                              ),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _newIngredientController,
                                decoration: const InputDecoration(
                                  labelText: 'Add ingredient',
                                  hintText: 'e.g. Beef, Rice',
                                ),
                                onSubmitted: (_) {
                                  _addIngredientOption();
                                  dialogSetState(() {});
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: () {
                                _addIngredientOption();
                                dialogSetState(() {});
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Add'),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      if (formError != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Text(
                            formError!,
                            style: TextStyle(
                              color: Colors.red.shade800,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Available for ordering'),
                        subtitle: const Text(
                          'Unavailable dishes are visible but cannot be added to tray.',
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
                  onPressed:
                      isSaving ? null : () => Navigator.of(context).pop(),
                  child: const Text('CANCEL'),
                ),
                ElevatedButton(
                  onPressed:
                      isSaving
                          ? null
                          : () async {
                            final name = _nameController.text.trim();
                            final price = _priceController.text.trim();
                            final additionalCharge =
                                double.tryParse(
                                  _additionalChargeController.text.trim(),
                                ) ??
                                0;
                            final needsPax = category == 'restaurant';
                            final paxToSave =
                                category == 'catering'
                                    ? const <String>[]
                                    : _editingPaxOptions;
                            if (name.isEmpty ||
                                price.isEmpty ||
                                (needsPax && paxToSave.isEmpty)) {
                              dialogSetState(() {
                                formError =
                                    name.isEmpty || price.isEmpty
                                        ? 'Please enter name and price.'
                                        : 'Add at least one PAX / size option for this dish.';
                              });
                              return;
                            }
                            if (category == 'catering' &&
                                !kCateringMealTypes.contains(
                                  normalizeCateringMealType(_editingMealType),
                                )) {
                              dialogSetState(() {
                                formError =
                                    'Please select a meal type (Appetizer, Main, Sides, Pasta, or Drinks).';
                              });
                              return;
                            }
                            dialogSetState(() => formError = null);
                            dialogSetState(() => isSaving = true);
                            try {
                              if (dish == null) {
                                await MenuStore.instance.addDish(
                                  name: name,
                                  price: price,
                                  additionalChargeAmount: additionalCharge,
                                  paxOptions: paxToSave,
                                  imageBase64: _editingImageBase64,
                                  category: category,
                                  sauces:
                                      category == 'restaurant'
                                          ? (_editingSupportsAddOns
                                              ? _editingSauces
                                              : const <String>[])
                                          : const [],
                                  supportsAddOns:
                                      category == 'restaurant' &&
                                      _editingSupportsAddOns,
                                  type: '',
                                  mealType:
                                      category == 'catering'
                                          ? normalizeCateringMealType(
                                            _editingMealType,
                                          )
                                          : _editingType,
                                  available: _editingAvailable,
                                  publicDescription:
                                      _publicDescriptionController.text,
                                  allergens: _allergensController.text,
                                  ingredients: _editingIngredients,
                                );
                              } else {
                                await MenuStore.instance.updateDish(
                                  id: dish.id,
                                  name: name,
                                  price: price,
                                  additionalChargeAmount: additionalCharge,
                                  paxOptions: paxToSave,
                                  // Only send when we have a photo (null keeps existing on server).
                                  imageBase64: _editingImageBase64,
                                  category: category,
                                  sauces:
                                      category == 'restaurant'
                                          ? (_editingSupportsAddOns
                                              ? _editingSauces
                                              : const <String>[])
                                          : const [],
                                  supportsAddOns:
                                      category == 'restaurant' &&
                                      _editingSupportsAddOns,
                                  type: '',
                                  mealType:
                                      category == 'catering'
                                          ? normalizeCateringMealType(
                                            _editingMealType,
                                          )
                                          : _editingType,
                                  available: _editingAvailable,
                                  publicDescription:
                                      _publicDescriptionController.text,
                                  allergens: _allergensController.text,
                                  ingredients: _editingIngredients,
                                );
                              }
                              if (context.mounted) {
                                Navigator.of(context).pop();
                              }
                              if (mounted) {
                                showAntdMessage(
                                  this.context,
                                  dish == null
                                      ? 'Dish added'
                                      : 'Dish saved',
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                final msg =
                                    e is ApiError
                                        ? e.message
                                        : e.toString();
                                showAntdMessage(
                                  context,
                                  'Dish save failed: $msg',
                                  type: AntdMessageType.error,
                                );
                              }
                            } finally {
                              if (context.mounted) {
                                dialogSetState(() => isSaving = false);
                              }
                            }
                          },
                  child:
                      isSaving
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : Text(dish == null ? 'ADD' : 'SAVE'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _toggleDishAvailability(MenuDish dish) async {
    try {
      await MenuStore.instance.updateDish(
        id: dish.id,
        name: dish.name,
        price: dish.price,
        additionalChargeAmount: dish.additionalChargeAmount,
        paxOptions: dish.paxOptions,
        imageBase64: dish.imageBase64,
        category: dish.category,
        sauces: dish.sauces,
        supportsAddOns: dish.supportsAddOns,
        ingredients: dish.ingredients,
        type: dish.type,
        mealType: dish.mealType,
        available: !dish.available,
        publicDescription: dish.publicDescription,
        allergens: dish.allergens,
      );
      if (mounted) {
        showAntdMessage(
          context,
          dish.available
              ? 'Dish marked as unavailable'
              : 'Dish marked as available',
        );
      }
    } catch (e) {
      if (mounted) {
        showAntdMessage(
          context,
          'Failed to update dish: $e',
          type: AntdMessageType.error,
        );
      }
    }
  }

  Future<void> _showBulkCateringPriceDialog() async {
    final priceCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Apply price to all catering dishes'),
          content: TextField(
            controller: priceCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Price (PHP)',
              hintText: 'Same base price for every active catering dish',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('APPLY TO ALL'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    final price = priceCtrl.text.trim();
    if (price.isEmpty) {
      showAntdMessage(context, 'Enter a price', type: AntdMessageType.error);
      return;
    }
    final dishes =
        MenuStore.instance.activeDishes
            .where((d) => d.category == 'catering')
            .toList();
    if (dishes.isEmpty) return;
    var done = 0;
    var failed = 0;
    for (final d in dishes) {
      try {
        await MenuStore.instance.updateDish(
          id: d.id,
          name: d.name,
          price: price,
          additionalChargeAmount: d.additionalChargeAmount,
          paxOptions: d.paxOptions,
          imageBase64: d.imageBase64,
          category: d.category,
          sauces: d.sauces,
          supportsAddOns: d.supportsAddOns,
          ingredients: d.ingredients,
          type: '',
          mealType: d.mealType.isNotEmpty ? d.mealType : d.type,
          available: d.available,
          publicDescription: d.publicDescription,
          allergens: d.allergens,
        );
        done++;
      } catch (_) {
        failed++;
      }
    }
    if (!mounted) return;
    showAntdMessage(
      context,
      failed == 0
          ? 'Updated $done catering dish(es).'
          : 'Updated $done, failed $failed.',
      type: failed == 0 ? AntdMessageType.success : AntdMessageType.warning,
    );
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
                              showAntdMessage(
                                context,
                                'Archive failed: $e',
                                type: AntdMessageType.error,
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
                                  showAntdMessage(
                                    context,
                                    'Ingredient save failed: $e',
                                    type: AntdMessageType.error,
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: Colors.grey.shade200,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: LazyDishImage(
                    dishId: dish.id,
                    width: 42,
                    height: 42,
                    fit: BoxFit.cover,
                    placeholder: Container(
                      color: Colors.grey.shade200,
                      child: const Icon(
                        Icons.fastfood,
                        size: 20,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        dish.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'PHP${dish.price}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dish.available ? 'Available' : 'Not Available',
                        style: TextStyle(
                          color:
                              dish.available
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 2,
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
                        additionalChargeAmount: dish.additionalChargeAmount,
                        paxOptions: dish.paxOptions,
                        imageBase64: dish.imageBase64,
                        category: dish.category,
                        sauces: dish.sauces,
                        supportsAddOns: dish.supportsAddOns,
                        ingredients: dish.ingredients,
                        type: dish.type,
                        mealType: dish.mealType,
                        available: !dish.available,
                        publicDescription: dish.publicDescription,
                        allergens: dish.allergens,
                      );
                    } catch (e) {
                      if (context.mounted) {
                        showAntdMessage(
                          context,
                          'Availability update failed: $e',
                          type: AntdMessageType.error,
                        );
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
            if (dish.category != 'catering' && dish.paxOptions.isNotEmpty) ...[
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
                        child: Text(
                          option,
                          style: const TextStyle(fontSize: 11),
                        ),
                      );
                    }).toList(),
              ),
            ],
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

  Widget _viewToggleButton(
    String label,
    bool isGrid,
    VoidCallback onTap, {
    bool? selectedGridView,
  }) {
    final currentGridView = selectedGridView ?? _isGridView;
    final isSelected =
        (currentGridView && isGrid) || (!currentGridView && !isGrid);
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
              color: isSelected ? Colors.black : AntdTokens.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : AntdTokens.textSecondary,
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
        onTap:
            () => setState(() {
              _activeTabIndex = index;
              _ingredientFilter = 'all';
              _allergenFilter = 'all';
              _mealTypeFilter = 'all';
              _searchController.clear();
            }),
        child: Container(
          height: 36,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFFFC024) : AntdTokens.cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? const Color(0xFFFFC024) : AntdTokens.border,
              width: 1,
            ),
            boxShadow: [
              if (selected)
                BoxShadow(
                  color: const Color(0xFFFFC024).withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              else
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
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
                fontSize: 11,
                letterSpacing: 0.2,
                color:
                    selected
                        ? const Color(0xFF1E1E1E)
                        : AntdTokens.textSecondary,
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
          style: TextStyle(color: AntdTokens.textSecondary),
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 4,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.35,
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
          style: TextStyle(color: AntdTokens.textSecondary),
        ),
      );
    }

    final isCatering =
        dishes.isNotEmpty && dishes.every((d) => d.category == 'catering');

    return Card(
      margin: EdgeInsets.zero,
      child: PagedDataTable(
        title: isCatering ? 'Catering Menu Dishes' : 'Restaurant Menu Dishes',
        enableSearch: false,
        fullWidth: true,
        maxTableHeight: MediaQuery.sizeOf(context).height,
        dataRowMinHeight: 54,
        dataRowMaxHeight: 72,
        headingRowHeight: 44,
        horizontalMargin: 12,
        columnSpacing: 18,
        columns: [
          const DataColumn(label: Text('Name')),
          const DataColumn(label: Text('Price')),
          if (!isCatering) const DataColumn(label: Text('Pax Options')),
          if (!isCatering) const DataColumn(label: Text('Sauces')),
          const DataColumn(label: Text('Status')),
          const DataColumn(label: Text('Actions')),
        ],
        rows:
            dishes.map((dish) {
              return DataRow(
                cells: [
                  DataCell(
                    SizedBox(
                      width: 260,
                      child: Row(
                        children: [
                          if (dish.imageBase64 != null &&
                              dish.imageBase64!.isNotEmpty)
                            Container(
                              width: 40,
                              height: 40,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                color: AntdTokens.fillTertiary,
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: CachedBase64Image(
                                base64String: dish.imageBase64,
                                fit: BoxFit.cover,
                                placeholder: Container(
                                  color: AntdTokens.fillTertiary,
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
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  DataCell(Text('PHP${dish.price}')),
                  if (!isCatering)
                    DataCell(
                      SizedBox(
                        width: 140,
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
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
                                            : AntdTokens.fillTertiary,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    pax,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color:
                                          pax == '1 pax'
                                              ? const Color(0xFF1E1E1E)
                                              : AntdTokens.valueDark,
                                    ),
                                  ),
                                );
                              }).toList(),
                        ),
                      ),
                    ),
                  if (!isCatering)
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
                          onPressed: () => _showIngredientsDialog(dish),
                          icon: const Icon(Icons.list_alt, size: 16),
                          tooltip: 'Ingredients',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
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
                        IconButton(
                          onPressed: () => _confirmArchiveDish(dish),
                          icon: const Icon(Icons.archive_outlined, size: 16),
                          tooltip: 'Archive',
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
    );
  }

  Widget _buildMenuToolbar({
    required String category,
    required bool isGridView,
    required ValueChanged<bool> onViewChanged,
    required VoidCallback onAddDish,
    required String searchHint,
    bool showBulkPrice = false,
    bool showViewToggle = true,
  }) {
    final ingredients = _distinctIngredients(category);
    final allergens = _distinctAllergens(category);
    final mealTypes =
        category == 'restaurant' ? _restaurantMealTypes : kCateringMealTypes;
    final ingredientValues = ingredients.map((v) => v.toLowerCase()).toSet();
    final allergenValues = allergens.map((v) => v.toLowerCase()).toSet();
    final mealTypeValues = mealTypes.map((v) => v.toLowerCase()).toSet();
    final ingredientValue =
        ingredientValues.contains(_ingredientFilter)
            ? _ingredientFilter
            : 'all';
    final allergenValue =
        allergenValues.contains(_allergenFilter) ? _allergenFilter : 'all';
    final mealTypeValue =
        mealTypeValues.contains(_mealTypeFilter) ? _mealTypeFilter : 'all';

    return AntdToolbar(
      elevated: false,
      padding: EdgeInsets.zero,
      children: [
        AntdSearchInput(
          controller: _searchController,
          hintText: searchHint,
          width: 220,
          onChanged: (_) => _debouncer.debounce(() => setState(() {})),
          onClear: () {
            _searchController.clear();
            setState(() {});
          },
        ),
        AntdSelect<String>(
          label: 'Ingredients',
          width: 180,
          value: ingredientValue,
          items: [
            const DropdownMenuItem(
              value: 'all',
              child: Text('All ingredients'),
            ),
            ...ingredients.map(
              (value) => DropdownMenuItem(
                value: value.toLowerCase(),
                child: Text(value),
              ),
            ),
          ],
          onChanged:
              (value) => setState(() => _ingredientFilter = value ?? 'all'),
        ),
        AntdSelect<String>(
          label: 'Allergens',
          width: 170,
          value: allergenValue,
          items: [
            const DropdownMenuItem(value: 'all', child: Text('All allergens')),
            ...allergens.map(
              (value) => DropdownMenuItem(
                value: value.toLowerCase(),
                child: Text(value),
              ),
            ),
          ],
          onChanged:
              (value) => setState(() => _allergenFilter = value ?? 'all'),
        ),
        AntdSelect<String>(
          label: 'Meal type',
          width: 170,
          value: mealTypeValue,
          items: [
            const DropdownMenuItem(value: 'all', child: Text('All meal types')),
            ...mealTypes.map(
              (value) => DropdownMenuItem(
                value: value.toLowerCase(),
                child: Text(
                  category == 'restaurant'
                      ? value
                          .split(' ')
                          .map(
                            (word) =>
                                word.isEmpty
                                    ? word
                                    : '${word[0].toUpperCase()}${word.substring(1)}',
                          )
                          .join(' ')
                      : mealTypeDisplayLabel(value),
                ),
              ),
            ),
          ],
          onChanged:
              (value) => setState(() => _mealTypeFilter = value ?? 'all'),
        ),
        if (_ingredientFilter != 'all' ||
            _allergenFilter != 'all' ||
            _mealTypeFilter != 'all' ||
            _searchController.text.trim().isNotEmpty)
          AntdSecondaryButton(
            onPressed: () => setState(() {
              _ingredientFilter = 'all';
              _allergenFilter = 'all';
              _mealTypeFilter = 'all';
              _searchController.clear();
            }),
            icon: Icons.filter_alt_off,
            label: 'Clear',
          ),
      ],
      trailing: [
        if (showViewToggle)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AntdTokens.fillTertiary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _viewToggleButton(
                  'Grid',
                  true,
                  () => onViewChanged(true),
                  selectedGridView: isGridView,
                ),
                _viewToggleButton(
                  'Table',
                  false,
                  () => onViewChanged(false),
                  selectedGridView: isGridView,
                ),
              ],
            ),
          ),
        if (showBulkPrice)
          IconButton.filledTonal(
            tooltip: 'Apply one price to all catering dishes',
            onPressed: _showBulkCateringPriceDialog,
            icon: const Icon(Icons.price_change_outlined),
          ),
        ElevatedButton.icon(
          onPressed: onAddDish,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add Dish'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFC024),
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCateringTab() {
    final cateringDishes =
        MenuStore.instance.activeDishes
            .where((d) => d.category == 'catering')
            .where(_matchesSearch)
            .where(_matchesMenuFilters)
            .toList();

    return Column(
      children: [
        Expanded(
          child:
              cateringDishes.isEmpty
                  ? Center(
                    child: Text(
                      'No catering dishes available',
                      style: TextStyle(color: AntdTokens.textSecondary),
                    ),
                  )
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
            .where(_matchesMenuFilters)
            .toList();

    return Column(
      children: [
        Expanded(
          child:
              restaurantDishes.isEmpty
                  ? Center(
                    child: Text(
                      'No restaurant dishes',
                      style: TextStyle(color: AntdTokens.textSecondary),
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

    // Group dishes by meal_type (legacy: type column)
    for (final dish in restaurantDishes) {
      final slot = _normalizeRestaurantMealType(dish.effectiveMealType);
      if (slot.isEmpty || !mealTypes.contains(slot)) {
        groupedDishes['others']!.add(dish);
      } else {
        groupedDishes[slot]!.add(dish);
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

  List<MenuDish> _sortedCateringDishesForSet(List<MenuDish> cateringDishes) {
    final byId = {for (final dish in cateringDishes) dish.id: dish};
    final selected = <MenuDish>[];
    for (final id in _selectedSetDishIds) {
      final dish = byId[id];
      if (dish != null) selected.add(dish);
    }
    final rest =
        cateringDishes
            .where((dish) => !_selectedSetDishIds.contains(dish.id))
            .toList();
    return [...selected, ...rest];
  }

  /// Dishes belonging to the currently selected set menu (by dishIds).
  List<MenuDish> _dishesForSelectedSetMenu(List<MenuDish> cateringDishes) {
    if (_selectedSetMenuId == null) return const [];
    final setMenus = SetMenuStore.instance.activeSetMenus;
    SetMenu? setMenu;
    for (final s in setMenus) {
      if (s.id == _selectedSetMenuId) {
        setMenu = s;
        break;
      }
    }
    if (setMenu == null) return const [];
    final byId = {for (final d in cateringDishes) d.id: d};
    final fromIds = <MenuDish>[];
    for (final id in setMenu.dishIds) {
      final dish = byId[id] ?? MenuStore.instance.findDishById(id);
      if (dish != null) fromIds.add(dish);
    }
    if (fromIds.isNotEmpty) return fromIds;
    // Fallback for legacy dishes that still carry setMenus names.
    return MenuStore.instance.getDishesBySet(setMenu.name);
  }

  Widget _buildSetMenuTab(List<MenuDish> cateringDishes) {
    final setMenus = SetMenuStore.instance.activeSetMenus;
    final sortedCateringDishes = _sortedCateringDishesForSet(cateringDishes);
    final selectedSetDishes = _dishesForSelectedSetMenu(cateringDishes);
    final isModifyingSelectedSet =
        _selectedSetMenuId != null &&
        (_selectedSetDishIds.isNotEmpty ||
            _setMenuNameController.text.trim().isNotEmpty);
    final selectedSetName =
        _selectedSetMenuId != null
            ? setMenus
                .firstWhere(
                  (s) => s.id == _selectedSetMenuId,
                  orElse: () => setMenus.first,
                )
                .name
            : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _setMenuColumn(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AntdTokens.brandPrimary.withValues(alpha: 0.22),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.add_circle_outline,
                        size: 18,
                        color: AntdTokens.valueDark,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'NEW MENU',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AntdTokens.valueDark,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Text(
                        'Menu Set Name',
                        style: TextStyle(color: AntdTokens.textSecondary),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _setMenuNameController,
                          style: TextStyle(color: AntdTokens.valueDark),
                          decoration: InputDecoration(
                            hintText: 'Set Name',
                            hintStyle: TextStyle(color: AntdTokens.labelMuted),
                            filled: true,
                            fillColor: AntdTokens.fillTertiary,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: AntdTokens.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: AntdTokens.border),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_setMenuError != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AntdTokens.error.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AntdTokens.error.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Text(
                        _setMenuError!,
                        style: TextStyle(
                          color: AntdTokens.error,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child:
                      _selectedSetDishIds.isEmpty
                          ? Center(
                            child: Text(
                              'add dishes here for your new menu',
                              style: TextStyle(
                                color: AntdTokens.labelMuted,
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
                                onRemove: () => _removeDishFromSet(dish.id),
                              );
                            },
                          ),
                ),
                if (_selectedSetDishIds.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSavingSetMenu ? null : _saveSetMenu,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1DB954),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          _isSavingSetMenu
                              ? 'Saving...'
                              : _selectedSetMenuId == null
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
        const SizedBox(width: 12),
        Expanded(
          child: _setMenuColumn(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Choose from existing set menus',
                    style: TextStyle(
                      color: AntdTokens.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: AntdSelect<String>(
                          width: null,
                          value: _selectedSetMenuId,
                          hint: 'Select set menu',
                          items:
                              setMenus
                                  .map(
                                    (setMenu) => DropdownMenuItem(
                                      value: setMenu.id,
                                      child: Text(
                                        setMenu.name,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            final setMenu = setMenus.firstWhere(
                              (s) => s.id == value,
                            );
                            _viewSetMenu(setMenu);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed:
                            _selectedSetMenuId != null
                                ? () =>
                                    _loadSetMenuForEditing(_selectedSetMenuId!)
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
                Expanded(
                  child:
                      selectedSetName == null
                          ? Center(
                            child: Text(
                              'select set menu to modify',
                              style: TextStyle(
                                color: AntdTokens.labelMuted,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          )
                          : selectedSetDishes.isEmpty
                          ? Center(
                            child: Text(
                              'No dishes in this set menu',
                              style: TextStyle(color: AntdTokens.labelMuted),
                            ),
                          )
                          : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: selectedSetDishes.length,
                            itemBuilder: (context, index) {
                              final dish = selectedSetDishes[index];
                              final isInCurrentSelection = _selectedSetDishIds
                                  .contains(dish.id);
                              return _buildSetMenuDishCard(
                                dish,
                                isInSet:
                                    isModifyingSelectedSet
                                        ? isInCurrentSelection
                                        : true,
                                onAddToMenu:
                                    isModifyingSelectedSet &&
                                            !isInCurrentSelection
                                        ? () => _addDishToCurrentSet(dish.id)
                                        : null,
                                onRemove: null,
                              );
                            },
                          ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _setMenuColumn(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'select from all dishes',
                    style: TextStyle(
                      color: AntdTokens.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: sortedCateringDishes.length,
                    itemBuilder: (context, index) {
                      final dish = sortedCateringDishes[index];
                      final isInCurrentSelection = _selectedSetDishIds.contains(
                        dish.id,
                      );
                      return _buildSetMenuDishCard(
                        dish,
                        isInSet: isInCurrentSelection,
                        onAddToMenu:
                            isInCurrentSelection
                                ? null
                                : () => _addDishToCurrentSet(dish.id),
                        onRemove:
                            isInCurrentSelection
                                ? () => _removeDishFromSet(dish.id)
                                : null,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _setMenuColumn({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: AntdTokens.cardBg,
        border: Border.all(color: AntdTokens.borderSubtle),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
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
    final listed = _dishesForSelectedSetMenu(MenuStore.instance.activeDishes);
    setState(() {
      _selectedSetDishIds = listed.map((d) => d.id).toList();
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
      color: AntdTokens.fillTertiary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AntdTokens.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 80,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: AntdTokens.cardBg,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: CachedBase64Image(
                    base64String: dish.imageBase64,
                    fit: BoxFit.cover,
                    placeholder: Container(
                      color: AntdTokens.cardBg,
                      child: Icon(
                        Icons.fastfood,
                        color: AntdTokens.labelMuted,
                      ),
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
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AntdTokens.valueDark,
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
        // Show loading state while fetching or before first paint of dishes.
        if (MenuStore.instance.isLoading ||
            (MenuStore.instance.activeDishes.isEmpty &&
                MenuStore.instance.error == null)) {
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
            color: AntdTokens.pageBg,
            child: Column(
              children: [
                Material(
                  color: AntdTokens.cardBg,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: AntdTokens.fillTertiary,
                            borderRadius: BorderRadius.circular(20),
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
                        _buildMenuToolbar(
                          category:
                              _activeTabIndex == 1 ? 'restaurant' : 'catering',
                          isGridView:
                              _activeTabIndex == 1
                                  ? _isRestaurantGridView
                                  : _isGridView,
                          onViewChanged: (value) {
                            setState(() {
                              if (_activeTabIndex == 1) {
                                _isRestaurantGridView = value;
                              } else {
                                _isGridView = value;
                              }
                            });
                          },
                          onAddDish:
                              () => _openDishDialog(
                                category:
                                    _activeTabIndex == 1
                                        ? 'restaurant'
                                        : 'catering',
                              ),
                          searchHint:
                              _activeTabIndex == 0
                                  ? 'Search catering dishes'
                                  : _activeTabIndex == 1
                                  ? 'Search restaurant dishes'
                                  : 'Search set menu dishes',
                          showBulkPrice: _activeTabIndex == 0,
                          showViewToggle: _activeTabIndex != 2,
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child:
                        _activeTabIndex == 0
                            ? _buildCateringTab()
                            : _activeTabIndex == 1
                            ? _buildRestaurantTab()
                            : _buildSetMenuTab(
                              MenuStore.instance.activeDishes
                                  .where((d) => d.category == 'catering')
                                  .where(_matchesSearch)
                                  .where(_matchesMenuFilters)
                                  .toList(),
                            ),
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
