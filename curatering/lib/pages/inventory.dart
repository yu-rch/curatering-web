import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/auth_session.dart';
import '../auth/roles.dart';
import '../services/api_client.dart';
import '../utils/debouncer.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/paginated_data_table.dart';

class InventoryItem {
  final String id;
  final String name;
  final String category;
  final int quantity;
  final double unitCost;
  final String unit;
  final DateTime lastUpdated;
  final String? notes;
  final bool lowStock;
  final bool archived;

  const InventoryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    required this.unitCost,
    required this.unit,
    required this.lastUpdated,
    this.notes,
    this.lowStock = false,
    this.archived = false,
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
    bool? lowStock,
    bool? archived,
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
      lowStock: lowStock ?? this.lowStock,
      archived: archived ?? this.archived,
    );
  }

  double get totalValue => quantity * unitCost;

  static InventoryItem fromApi(Map<String, dynamic> json) {
    return InventoryItem(
      id: json['id']?.toString() ?? '',
      name: (json['name'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      quantity: (json['quantity'] is int)
          ? json['quantity'] as int
          : int.tryParse('${json['quantity']}') ?? 0,
      unitCost: (json['unitCost'] is num)
          ? (json['unitCost'] as num).toDouble()
          : double.tryParse('${json['unitCost']}') ?? 0,
      unit: (json['unit'] ?? 'pcs').toString(),
      lastUpdated: DateTime.tryParse('${json['lastUpdated']}') ?? DateTime.now(),
      notes: json['notes']?.toString(),
      lowStock: json['lowStock'] == true,
      archived: json['archived'] == true,
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
  final TextEditingController _unitController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _minStockController =
      TextEditingController(text: '10');

  final Debouncer _searchDebouncer = Debouncer(
    delay: const Duration(milliseconds: 300),
  );

  List<InventoryItem> _activeItems = [];
  List<InventoryItem> _filteredActive = [];

  bool _isLoading = false;
  String? _editingItemId;
  String _sortBy = 'name';
  bool _sortAscending = true;
  bool _isTabularView = false;

  final List<String> _categories = const [
    'Cooking Equipment',
    'Serving Equipment',
    'Tableware & Cutlery',
    'Non-Perishable Ingredients',
    'Beverages & Liquids',
    'Packaging & Disposables',
    'Transport & Storage',
    'Cleaning Supplies',
    'Decor & Ambiance',
    'Safety & First Aid',
    'Ingredients',
    'Supplies',
    'Packaging',
    'Other',
  ];

  final List<String> _units = const [
    'pcs',
    'sets',
    'kg',
    'g',
    'L',
    'mL',
    'boxes',
    'bottles',
    'packs',
    'cases',
    'bags',
    'rolls',
    'pairs',
    'dozens',
  ];

  @override
  void initState() {
    super.initState();
    _loadInventory();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _nameController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _minStockController.dispose();
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

  Future<void> _loadInventory() async {
    setState(() => _isLoading = true);
    try {
      final decoded = await ApiClient.instance.getJson(
        '/api/inventory',
        queryParameters: const {'archived': 'false'},
        useCache: false,
      );
      final raw = decoded['items'];
      final list = <InventoryItem>[];
      if (raw is List) {
        for (final e in raw) {
          if (e is Map<String, dynamic>) {
            list.add(InventoryItem.fromApi(e));
          }
        }
      }
      setState(() {
        _activeItems = list;
        _applyActiveFilter();
      });
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged() {
    _searchDebouncer.debounce(() {
      if (mounted) setState(_applyActiveFilter);
    });
  }

  void _applyActiveFilter() {
    final q = _searchController.text.toLowerCase().trim();
    _filteredActive =
        _activeItems.where((item) {
          if (q.isEmpty) return true;
          return item.name.toLowerCase().contains(q) ||
              item.category.toLowerCase().contains(q) ||
              (item.notes?.toLowerCase().contains(q) ?? false);
        }).toList();
    _sortList(_filteredActive);
  }

  void _sortList(List<InventoryItem> list) {
    list.sort((a, b) {
      int c = 0;
      switch (_sortBy) {
        case 'quantity':
          c = a.quantity.compareTo(b.quantity);
          break;
        case 'category':
          c = a.category.compareTo(b.category);
          break;
        case 'lastUpdated':
          c = a.lastUpdated.compareTo(b.lastUpdated);
          break;
        case 'name':
        default:
          c = a.name.compareTo(b.name);
      }
      return _sortAscending ? c : -c;
    });
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  void _showAddEditDialog([InventoryItem? item]) {
    _editingItemId = item?.id;
    _nameController.text = item?.name ?? '';
    _quantityController.text = item?.quantity.toString() ?? '';
    _unitController.text = item?.unit ?? 'pcs';
    _descriptionController.text = item?.notes ?? '';
    _categoryController.text = item?.category ?? 'Non-Perishable Ingredients';
    if (!_categories.contains(_categoryController.text)) {
      _categoryController.text = 'Other';
    }
    _minStockController.text = '10';

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
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
                      labelText: 'Item',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownMenu<String>(
                    initialSelection: _categoryController.text,
                    label: const Text('Category'),
                    dropdownMenuEntries:
                        _categories
                            .map(
                              (c) => DropdownMenuEntry(value: c, label: c),
                            )
                            .toList(),
                    onSelected: (v) {
                      if (v != null) _categoryController.text = v;
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _quantityController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Quantity',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownMenu<String>(
                          initialSelection:
                              _units.contains(_unitController.text)
                                  ? _unitController.text
                                  : 'pcs',
                          label: const Text('Unit'),
                          dropdownMenuEntries:
                              _units
                                  .map(
                                    (u) => DropdownMenuEntry(value: u, label: u),
                                  )
                                  .toList(),
                          onSelected: (v) {
                            if (v != null) _unitController.text = v;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _minStockController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Low stock alert (quantity ≤ this)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => _saveInventoryItem(dialogContext),
              child: Text(item == null ? 'Add' : 'Update'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveInventoryItem(BuildContext dialogContext) async {
    if (_nameController.text.trim().isEmpty ||
        _quantityController.text.trim().isEmpty ||
        _unitController.text.trim().isEmpty ||
        _categoryController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final q = int.tryParse(_quantityController.text.trim());
    if (q == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid quantity')),
      );
      return;
    }

    try {
      final body = {
        'name': _nameController.text.trim(),
        'category': _categoryController.text.trim(),
        'quantity': q,
        'unitCost': 0,
        'unit': _unitController.text.trim(),
        'notes':
            _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
        'minStockLevel': int.tryParse(_minStockController.text.trim()) ?? 0,
      };

      if (_editingItemId != null) {
        await ApiClient.instance.putJson(
          '/api/inventory/$_editingItemId',
          body: body,
        );
      } else {
        await ApiClient.instance.postJson('/api/inventory', body: body);
      }

      if (!mounted) return;
      Navigator.pop(dialogContext);
      _clearControllers();
      await _loadInventory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _editingItemId != null ? 'Item updated' : 'Item added',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _archiveItem(InventoryItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Archive item'),
            content: Text('Archive "${item.name}"? You can restore it later.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Archive'),
              ),
            ],
          ),
    );
    if (ok != true || !mounted) return;
    try {
      await ApiClient.instance.postJson(
        '/api/inventory/${item.id}/archive',
        body: {'archived': true},
      );
      await _loadInventory();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Item archived')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _clearControllers() {
    _nameController.clear();
    _quantityController.clear();
    _unitController.text = 'pcs';
    _descriptionController.clear();
    _categoryController.clear();
    _minStockController.text = '10';
    _editingItemId = null;
  }

  Widget _buildViewToggleButton(
    String label,
    bool isTabular,
    VoidCallback onPressed,
  ) {
    final isSelected = _isTabularView == isTabular;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFC024) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFFFFC024) : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildTabularView(List<InventoryItem> items) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: PagedDataTable(
        headingRowColor: const WidgetStatePropertyAll(Color(0xFFF5F7F9)),
        columnSpacing: 20,
        columns: const [
          DataColumn(label: SizedBox(width: 120, child: Text('Item'))),
          DataColumn(label: Text('Category')),
          DataColumn(label: Text('Description')),
          DataColumn(label: Text('Qty')),
          DataColumn(label: Text('Unit')),
          DataColumn(label: Text('Updated')),
          DataColumn(label: Text('Stock')),
          DataColumn(label: Text('Actions')),
        ],
        rows:
            items.map((item) {
              return DataRow(
                cells: [
                  DataCell(
                    SizedBox(
                      width: 120,
                      child: Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(Text(item.category)),
                  DataCell(
                    SizedBox(
                      width: 160,
                      child: Text(
                        item.notes?.trim().isNotEmpty == true
                            ? item.notes!
                            : '—',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(Text('${item.quantity}')),
                  DataCell(Text(item.unit)),
                  DataCell(Text(_formatDate(item.lastUpdated))),
                  DataCell(
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
                      ),
                      child: Text(
                        item.lowStock ? 'Low' : 'OK',
                        style: TextStyle(
                          color:
                              item.lowStock
                                  ? Colors.red.shade800
                                  : Colors.green.shade800,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    _isManager
                        ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Edit',
                              icon: const Icon(
                                Icons.edit,
                                size: 20,
                                color: Colors.blue,
                              ),
                              onPressed: () => _showAddEditDialog(item),
                            ),
                            IconButton(
                              tooltip: 'Archive',
                              icon: const Icon(
                                Icons.archive_outlined,
                                size: 20,
                                color: Colors.orange,
                              ),
                              onPressed: () => _archiveItem(item),
                            ),
                          ],
                        )
                        : const Text('—'),
                  ),
                ],
              );
            }).toList(),
      ),
    );
  }

  Widget _buildGridCard(InventoryItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(item.category, style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            Text('Qty: ${item.quantity} ${item.unit}'),
            if (item.notes != null && item.notes!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  item.notes!,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ),
            if (_isManager) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _showAddEditDialog(item),
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Edit'),
                  ),
                  TextButton.icon(
                    onPressed: () => _archiveItem(item),
                    icon: const Icon(Icons.archive_outlined, size: 18),
                    label: const Text('Archive'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGridView(List<InventoryItem> items) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return _buildGridCard(items[index]);
      },
    );
  }

  Widget _buildStatsRow(List<InventoryItem> items, int totalActiveInSystem) {
    final total = items.length;
    final low = items.where((e) => e.lowStock).length;
    final showTotalHint = totalActiveInSystem > 0 && total != totalActiveInSystem;
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
                    '$total',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const Text('Items'),
                  if (showTotalHint)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'of $totalActiveInSystem total',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Card(
            color: Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    '$low',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const Text('Low stock'),
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
          child: Text(
            'You don\'t have permission to access inventory.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    final displayList = _filteredActive;

    return AppScaffold(
      showSearch: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search inventory…',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildStatsRow(displayList, _activeItems.length),
                ),
                const SizedBox(width: 12),
                Column(
                  children: [
                    _buildViewToggleButton(
                      'Grid',
                      false,
                      () => setState(() => _isTabularView = false),
                    ),
                    const SizedBox(height: 6),
                    _buildViewToggleButton(
                      'Table',
                      true,
                      () => setState(() => _isTabularView = true),
                    ),
                  ],
                ),
                if (_isManager) ...[
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => _showAddEditDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add item'),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : displayList.isEmpty
                    ? Center(
                      child: Text(
                        _activeItems.isEmpty
                            ? 'No inventory items'
                            : 'No matches for your search',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                    : _isTabularView
                    ? _buildTabularView(displayList)
                    : _buildGridView(displayList),
          ),
        ],
      ),
    );
  }
}
