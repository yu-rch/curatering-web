import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../auth/auth_session.dart';
import '../auth/roles.dart';
import '../services/api_client.dart';
import '../utils/debouncer.dart';
import '../widgets/antd_buttons.dart';
import '../widgets/antd_form_field.dart';
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
      lastUpdated:
          DateTime.tryParse('${json['lastUpdated']}') ?? DateTime.now(),
      notes: json['notes']?.toString(),
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
  String? _editingItemId;
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
          if (_categoryFilter != 'all' && item.category != _categoryFilter) {
            return false;
          }
          if (_stockFilter == 'ok' && (item.lowStock || !item.available)) {
            return false;
          }
          if (_stockFilter == 'low' && (!item.lowStock || !item.available)) {
            return false;
          }
          if (_stockFilter == 'unavailable' && item.available) {
            return false;
          }
          if (_updatedYearFilter != null &&
              item.lastUpdated.year != _updatedYearFilter) {
            return false;
          }
          if (_updatedMonthFilter != null &&
              item.lastUpdated.month != _updatedMonthFilter) {
            return false;
          }
          if (_updatedDayFilter != null &&
              item.lastUpdated.day != _updatedDayFilter) {
            return false;
          }
          return true;
        }).toList();
    _sortList(_filteredActive);
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
      final doc = pw.Document(title: 'Inventory Items');
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

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(24),
          footer:
              (context) => pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ),
          build:
              (context) => [
                pw.Text(
                  'Inventory Items',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  "Macrina's Kitchen and Catering",
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'As of ${_formatDateTime(generatedAt)} · ${items.length} row(s)',
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.TableHelper.fromTextArray(
                  headers: headers,
                  data: rows,
                  border: pw.TableBorder.all(
                    color: PdfColors.grey300,
                    width: 0.4,
                  ),
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.grey200,
                  ),
                  headerStyle: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  cellStyle: const pw.TextStyle(fontSize: 7),
                  cellAlignment: pw.Alignment.centerLeft,
                  headerAlignment: pw.Alignment.centerLeft,
                  columnWidths: const {
                    0: pw.FixedColumnWidth(58),
                    1: pw.FlexColumnWidth(1.3),
                    2: pw.FlexColumnWidth(1.2),
                    3: pw.FlexColumnWidth(1.7),
                    4: pw.FixedColumnWidth(38),
                    5: pw.FixedColumnWidth(42),
                    6: pw.FixedColumnWidth(58),
                    7: pw.FixedColumnWidth(64),
                  },
                ),
              ],
        ),
      );

      await Printing.layoutPdf(
        onLayout: (_) => doc.save(),
        name: 'inventory-items.pdf',
      );
    } finally {
      if (mounted) setState(() => _isExportingPdf = false);
    }
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
                item == null ? 'Add Inventory Item' : 'Edit Inventory Item',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AntdFieldShell(
                        label: 'Item',
                        required: true,
                        child: AntdOutlineInput(
                          controller: _nameController,
                          hintText: 'Item name',
                        ),
                      ),
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
                              DropdownMenuItem(value: c, child: Text(c)),
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
                              child: AntdOutlineInput(
                                controller: _quantityController,
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
                              child: DropdownButtonFormField<String>(
                                value:
                                    _units.contains(_unitController.text)
                                        ? _unitController.text
                                        : 'pcs',
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                                items: [
                                  for (final u in _units)
                                    DropdownMenuItem(value: u, child: Text(u)),
                                ],
                                onChanged: (v) {
                                  if (v != null) _unitController.text = v;
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
                            (v) => setModalState(() => _editingAvailable = v),
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
                  label: item == null ? 'Add' : 'Update',
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid quantity')));
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
        'available': _editingAvailable,
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
          SnackBar(
            content: Text('Save failed: $e'),
            backgroundColor: Colors.red,
          ),
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
    _editingAvailable = true;
    _editingItemId = null;
  }

  Widget _buildTabularView(List<InventoryItem> items) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AntdTokens.borderSubtle),
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
            headingRowColor: const WidgetStatePropertyAll(Color(0xFFF5F7F9)),
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
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<T>(
        value: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
        items: items,
        onChanged: onChanged,
      ),
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
          }.where((e) => e.trim().isNotEmpty).toList()
          ..sort();
    if (_categoryFilter != 'all' &&
        !categoryOptions.contains(_categoryFilter)) {
      _categoryFilter = 'all';
    }
    final years =
        {for (final item in _activeItems) item.lastUpdated.year}.toList()
          ..sort((a, b) => b.compareTo(a));
    if (_updatedYearFilter != null && !years.contains(_updatedYearFilter)) {
      _updatedYearFilter = null;
    }
    final months =
        {
            for (final item in _activeItems)
              if (_updatedYearFilter == null ||
                  item.lastUpdated.year == _updatedYearFilter)
                item.lastUpdated.month,
          }.toList()
          ..sort();
    if (_updatedMonthFilter != null && !months.contains(_updatedMonthFilter)) {
      _updatedMonthFilter = null;
    }
    final days =
        {
            for (final item in _activeItems)
              if ((_updatedYearFilter == null ||
                      item.lastUpdated.year == _updatedYearFilter) &&
                  (_updatedMonthFilter == null ||
                      item.lastUpdated.month == _updatedMonthFilter))
                item.lastUpdated.day,
          }.toList()
          ..sort();
    if (_updatedDayFilter != null && !days.contains(_updatedDayFilter)) {
      _updatedDayFilter = null;
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 300,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by item prefix…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon:
                    _searchController.text.isEmpty
                        ? null
                        : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _searchController.clear();
                            setState(_applyActiveFilter);
                          },
                          icon: const Icon(Icons.close),
                        ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
            ),
          ),
          _filterDropdown<String>(
            label: 'Stock level',
            value: _stockFilter,
            width: 170,
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
            width: 240,
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
          OutlinedButton.icon(
            onPressed: _clearFilters,
            icon: const Icon(Icons.filter_alt_off),
            label: const Text('Clear filters'),
          ),
          OutlinedButton.icon(
            onPressed:
                _isExportingPdf || displayItems.isEmpty
                    ? null
                    : () => _printInventoryPdf(displayItems),
            icon:
                _isExportingPdf
                    ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.picture_as_pdf),
            label: Text(_isExportingPdf ? 'Preparing PDF' : 'Print PDF'),
          ),
          Text(
            '${displayItems.length} of ${_activeItems.length} rows',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
          if (_isManager)
            AntdPrimaryButton(
              label: 'Add item',
              onPressed: () => _showAddEditDialog(),
            ),
        ],
      ),
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
          _buildFilterBar(displayList),
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildStatsRow(displayList, _activeItems.length),
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
                    : _buildTabularView(displayList),
          ),
        ],
      ),
    );
  }
}
