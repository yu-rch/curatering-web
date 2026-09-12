import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/auth_session.dart';
import '../auth/roles.dart';
import '../services/api_client.dart';
import '../utils/debouncer.dart';
import '../utils/print_tabular_report.dart';
import '../widgets/antd_buttons.dart';
import '../widgets/antd_form_field.dart';
import '../widgets/antd_staff.dart';
import '../widgets/antd_tokens.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/paginated_data_table.dart';

class InventoryItem {
  final String id;
  final String itemCode;
  final String name;
  final String category;
  final int quantity;
  final double unitCost;
  final String unit;
  final DateTime lastUpdated;
  final String? notes;
  final int minStockLevel;
  final bool lowStock;
  final bool available;
  final bool archived;

  const InventoryItem({
    required this.id,
    required this.itemCode,
    required this.name,
    required this.category,
    required this.quantity,
    required this.unitCost,
    required this.unit,
    required this.lastUpdated,
    this.notes,
    this.minStockLevel = 0,
    this.lowStock = false,
    this.available = true,
    this.archived = false,
  });

  InventoryItem copyWith({
    String? id,
    String? itemCode,
    String? name,
    String? category,
    int? quantity,
    double? unitCost,
    String? unit,
    DateTime? lastUpdated,
    String? notes,
    int? minStockLevel,
    bool? lowStock,
    bool? available,
    bool? archived,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      itemCode: itemCode ?? this.itemCode,
      name: name ?? this.name,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      unitCost: unitCost ?? this.unitCost,
      unit: unit ?? this.unit,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      notes: notes ?? this.notes,
      minStockLevel: minStockLevel ?? this.minStockLevel,
      lowStock: lowStock ?? this.lowStock,
      available: available ?? this.available,
      archived: archived ?? this.archived,
    );
  }

  double get totalValue => quantity * unitCost;

  static String _fallbackItemCode(String rawId) {
    final compact = rawId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final suffix = compact.isEmpty ? '0000' : compact.padLeft(4, '0');
    return 'ITM-${suffix.substring(0, 4).toUpperCase()}';
  }

  static InventoryItem fromApi(Map<String, dynamic> json) {
    final rawCode =
        (json['itemCode'] ?? json['itemNo'] ?? json['item_code'] ?? '')
            .toString()
            .trim();
    final parsedUpdated = DateTime.tryParse('${json['lastUpdated']}');
    return InventoryItem(
      id: json['id']?.toString() ?? '',
      itemCode:
          rawCode.isNotEmpty
              ? rawCode
              : _fallbackItemCode((json['id'] ?? '').toString()),
      name: (json['name'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      quantity:
          (json['quantity'] is int)
              ? json['quantity'] as int
              : int.tryParse('${json['quantity']}') ?? 0,
      unitCost:
          (json['unitCost'] is num)
              ? (json['unitCost'] as num).toDouble()
              : double.tryParse('${json['unitCost']}') ?? 0,
      unit: (json['unit'] ?? 'pcs').toString(),
      lastUpdated: parsedUpdated?.toLocal() ?? DateTime.now(),
      notes: json['notes']?.toString(),
      minStockLevel:
          (json['minStockLevel'] is int)
              ? json['minStockLevel'] as int
              : int.tryParse('${json['minStockLevel'] ?? ''}') ?? 0,
      lowStock: json['lowStock'] == true,
      available: json['available'] != false,
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
  final TextEditingController _minStockController = TextEditingController(
    text: '10',
  );

  final Debouncer _searchDebouncer = Debouncer(
    delay: const Duration(milliseconds: 300),
  );

  List<InventoryItem> _activeItems = [];
  List<InventoryItem> _filteredActive = [];

  bool _isLoading = false;
  bool _isExportingPdf = false;
  bool _isSavingInventory = false;
  String? _editingItemId;
  InventoryItem? _stockTargetItem;
  bool _creatingNewInventoryItem = false;
  String _sortBy = 'name';
  bool _sortAscending = true;
  bool _editingAvailable = true;
  String _stockFilter = 'all';
  String _categoryFilter = 'all';
  int? _updatedYearFilter;
  int? _updatedMonthFilter;
  int? _updatedDayFilter;

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
          if (q.isNotEmpty && !_matchesInventoryPrefix(item, q)) return false;
          if (_categoryFilter != 'all' && !_matchesCategoryFilter(item)) {
            return false;
          }
          if (!_matchesStockFilter(item)) return false;
          final updated = item.lastUpdated.toLocal();
          if (_updatedYearFilter != null &&
              updated.year != _updatedYearFilter) {
            return false;
          }
          if (_updatedMonthFilter != null &&
              updated.month != _updatedMonthFilter) {
            return false;
          }
          if (_updatedDayFilter != null && updated.day != _updatedDayFilter) {
            return false;
          }
          return true;
        }).toList();
    _sortList(_filteredActive);
  }

  String _filterKey(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  bool _matchesCategoryFilter(InventoryItem item) {
    return _filterKey(item.category) == _filterKey(_categoryFilter);
  }

  bool _matchesStockFilter(InventoryItem item) {
    switch (_stockFilter) {
      case 'ok':
        return item.available && !item.lowStock;
      case 'low':
        return item.available && item.lowStock;
      case 'unavailable':
        return !item.available;
      case 'all':
      default:
        return true;
    }
  }

  bool _matchesInventoryPrefix(InventoryItem item, String query) {
    final fields = [
      item.itemCode,
      item.name,
      item.category,
      item.notes ?? '',
      '${item.quantity}',
      item.unit,
      _formatDate(item.lastUpdated),
    ];
    for (final field in fields) {
      final normalized = field.toLowerCase().trim();
      if (normalized.startsWith(query)) return true;
      final tokens = normalized.split(RegExp(r'[\s,./:_-]+'));
      if (tokens.any((word) => word.startsWith(query))) return true;
    }
    return false;
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

  String _formatDateTime(DateTime date) {
    final local = date.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  String _stockLabel(InventoryItem item) {
    if (!item.available) return 'Unavailable';
    return item.lowStock ? 'Low' : 'OK';
  }

  Future<void> _printInventoryPdf(List<InventoryItem> items) async {
    if (_isExportingPdf) return;
    setState(() => _isExportingPdf = true);
    try {
      final generatedAt = DateTime.now();
      final headers = [
        'Item No.',
        'Item',
        'Category',
        'Description',
        'Qty',
        'Unit',
        'Updated',
        'Stock',
      ];
      final rows =
          items
              .map(
                (item) => [
                  item.itemCode,
                  item.name,
                  item.category,
                  item.notes?.trim().isNotEmpty == true ? item.notes! : '-',
                  '${item.quantity}',
                  item.unit,
                  _formatDate(item.lastUpdated),
                  _stockLabel(item),
                ],
              )
              .toList();

      await printSingleTableReport(
        title: 'Inventory Items',
        headers: headers,
        rows: rows,
        sectionTitle: 'Inventory Items',
        filename: 'inventory-items.pdf',
        subtitle:
            "Macrina's Kitchen and Catering · As of ${_formatDateTime(generatedAt)} · ${items.length} row(s)",
      );
    } finally {
      if (mounted) setState(() => _isExportingPdf = false);
    }
  }

  void _showAddEditDialog([InventoryItem? item, bool createNewItem = false]) {
    _editingItemId = item?.id;
    _stockTargetItem = null;
    _creatingNewInventoryItem = createNewItem || item != null;
    _nameController.text = item?.name ?? '';
    _quantityController.text = item == null ? '' : item.quantity.toString();
    _unitController.text = item?.unit ?? 'pcs';
    _descriptionController.text = item?.notes ?? '';
    _categoryController.text = item?.category ?? 'Non-Perishable Ingredients';
    if (!_categories.contains(_categoryController.text)) {
      _categoryController.text = 'Other';
    }
    _minStockController.text = item == null ? '10' : item.minStockLevel.toString();
    _editingAvailable = item?.available ?? true;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: AntdTokens.modalBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              title: Text(
                item == null
                    ? createNewItem
                        ? 'New Inventory Item'
                        : 'Add Stock to Existing Item'
                    : 'Edit Inventory Item',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Builder(
                    builder: (context) {
                      final isAddStock = item == null && !createNewItem;
                      final isEdit = item != null;
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AntdFieldShell(
                            label: 'Item',
                            required: true,
                            errorText:
                                isAddStock &&
                                        _nameController.text.trim().isNotEmpty &&
                                        (_stockTargetItem == null ||
                                            _stockTargetItem!.name
                                                    .toLowerCase()
                                                    .trim() !=
                                                _nameController.text
                                                    .toLowerCase()
                                                    .trim())
                                    ? 'Select a matching inventory item'
                                    : null,
                            child:
                                isAddStock
                                    ? Autocomplete<InventoryItem>(
                                      displayStringForOption:
                                          (option) => option.name,
                                      optionsBuilder: (value) {
                                        final query =
                                            value.text.trim().toLowerCase();
                                        if (query.isEmpty) {
                                          return _activeItems.take(12);
                                        }
                                        return _activeItems.where(
                                          (i) =>
                                              _matchesInventoryPrefix(i, query),
                                        );
                                      },
                                      fieldViewBuilder: (
                                        context,
                                        controller,
                                        focusNode,
                                        onSubmit,
                                      ) {
                                        if (controller.text !=
                                            _nameController.text) {
                                          controller.text =
                                              _nameController.text;
                                        }
                                        return TextField(
                                          controller: controller,
                                          focusNode: focusNode,
                                          decoration: const InputDecoration(
                                            hintText:
                                                'Search by first letter / prefix…',
                                            border: InputBorder.none,
                                            isDense: true,
                                          ),
                                          onChanged: (value) {
                                            setModalState(() {
                                              _nameController.text = value;
                                              InventoryItem? match;
                                              final normalized =
                                                  value.toLowerCase().trim();
                                              for (final i in _activeItems) {
                                                if (i.name
                                                        .toLowerCase()
                                                        .trim() ==
                                                    normalized) {
                                                  match = i;
                                                  break;
                                                }
                                              }
                                              _stockTargetItem = match;
                                              _editingItemId = match?.id;
                                              if (match != null) {
                                                _unitController.text =
                                                    match.unit;
                                              }
                                            });
                                          },
                                        );
                                      },
                                      onSelected: (selected) {
                                        setModalState(() {
                                          _stockTargetItem = selected;
                                          _editingItemId = selected.id;
                                          _nameController.text = selected.name;
                                          _categoryController.text =
                                              _categories.contains(
                                                    selected.category,
                                                  )
                                                  ? selected.category
                                                  : 'Other';
                                          _unitController.text =
                                              _units.contains(selected.unit)
                                                  ? selected.unit
                                                  : 'pcs';
                                          _descriptionController.text =
                                              selected.notes ?? '';
                                          _editingAvailable =
                                              selected.available;
                                        });
                                      },
                                    )
                                    : AntdOutlineInput(
                                      controller: _nameController,
                                      // New item and edit: allow typing item name.
                                      readOnly: false,
                                      hintText: 'Item name',
                                    ),
                          ),
                          if (isAddStock) ...[
                            const SizedBox(height: 14),
                            AntdFieldShell(
                              label: 'Quantity to add',
                              required: true,
                              helperText:
                                  _stockTargetItem == null
                                      ? 'Select an item first. Unit stays on the existing item.'
                                      : 'Adds to current stock (${_stockTargetItem!.quantity} ${_stockTargetItem!.unit}).',
                              child: AntdOutlineInput(
                                controller: _quantityController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                hintText: '0',
                              ),
                            ),
                          ] else ...[
                            const SizedBox(height: 14),
                            AntdFieldShell(
                              label: 'Category',
                              required: true,
                              child: DropdownButtonFormField<String>(
                                value: _categoryController.text,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                                items: [
                                  for (final c in _categories)
                                    DropdownMenuItem(
                                      value: c,
                                      child: Text(c),
                                    ),
                                ],
                                onChanged: (v) {
                                  if (v != null) _categoryController.text = v;
                                },
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: AntdFieldShell(
                                    label: 'Quantity',
                                    required: true,
                                    helperText:
                                        isEdit
                                            ? 'Locked. Archive and add a new item to change quantity/unit.'
                                            : null,
                                    child: AntdOutlineInput(
                                      controller: _quantityController,
                                      readOnly: isEdit,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      hintText: '0',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: AntdFieldShell(
                                    label: 'Unit',
                                    required: true,
                                    helperText:
                                        isEdit
                                            ? 'Locked. Archive and recreate to change unit.'
                                            : null,
                                    child:
                                        isEdit
                                            ? AntdOutlineInput(
                                              controller: _unitController,
                                              readOnly: true,
                                            )
                                            : DropdownButtonFormField<String>(
                                              value:
                                                  _units.contains(
                                                        _unitController.text,
                                                      )
                                                      ? _unitController.text
                                                      : 'pcs',
                                              isExpanded: true,
                                              decoration: const InputDecoration(
                                                border: InputBorder.none,
                                                isDense: true,
                                              ),
                                              items: [
                                                for (final u in _units)
                                                  DropdownMenuItem(
                                                    value: u,
                                                    child: Text(u),
                                                  ),
                                              ],
                                              onChanged: (v) {
                                                if (v != null) {
                                                  _unitController.text = v;
                                                }
                                              },
                                            ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            AntdFieldShell(
                              label: 'Low stock alert',
                              helperText:
                                  'Item is marked low when quantity is at or below this value.',
                              child: AntdOutlineInput(
                                controller: _minStockController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                hintText: '10',
                              ),
                            ),
                            const SizedBox(height: 14),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Available stock'),
                              subtitle: Text(
                                _editingAvailable
                                    ? 'This item can be used for operations.'
                                    : 'This item is marked unavailable.',
                              ),
                              value: _editingAvailable,
                              activeColor: AntdTokens.success,
                              onChanged:
                                  (v) => setModalState(
                                    () => _editingAvailable = v,
                                  ),
                            ),
                            const SizedBox(height: 14),
                            AntdFieldShell(
                              label: 'Description',
                              child: AntdOutlineInput(
                                controller: _descriptionController,
                                maxLines: 3,
                                hintText: 'Optional notes',
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              actions: [
                AntdCancelButton(
                  label: 'Cancel',
                  onPressed: () => Navigator.pop(dialogContext),
                ),
                AntdPrimaryButton(
                  label:
                      item == null
                          ? (createNewItem ? 'Add' : 'Add stock')
                          : 'Update',
                  loading: _isSavingInventory,
                  onPressed: () => _saveInventoryItem(dialogContext),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _saveInventoryItem(BuildContext dialogContext) async {
    if (_isSavingInventory) return;

    // `_creatingNewInventoryItem` is true for New Item AND Edit.
    // Add Stock sets it false.
    final isAddStockMode = !_creatingNewInventoryItem;

    if (_nameController.text.trim().isEmpty ||
        _quantityController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!isAddStockMode &&
        (_unitController.text.trim().isEmpty ||
            _categoryController.text.trim().isEmpty)) {
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid quantity')));
      return;
    }

    try {
      setState(() => _isSavingInventory = true);
      final target = _stockTargetItem;
      if (isAddStockMode && target == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select an existing inventory item'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      final savedQuantity =
          isAddStockMode && target != null ? target.quantity + q : q;
      final body = {
        'name':
            isAddStockMode && target != null
                ? target.name
                : _nameController.text.trim(),
        'category':
            isAddStockMode && target != null
                ? target.category
                : _categoryController.text.trim(),
        'quantity': savedQuantity,
        'unitCost': 0,
        'unit':
            isAddStockMode && target != null
                ? target.unit
                : _unitController.text.trim(),
        'notes':
            isAddStockMode && target != null
                ? target.notes
                : (_descriptionController.text.trim().isEmpty
                    ? null
                    : _descriptionController.text.trim()),
        'minStockLevel':
            isAddStockMode && target != null
                ? target.minStockLevel
                : (int.tryParse(_minStockController.text.trim()) ?? 0),
        'available':
            isAddStockMode && target != null
                ? target.available
                : _editingAvailable,
      };

      final editingId = _editingItemId;
      if (editingId != null) {
        await ApiClient.instance.putJson(
          '/api/inventory/$editingId',
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
              isAddStockMode
                  ? 'Stock added'
                  : (editingId != null ? 'Item updated' : 'Item added'),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final message =
            e is ApiError && e.statusCode == 409
                ? 'This inventory item already exists.'
                : 'Save failed: $e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingInventory = false);
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
    _editingAvailable = true;
    _editingItemId = null;
    _stockTargetItem = null;
    _creatingNewInventoryItem = false;
  }

  Widget _buildTabularView(List<InventoryItem> items) {
    return Card(
      elevation: 0,
      color: AntdTokens.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AntdTokens.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: PagedDataTable(
            title: 'Inventory Items',
            enableSearch: false,
            enablePrint: false,
            maxTableHeight: MediaQuery.sizeOf(context).height * 0.62,
            pdfExcludedColumnIndexes: const {8},
            fullWidth: true,
            headingRowHeight: 42,
            dataRowMinHeight: 44,
            dataRowMaxHeight: 56,
            horizontalMargin: 12,
            headingRowColor: WidgetStatePropertyAll(AntdTokens.tableHeaderBg),
            columnSpacing: 18,
            columns: const [
              DataColumn(label: Text('Item No.')),
              DataColumn(label: SizedBox(width: 160, child: Text('Item'))),
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
                      DataCell(Text(item.itemCode)),
                      DataCell(
                        SizedBox(
                          width: 160,
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
                          width: 180,
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
                      DataCell(_stockBadge(item)),
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
                                    color: AntdTokens.blue,
                                  ),
                                  onPressed: () => _showAddEditDialog(item),
                                ),
                                IconButton(
                                  tooltip: 'Archive',
                                  icon: const Icon(
                                    Icons.archive_outlined,
                                    size: 20,
                                    color: AntdTokens.warning,
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
        ),
    );
  }

  Widget _stockBadge(InventoryItem item) {
    final label = _stockLabel(item);
    final color =
        !item.available
            ? Colors.grey
            : item.lowStock
            ? Colors.red
            : Colors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color.shade800,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildStatsRow(List<InventoryItem> items, int totalActiveInSystem) {
    final total = items.length;
    final lowItems = items.where((e) => e.lowStock && e.available).toList();
    final unavailableItems = items.where((e) => !e.available).toList();
    final showTotalHint =
        totalActiveInSystem > 0 && total != totalActiveInSystem;
    return Row(
      children: [
        Expanded(
          child: _inventoryStatTile(
            label: 'Items',
            value: '$total',
            color: Colors.blue,
            subtitle: showTotalHint ? 'of $totalActiveInSystem total' : null,
          ),
        ),
        Expanded(
          child: _inventoryStatTile(
            label: 'Low Stock',
            value: '${lowItems.length}',
            color: Colors.red,
            onTap:
                () => _showInventoryListDialog(
                  title: 'Low Stock Items',
                  items: lowItems,
                ),
          ),
        ),
        Expanded(
          child: _inventoryStatTile(
            label: 'Unavailable',
            value: '${unavailableItems.length}',
            color: Colors.grey,
            onTap:
                () => _showInventoryListDialog(
                  title: 'Unavailable Items',
                  items: unavailableItems,
                ),
          ),
        ),
      ],
    );
  }

  Widget _inventoryStatTile({
    required String label,
    required String value,
    required MaterialColor color,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 0,
      color: color.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.shade100),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color.shade700,
                ),
              ),
              Text(label),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                  ),
                ),
              if (onTap != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'View list',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color.shade700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showInventoryListDialog({
    required String title,
    required List<InventoryItem> items,
  }) {
    showDialog<void>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(title),
            content: SizedBox(
              width: 620,
              child:
                  items.isEmpty
                      ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No items to show.'),
                      )
                      : ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 420),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return ListTile(
                              dense: true,
                              title: Text('${item.itemCode} · ${item.name}'),
                              subtitle: Text(
                                '${item.category} · ${item.quantity} ${item.unit} · Updated ${_formatDate(item.lastUpdated)}',
                              ),
                              trailing: _stockBadge(item),
                            );
                          },
                        ),
                      ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  Widget _filterDropdown<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    double width = 180,
  }) {
    return AntdSelect<T>(
      label: label,
      width: width,
      value: value,
      items: items,
      onChanged: onChanged,
    );
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _stockFilter = 'all';
      _categoryFilter = 'all';
      _updatedYearFilter = null;
      _updatedMonthFilter = null;
      _updatedDayFilter = null;
      _applyActiveFilter();
    });
  }

  Widget _buildFilterBar(List<InventoryItem> displayItems) {
    final categoryOptions =
        {
            for (final item in _activeItems) item.category,
            ..._categories,
            if (_categoryFilter != 'all') _categoryFilter,
          }.where((e) => e.trim().isNotEmpty).toList()
          ..sort();
    final years =
        {
            for (final item in _activeItems) item.lastUpdated.toLocal().year,
            if (_updatedYearFilter != null) _updatedYearFilter!,
          }.toList()
          ..sort((a, b) => b.compareTo(a));
    final months =
        {
            for (final item in _activeItems)
              if (_updatedYearFilter == null ||
                  item.lastUpdated.toLocal().year == _updatedYearFilter)
                item.lastUpdated.toLocal().month,
            if (_updatedMonthFilter != null) _updatedMonthFilter!,
          }.toList()
          ..sort();
    final days =
        {
            for (final item in _activeItems)
              if ((_updatedYearFilter == null ||
                      item.lastUpdated.toLocal().year == _updatedYearFilter) &&
                  (_updatedMonthFilter == null ||
                      item.lastUpdated.toLocal().month == _updatedMonthFilter))
                item.lastUpdated.toLocal().day,
            if (_updatedDayFilter != null) _updatedDayFilter!,
          }.toList()
          ..sort();
    return AntdToolbar(
      elevated: false,
      padding: EdgeInsets.zero,
      children: [
        AntdSearchInput(
          controller: _searchController,
          hintText: 'Search by first letter / prefix…',
          width: 280,
          onChanged: (_) => setState(_applyActiveFilter),
          onClear: () {
            _searchController.clear();
            setState(_applyActiveFilter);
          },
        ),
        _filterDropdown<String>(
          label: 'Stock level',
          value: _stockFilter,
          width: 160,
          items: const [
            DropdownMenuItem(value: 'all', child: Text('All stock')),
            DropdownMenuItem(value: 'ok', child: Text('OK')),
            DropdownMenuItem(value: 'low', child: Text('Low stock')),
            DropdownMenuItem(
              value: 'unavailable',
              child: Text('Unavailable'),
            ),
          ],
          onChanged:
              (v) => setState(() {
                _stockFilter = v ?? 'all';
                _applyActiveFilter();
              }),
        ),
        _filterDropdown<String>(
          label: 'Category',
          value: _categoryFilter,
          width: 200,
          items: [
            const DropdownMenuItem(
              value: 'all',
              child: Text('All categories'),
            ),
            for (final c in categoryOptions)
              DropdownMenuItem(value: c, child: Text(c)),
          ],
          onChanged:
              (v) => setState(() {
                _categoryFilter = v ?? 'all';
                _applyActiveFilter();
              }),
        ),
        _filterDropdown<int?>(
          label: 'Updated year',
          value: _updatedYearFilter,
          width: 150,
          items: [
            const DropdownMenuItem<int?>(
              value: null,
              child: Text('All years'),
            ),
            for (final y in years)
              DropdownMenuItem(value: y, child: Text('$y')),
          ],
          onChanged:
              (v) => setState(() {
                _updatedYearFilter = v;
                _updatedMonthFilter = null;
                _updatedDayFilter = null;
                _applyActiveFilter();
              }),
        ),
        _filterDropdown<int?>(
          label: 'Updated month',
          value: _updatedMonthFilter,
          width: 150,
          items: [
            const DropdownMenuItem<int?>(
              value: null,
              child: Text('All months'),
            ),
            for (final m in months)
              DropdownMenuItem(
                value: m,
                child: Text(m.toString().padLeft(2, '0')),
              ),
          ],
          onChanged:
              (v) => setState(() {
                _updatedMonthFilter = v;
                _updatedDayFilter = null;
                _applyActiveFilter();
              }),
        ),
        _filterDropdown<int?>(
          label: 'Updated day',
          value: _updatedDayFilter,
          width: 140,
          items: [
            const DropdownMenuItem<int?>(
              value: null,
              child: Text('All days'),
            ),
            for (final d in days)
              DropdownMenuItem(
                value: d,
                child: Text(d.toString().padLeft(2, '0')),
              ),
          ],
          onChanged:
              (v) => setState(() {
                _updatedDayFilter = v;
                _applyActiveFilter();
              }),
        ),
        AntdSecondaryButton(
          onPressed: _clearFilters,
          icon: Icons.filter_alt_off,
          label: 'Clear filters',
        ),
        AntdStatusTag(
          label: '${displayItems.length} of ${_activeItems.length} rows',
          color: AntdTokens.textSecondary,
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
      child: AntdPage(
        title: 'Inventory',
        subtitle: 'Track stock levels, categories, and restocks.',
        actions: [
          AntdSecondaryButton(
            onPressed:
                _isExportingPdf || displayList.isEmpty
                    ? null
                    : () => _printInventoryPdf(displayList),
            icon: Icons.picture_as_pdf,
            label: _isExportingPdf ? 'Preparing PDF' : 'Print PDF',
          ),
          if (_isManager)
            AntdSecondaryButton(
              onPressed: () => _showAddEditDialog(null, true),
              icon: Icons.add_box_outlined,
              label: 'New item',
            ),
          if (_isManager)
            AntdPrimaryButton(
              label: 'Add stock',
              onPressed: () => _showAddEditDialog(),
            ),
        ],
        filters: _buildFilterBar(displayList),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStatsRow(displayList, _activeItems.length),
            const SizedBox(height: 12),
            Expanded(
              child:
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : displayList.isEmpty
                      ? Center(
                        child: Text(
                          _activeItems.isEmpty
                              ? 'No inventory items'
                              : 'No inventory items match the active filters',
                          style: TextStyle(color: AntdTokens.textSecondary),
                        ),
                      )
                      : _buildTabularView(displayList),
            ),
          ],
        ),
      ),
    );
  }
}
