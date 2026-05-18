import 'package:flutter/material.dart';

import '../auth/auth_session.dart';
import '../auth/roles.dart';
import '../models/user.dart';
import '../services/api_client.dart';
import '../services/menu_store.dart';
import '../services/super_admin_api.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/paginated_data_table.dart';
import 'inventory.dart';

class ArchivedTransaction {
  final String OrderNo;
  final String customerName;
  final String eventTitle;
  final String eventType;
  final String totalCost;
  final String loyaltyRewards;
  final String archiveDate;

  ArchivedTransaction({
    required this.OrderNo,
    required this.customerName,
    required this.eventTitle,
    required this.eventType,
    required this.totalCost,
    required this.loyaltyRewards,
    required this.archiveDate,
  });
}

class ArchivedDish {
  final String dishNo;
  final String dishName;
  final String variants;
  final String price;
  final String archiveDate;

  ArchivedDish({
    required this.dishNo,
    required this.dishName,
    required this.variants,
    required this.price,
    required this.archiveDate,
  });
}

class Archive extends StatefulWidget {
  const Archive({super.key});

  @override
  State<Archive> createState() => _ArchiveState();
}

class _ArchiveState extends State<Archive> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<UserDto> _archivedUsers = [];
  bool _loadingUsers = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadArchivedUsers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadArchivedUsers() async {
    setState(() => _loadingUsers = true);
    try {
      final users = await SuperAdminApi.instance.listUsers(
        archived: true,
      );
      setState(() => _archivedUsers = users);
    } catch (e) {
      // Handle error
    } finally {
      setState(() => _loadingUsers = false);
    }
  }

  List<ArchivedDish> _archivedDishesFromStore() {
    return MenuStore.instance.archivedDishes.map((d) {
      final archivedAt = d.archivedAt;
      final archiveDate = archivedAt == null
          ? ''
          : '${archivedAt.month.toString().padLeft(2, '0')} ${archivedAt.day} ${archivedAt.year} ${archivedAt.hour.toString().padLeft(2, '0')}:${archivedAt.minute.toString().padLeft(2, '0')}';
      return ArchivedDish(
        dishNo: d.id,
        dishName: d.name,
        variants: d.paxOptions.join(', '),
        price: '₱${d.price}',
        archiveDate: archiveDate,
      );
    }).toList();
  }

  Widget _buildTabButton(String label, int index) {
    final isSelected = _tabController.index == index;
    return GestureDetector(
      onTap: () => setState(() => _tabController.index = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFC024) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildTable<T>({
    required List<DataColumn> columns,
    required List<DataRow> rows,
    Widget? emptyMessage,
  }) {
    if (rows.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Center(
            child: emptyMessage ?? const Text('No archived items found.'),
          ),
        ),
      );
    }
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: PagedDataTable(columns: columns, rows: rows),
      ),
    );
  }

  Widget _buildMenuArchiveTab() {
    return AnimatedBuilder(
      animation: MenuStore.instance,
      builder: (context, _) {
        final archivedDishes = _archivedDishesFromStore();
        return SingleChildScrollView(
          child: _buildTable<ArchivedDish>(
            columns: const [
              DataColumn(label: Text('Dish No.')),
              DataColumn(label: Text('Dish Name')),
              DataColumn(label: Text('Category')),
              DataColumn(label: Text('Variants')),
              DataColumn(label: Text('Price')),
              DataColumn(label: Text('Archive Date')),
            ],
            rows: archivedDishes
                .map(
                  (d) => DataRow(cells: [
                    DataCell(Text(d.dishNo)),
                    DataCell(Text(d.dishName)),
                    DataCell(const Text('Menu')),
                    DataCell(Text(d.variants)),
                    DataCell(Text(d.price)),
                    DataCell(Text(d.archiveDate)),
                  ]),
                )
                .toList(),
            emptyMessage: const Text('No archived menu items found.'),
          ),
        );
      },
    );
  }

  Widget _buildLoyaltyArchiveTab() {
    return SingleChildScrollView(
      child: _buildTable<ArchivedTransaction>(
        columns: const [
          DataColumn(label: Text('Reward ID')),
          DataColumn(label: Text('Customer Name')),
          DataColumn(label: Text('Reward Type')),
          DataColumn(label: Text('Points')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Archive Date')),
        ],
        rows: const [], // Placeholder for loyalty rewards archive
        emptyMessage: const Text('No archived loyalty rewards found.'),
      ),
    );
  }

  Widget _buildEventsArchiveTab() {
    return SingleChildScrollView(
      child: _buildTable<ArchivedTransaction>(
        columns: const [
          DataColumn(label: Text('Order No.')),
          DataColumn(label: Text('Customer Name')),
          DataColumn(label: Text('Event Title')),
          DataColumn(label: Text('Event Type')),
          DataColumn(label: Text('Total Cost')),
          DataColumn(label: Text('Archive Date')),
        ],
        rows: const [], // Placeholder for events archive
        emptyMessage: const Text('No archived events found.'),
      ),
    );
  }

  Widget _buildAccountsArchiveTab() {
    if (_loadingUsers) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      child: _buildTable<UserDto>(
        columns: const [
          DataColumn(label: Text('User ID')),
          DataColumn(label: Text('Full Name')),
          DataColumn(label: Text('Email')),
          DataColumn(label: Text('Role')),
          DataColumn(label: Text('Archive Date')),
        ],
        rows: _archivedUsers
            .map(
              (u) => DataRow(cells: [
                DataCell(Text(u.id)),
                DataCell(Text(u.fullName)),
                DataCell(Text(u.email)),
                DataCell(Text(u.role.displayName)),
                const DataCell(Text('-')), // Archive date not available in UserDto
              ]),
            )
            .toList(),
        emptyMessage: const Text('No archived accounts found.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, _) {
        return AppScaffold(
          showSearch: true,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Archive',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                  children: [
                    _buildTabButton('Menu', 0),
                    const SizedBox(width: 8),
                    _buildTabButton('Loyalty Rewards', 1),
                    const SizedBox(width: 8),
                    _buildTabButton('Events', 2),
                    const SizedBox(width: 8),
                    _buildTabButton('Accounts', 3),
                    const SizedBox(width: 8),
                    _buildTabButton('Inventory', 4),
                  ],
                ),
                ),
                const SizedBox(height: 16),
                // Tab content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildMenuArchiveTab(),
                      _buildLoyaltyArchiveTab(),
                      _buildEventsArchiveTab(),
                      _buildAccountsArchiveTab(),
                      const ArchiveInventoryTab(),
                    ],
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

class ArchiveInventoryTab extends StatefulWidget {
  const ArchiveInventoryTab({super.key});

  @override
  State<ArchiveInventoryTab> createState() => _ArchiveInventoryTabState();
}

class _ArchiveInventoryTabState extends State<ArchiveInventoryTab> {
  final TextEditingController _search = TextEditingController();
  List<InventoryItem> _items = [];
  bool _loading = true;

  bool get _isManager =>
      AuthSession.instance.currentRole == Role.manager ||
      AuthSession.instance.currentRole == Role.superAdmin;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final decoded = await ApiClient.instance.getJson(
        '/api/inventory',
        queryParameters: const {'archived': 'true'},
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
      if (mounted) setState(() => _items = list);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load archived inventory.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  List<InventoryItem> get _filtered {
    final q = _search.text.toLowerCase().trim();
    if (q.isEmpty) return _items;
    return _items
        .where(
          (i) =>
              i.name.toLowerCase().contains(q) ||
              i.category.toLowerCase().contains(q),
        )
        .toList();
  }

  Future<void> _restore(InventoryItem item) async {
    try {
      await ApiClient.instance.postJson(
        '/api/inventory/${item.id}/archive',
        body: {'archived': false},
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restored "${item.name}"')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _deleteForever(InventoryItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Delete permanently'),
            content: Text('Remove "${item.name}" forever?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (ok != true || !mounted) return;
    try {
      await ApiClient.instance.delete('/api/inventory/${item.id}');
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final rows = _filtered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _search,
          decoration: InputDecoration(
            hintText: 'Search archived inventory…',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            filled: true,
            fillColor: Colors.grey.shade100,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child:
              rows.isEmpty
                  ? Center(
                    child: Text(
                      _items.isEmpty
                          ? 'No archived inventory items.'
                          : 'No matches.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  )
                  : PagedDataTable(
                    headingRowColor: const WidgetStatePropertyAll(
                      Color(0xFFF5F7F9),
                    ),
                    columns: const [
                      DataColumn(label: Text('Name')),
                      DataColumn(label: Text('Category')),
                      DataColumn(label: Text('Qty')),
                      DataColumn(label: Text('Unit')),
                      DataColumn(label: Text('Unit cost')),
                      DataColumn(label: Text('Updated')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows:
                        rows.map((item) {
                          return DataRow(
                            cells: [
                              DataCell(Text(item.name)),
                              DataCell(Text(item.category)),
                              DataCell(Text('${item.quantity}')),
                              DataCell(Text(item.unit)),
                              DataCell(
                                Text('₱${item.unitCost.toStringAsFixed(2)}'),
                              ),
                              DataCell(Text(_fmt(item.lastUpdated))),
                              DataCell(
                                _isManager
                                    ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          tooltip: 'Restore',
                                          icon: const Icon(
                                            Icons.unarchive,
                                            color: Colors.blue,
                                          ),
                                          onPressed: () => _restore(item),
                                        ),
                                        IconButton(
                                          tooltip: 'Delete',
                                          icon: const Icon(
                                            Icons.delete_forever,
                                            color: Colors.red,
                                          ),
                                          onPressed: () => _deleteForever(item),
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
      ],
    );
  }
}
