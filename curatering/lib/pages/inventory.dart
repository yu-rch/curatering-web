import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/auth_session.dart';
import '../auth/roles.dart';
import '../utils/debouncer.dart';
import '../widgets/app_scaffold.dart';

class InventoryItem {
  final String id;
  final String name;
  final String category;
  final int quantity;
  final double unitCost;
  final String unit;
  final DateTime lastUpdated;
  final String? notes;
  final String? imageBase64;
  final bool lowStock;

  InventoryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    required this.unitCost,
    required this.unit,
    required this.lastUpdated,
    this.notes,
    this.imageBase64,
    this.lowStock = false,
  });

  InventoryItem copyWith({
    String? id,
    String? name,
    String? category,
    int? quantity,
    double? unitCost,
    String? unit,
    DateTime? lastUpdated,
    String? notes,
    String? imageBase64,
    bool? lowStock,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      unitCost: unitCost ?? this.unitCost,
      unit: unit ?? this.unit,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      notes: notes ?? this.notes,
      imageBase64: imageBase64 ?? this.imageBase64,
      lowStock: lowStock ?? this.lowStock,
    );
  }

  double get totalValue => quantity * unitCost;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'quantity': quantity,
      'unitCost': unitCost,
      'unit': unit,
      'lastUpdated': lastUpdated.toIso8601String(),
      'notes': notes,
      'imageBase64': imageBase64,
      'lowStock': lowStock,
    };
  }

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      category: json['category'] ?? '',
      quantity: json['quantity'] ?? 0,
      unitCost: (json['unitCost'] ?? 0.0).toDouble(),
      unit: json['unit'] ?? '',
      lastUpdated:
          DateTime.tryParse(json['lastUpdated'] ?? '') ?? DateTime.now(),
      notes: json['notes'],
      imageBase64: json['imageBase64'],
      lowStock: json['lowStock'] ?? false,
    );
  }
}

class Inventory extends StatefulWidget {
  const Inventory({super.key});

  @override
  State<Inventory> createState() => _InventoryState();
}

class _InventoryState extends State<Inventory> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _unitCostController = TextEditingController();
  final TextEditingController _unitController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();

  final Debouncer _searchDebouncer = Debouncer(
    delay: Duration(milliseconds: 300),
  );
  List<InventoryItem> _inventoryItems = [];
  List<InventoryItem> _filteredItems = [];
  bool _isLoading = false;
  String? _editingItemId;
  String? _selectedCategory;
  String _sortBy = 'name'; // name, quantity, category, lastUpdated
  bool _sortAscending = true;

  final List<String> _categories = [
    'Ingredients',
    'Beverages',
    'Supplies',
    'Equipment',
    'Packaging',
    'Cleaning',
    'Other',
  ];

  final List<String> _units = [
    'pcs',
    'kg',
    'g',
    'L',
    'mL',
    'boxes',
    'bottles',
    'packs',
  ];

  @override
  void initState() {
    super.initState();
    _loadInventoryItems();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _nameController.dispose();
    _quantityController.dispose();
    _unitCostController.dispose();
    _unitController.dispose();
    _notesController.dispose();
    _categoryController.dispose();
    _searchDebouncer.dispose();
    super.dispose();
  }

  bool get _isManager =>
      AuthSession.instance.currentRole == Role.manager ||
      AuthSession.instance.currentRole == Role.superAdmin;

  bool get _isStaff =>
      AuthSession.instance.currentRole == Role.supervisor ||
      AuthSession.instance.currentRole == Role.cashier ||
      _isManager;

  Future<void> _loadInventoryItems() async {
    setState(() => _isLoading = true);
    try {
      // Simulate loading from API - replace with actual API call
      await Future.delayed(const Duration(milliseconds: 500));

      // Sample data - replace with actual API call
      _inventoryItems = [
        InventoryItem(
          id: '1',
          name: 'Chicken Breast',
          category: 'Ingredients',
          quantity: 50,
          unitCost: 120.0,
          unit: 'kg',
          lastUpdated: DateTime.now().subtract(const Duration(hours: 2)),
          notes: 'Fresh frozen chicken breast',
          lowStock: false,
        ),
        InventoryItem(
          id: '2',
          name: 'Rice',
          category: 'Ingredients',
          quantity: 15,
          unitCost: 45.0,
          unit: 'kg',
          lastUpdated: DateTime.now().subtract(const Duration(days: 1)),
          lowStock: true,
        ),
        InventoryItem(
          id: '3',
          name: 'Cooking Oil',
          category: 'Supplies',
          quantity: 8,
          unitCost: 150.0,
          unit: 'L',
          lastUpdated: DateTime.now().subtract(const Duration(hours: 6)),
          notes: 'Vegetable oil',
          lowStock: false,
        ),
        InventoryItem(
          id: '4',
          name: 'Paper Plates',
          category: 'Packaging',
          quantity: 200,
          unitCost: 2.5,
          unit: 'pcs',
          lastUpdated: DateTime.now().subtract(const Duration(days: 2)),
          lowStock: false,
        ),
        InventoryItem(
          id: '5',
          name: 'Soy Sauce',
          category: 'Ingredients',
          quantity: 3,
          unitCost: 85.0,
          unit: 'L',
          lastUpdated: DateTime.now().subtract(const Duration(hours: 12)),
          lowStock: true,
        ),
      ];

      _filteredItems = _inventoryItems;
      _sortItems();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load inventory: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged() {
    _searchDebouncer.debounce(() {
      final query = _searchController.text.toLowerCase();
      setState(() {
        _filteredItems =
            _inventoryItems.where((item) {
              return item.name.toLowerCase().contains(query) ||
                  item.category.toLowerCase().contains(query) ||
                  (item.notes?.toLowerCase().contains(query) ?? false);
            }).toList();
        _sortItems();
      });
    });
  }

  void _sortItems() {
    _filteredItems.sort((a, b) {
      int comparison = 0;
      switch (_sortBy) {
        case 'name':
          comparison = a.name.compareTo(b.name);
          break;
        case 'quantity':
          comparison = a.quantity.compareTo(b.quantity);
          break;
        case 'category':
          comparison = a.category.compareTo(b.category);
          break;
        case 'lastUpdated':
          comparison = a.lastUpdated.compareTo(b.lastUpdated);
          break;
      }
      return _sortAscending ? comparison : -comparison;
    });
  }

  void _showAddEditDialog([InventoryItem? item]) {
    _editingItemId = item?.id;
    _nameController.text = item?.name ?? '';
    _quantityController.text = item?.quantity.toString() ?? '';
    _unitCostController.text = item?.unitCost.toString() ?? '';
    _unitController.text = item?.unit ?? 'pcs';
    _notesController.text = item?.notes ?? '';
    _categoryController.text =
        item?.category ?? _selectedCategory ?? 'Ingredients';

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              item == null ? 'Add Inventory Item' : 'Edit Inventory Item',
            ),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Item Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value:
                          _categoryController.text.isEmpty
                              ? 'Ingredients'
                              : _categoryController.text,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      items:
                          _categories.map((category) {
                            return DropdownMenuItem(
                              value: category,
                              child: Text(category),
                            );
                          }).toList(),
                      onChanged: (value) {
                        _categoryController.text = value ?? 'Ingredients';
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _quantityController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Quantity',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value:
                                _unitController.text.isEmpty
                                    ? 'pcs'
                                    : _unitController.text,
                            decoration: const InputDecoration(
                              labelText: 'Unit',
                              border: OutlineInputBorder(),
                            ),
                            items:
                                _units.map((unit) {
                                  return DropdownMenuItem(
                                    value: unit,
                                    child: Text(unit),
                                  );
                                }).toList(),
                            onChanged: (value) {
                              _unitController.text = value ?? 'pcs';
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _unitCostController,
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Unit Cost (₱)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Notes (Optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => _saveInventoryItem(),
                child: Text(item == null ? 'Add' : 'Update'),
              ),
            ],
          ),
    );
  }

  Future<void> _saveInventoryItem() async {
    if (_nameController.text.trim().isEmpty ||
        _quantityController.text.trim().isEmpty ||
        _unitCostController.text.trim().isEmpty ||
        _unitController.text.trim().isEmpty ||
        _categoryController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final inventoryItem = InventoryItem(
        id: _editingItemId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        category: _categoryController.text.trim(),
        quantity: int.parse(_quantityController.text),
        unitCost: double.parse(_unitCostController.text),
        unit: _unitController.text.trim(),
        lastUpdated: DateTime.now(),
        notes:
            _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
        lowStock:
            int.parse(_quantityController.text) < 10, // Simple low stock logic
      );

      setState(() {
        if (_editingItemId != null) {
          final index = _inventoryItems.indexWhere(
            (item) => item.id == _editingItemId,
          );
          if (index != -1) {
            _inventoryItems[index] = inventoryItem;
          }
        } else {
          _inventoryItems.add(inventoryItem);
        }
        _filteredItems = _inventoryItems;
        _sortItems();
      });

      Navigator.pop(context);
      _clearControllers();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _editingItemId != null
                ? 'Item updated successfully'
                : 'Item added successfully',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save item: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _deleteInventoryItem(String itemId) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Item'),
            content: const Text(
              'Are you sure you want to delete this inventory item?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _inventoryItems.removeWhere((item) => item.id == itemId);
                    _filteredItems = _inventoryItems;
                    _sortItems();
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Item deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  void _clearControllers() {
    _nameController.clear();
    _quantityController.clear();
    _unitCostController.clear();
    _unitController.clear();
    _notesController.clear();
    _categoryController.clear();
    _editingItemId = null;
  }

  Widget _buildInventoryCard(InventoryItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.category,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        item.lowStock
                            ? Colors.red.shade100
                            : Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: item.lowStock ? Colors.red : Colors.green,
                    ),
                  ),
                  child: Text(
                    item.lowStock ? 'Low Stock' : 'In Stock',
                    style: TextStyle(
                      color:
                          item.lowStock
                              ? Colors.red.shade700
                              : Colors.green.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quantity: ${item.quantity} ${item.unit}',
                        style: const TextStyle(fontSize: 16),
                      ),
                      Text(
                        'Unit Cost: ₱${item.unitCost.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Total Value',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '₱${item.totalValue.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (item.notes != null) ...[
              const SizedBox(height: 8),
              Text(
                'Notes: ${item.notes}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Last Updated: ${item.lastUpdated.day}/${item.lastUpdated.month}/${item.lastUpdated.year} ${item.lastUpdated.hour}:${item.lastUpdated.minute.toString().padLeft(2, '0')}',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
            ),
            if (_isManager) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _showAddEditDialog(item),
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit'),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _deleteInventoryItem(item.id),
                    icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                    label: const Text(
                      'Delete',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    final totalItems = _filteredItems.length;
    final lowStockItems = _filteredItems.where((item) => item.lowStock).length;
    final totalValue = _filteredItems.fold<double>(
      0,
      (sum, item) => sum + item.totalValue,
    );

    return Row(
      children: [
        Expanded(
          child: Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    totalItems.toString(),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const Text(
                    'Total Items',
                    style: TextStyle(color: Colors.blue),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Card(
            color: Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    lowStockItems.toString(),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const Text('Low Stock', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Card(
            color: Colors.green.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    '₱${totalValue.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const Text(
                    'Total Value',
                    style: TextStyle(color: Colors.green),
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
    if (!_isStaff) {
      return AppScaffold(
        showSearch: false,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Access Denied',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'You don\'t have permission to access the inventory.',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return AppScaffold(
      showSearch: true,
      child: Column(
        children: [
          // Header with search and filters
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search inventory items...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<String>(
                      value: _selectedCategory,
                      hint: const Text('All Categories'),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All Categories'),
                        ),
                        ..._categories.map((category) {
                          return DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedCategory = value;
                          _filteredItems =
                              value == null
                                  ? _inventoryItems
                                  : _inventoryItems
                                      .where((item) => item.category == value)
                                      .toList();
                          _sortItems();
                        });
                      },
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<String>(
                      value: _sortBy,
                      items: const [
                        DropdownMenuItem(
                          value: 'name',
                          child: Text('Sort by Name'),
                        ),
                        DropdownMenuItem(
                          value: 'quantity',
                          child: Text('Sort by Quantity'),
                        ),
                        DropdownMenuItem(
                          value: 'category',
                          child: Text('Sort by Category'),
                        ),
                        DropdownMenuItem(
                          value: 'lastUpdated',
                          child: Text('Sort by Date'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _sortBy = value!;
                          _sortItems();
                        });
                      },
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _sortAscending = !_sortAscending;
                          _sortItems();
                        });
                      },
                      icon: Icon(
                        _sortAscending
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildStatsRow(),
              ],
            ),
          ),

          // Add button (only for managers)
          if (_isManager)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _showAddEditDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Item'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Inventory list
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredItems.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inventory_outlined,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No inventory items found',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredItems.length,
                      itemBuilder: (context, index) {
                        return _buildInventoryCard(_filteredItems[index]);
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
